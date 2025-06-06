// lib/screens/nurse/nfc_card_registration.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_registration.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart';

class NFCCardRegistration extends StatefulWidget {
  @override
  _NFCCardRegistrationState createState() => _NFCCardRegistrationState();
}

class _NFCCardRegistrationState extends State<NFCCardRegistration> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Tap "Scan Card" to begin';
  bool _success = false;
  bool _error = false;
  String? _cardId;
  String? _errorMessage;
  Map<String, dynamic>? _existingPatientData;
  
  // ADD: Debug mode for development
  static const bool _debugMode = true; // Set to false in production
  bool _showDebugOptions = _debugMode;
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ENHANCED: Generate random card ID for testing
  String _generateRandomCardId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(99999).toString().padLeft(5, '0');
    return 'DEV${timestamp.toString().substring(8)}$randomPart';
  }

  // ENHANCED: Start NFC scanning with debug option
  Future<void> _startNFCScanning({bool useDebugCard = false}) async {
    if (useDebugCard && _debugMode) {
      // Generate a random card ID for testing
      final randomCardId = _generateRandomCardId();
      setState(() {
        _cardId = randomCardId;
        _statusMessage = 'Debug card generated, checking registration...';
        _isScanning = true;
        _error = false;
        _success = false;
        _existingPatientData = null;
        _errorMessage = null;
      });
      
      // Add a small delay to simulate scanning
      await Future.delayed(Duration(seconds: 1));
      await _checkCardRegistration(randomCardId);
      return;
    }

    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      
      if (availability != NFCAvailability.available) {
        setState(() {
          _statusMessage = 'NFC is not available on this device';
          _error = true;
          _isScanning = false;
          _errorMessage = 'Please enable NFC in device settings and try again.';
        });
        return;
      }
      
      setState(() {
        _isScanning = true;
        _error = false;
        _success = false;
        _cardId = null;
        _errorMessage = null;
        _existingPatientData = null;
        _statusMessage = 'Place NFC card on the back of your device';
      });
      
      try {
        var tag = await FlutterNfcKit.poll();
        String cardSerialNumber = tag.id;
        
        setState(() {
          _cardId = cardSerialNumber;
          _statusMessage = 'Card detected, checking registration...';
        });
        
        await _checkCardRegistration(cardSerialNumber);
        
      } catch (e) {
        setState(() {
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Error reading card';
          _errorMessage = e.toString();
        });
      } finally {
        await FlutterNfcKit.finish();
      }
    } catch (e) {
      setState(() {
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error initializing NFC';
        _errorMessage = e.toString();
      });
    }
  }
  
  Future<void> _checkCardRegistration(String cardId) async {
    try {
      final databaseService = DatabaseService();
      
      // Check if card is already registered
      final cardCheck = await databaseService.checkCardRegistration(cardId);
      
      if (cardCheck != null && cardCheck['isRegistered'] == true) {
        // Card is already registered - show patient details
        final existingPatient = cardCheck['patientData'] as Map<String, dynamic>;
        
        setState(() {
          _cardId = cardId;
          _existingPatientData = existingPatient;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Regular patient found';
        });
      } else {
        // Card is not registered - available for new registration
        setState(() {
          _cardId = cardId;
          _existingPatientData = null;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'New patient - card available for registration';
        });
      }
    } catch (e) {
      setState(() {
        _cardId = cardId;
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error checking patient information';
        _errorMessage = e.toString();
      });
    }
  }
  
  void _cancelScanning() async {
    try {
      await FlutterNfcKit.finish();
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan cancelled';
      });
    } catch (e) {
      print('Error cancelling scan: $e');
    }
  }
  
  void _handleNewPatientFlow() {
    if (_cardId == null || _cardId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No card ID detected. Please scan the card again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_existingPatientData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This card is already registered. Use "Assign Doctor" instead.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientRegistrationScreen(
          cardSerialNumber: _cardId!,
        ),
      ),
    );
  }
  
  void _handleRegularPatientFlow() {
    if (_existingPatientData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssignDoctorScreen(
            patientId: _existingPatientData!['patientId'],
            patientName: _existingPatientData!['name'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Patient Flow', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_debugMode)
            IconButton(
              icon: Icon(Icons.bug_report),
              onPressed: () {
                setState(() {
                  _showDebugOptions = !_showDebugOptions;
                });
              },
              tooltip: 'Toggle Debug Options',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _cardId = null;
                _existingPatientData = null;
                _success = false;
                _error = false;
                _isScanning = false;
                _statusMessage = 'Tap "Scan Card" to begin';
                _errorMessage = null;
              });
            },
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Instructions
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Nurse Patient Flow',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Scan the NFC card to register or assign a doctor to a patient.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // ADD: Debug options for development
                if (_showDebugOptions && _debugMode) ...[
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.developer_mode, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Developer Options',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _startNFCScanning(useDebugCard: true),
                            icon: Icon(Icons.credit_card),
                            label: Text('Generate Test Card'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 40),
                
                // NFC animation or status icon
                if (_isScanning)
                  ScaleTransition(
                    scale: _animation,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.contactless,
                        size: 100,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                else if (_success)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green,
                    ),
                  )
                else if (_error)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error,
                      size: 80,
                      color: Colors.red,
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contactless,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                
                SizedBox(height: 24),
                
                // Status message
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _error
                        ? Colors.red
                        : _success
                            ? Colors.green
                            : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                if (_errorMessage != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                SizedBox(height: 24),
                
                // Display card info when successfully scanned
                if (_cardId != null && (_success || _error)) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_existingPatientData != null ? Colors.blue : Colors.green).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (_existingPatientData != null ? Colors.blue : Colors.green).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _existingPatientData != null 
                                  ? Icons.person 
                                  : Icons.person_add,
                              color: _existingPatientData != null ? Colors.blue : Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _existingPatientData != null 
                                  ? 'REGULAR PATIENT' 
                                  : 'NEW PATIENT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: (_existingPatientData != null ? Colors.blue : Colors.green)[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Card ID: $_cardId',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                        if (_existingPatientData != null) ...[
                          SizedBox(height: 8),
                          Text(
                            'Patient: ${_existingPatientData!['name']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 40),
                
                // Action buttons
                if (_isScanning)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _cancelScanning,
                      icon: Icon(Icons.cancel),
                      label: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (_success && _cardId != null)
                  // Show flow options
                  Column(
                    children: [
                      if (_existingPatientData == null) ...[
                        // New patient flow
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleNewPatientFlow,
                            icon: Icon(Icons.person_add),
                            label: Text('Register New Patient'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Regular patient flow
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleRegularPatientFlow,
                            icon: Icon(Icons.assignment_ind),
                            label: Text('Assign Doctor'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      
                      SizedBox(height: 12),
                      
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _cardId = null;
                              _existingPatientData = null;
                              _success = false;
                              _error = false;
                              _statusMessage = 'Tap "Scan Card" to begin';
                            });
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Scan Different Card'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Default scan button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startNFCScanning,
                      icon: Icon(Icons.contactless),
                      label: Text('Scan NFC Card'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                
                SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}