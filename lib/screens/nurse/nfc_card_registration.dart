import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/nfc_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_registration.dart';

class NFCCardRegistration extends StatefulWidget {
  @override
  _NFCCardRegistrationState createState() => _NFCCardRegistrationState();
}

class _NFCCardRegistrationState extends State<NFCCardRegistration> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Tap "Scan Card" to begin';
  bool _success = false;
  bool _error = false;
  String? _cardSerialNumber;
  String? _detailedErrorMessage;
  Map<String, dynamic>? _existingPatientData;
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
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
    NFCService.stopSession(); // Stop NFC session if active
    super.dispose();
  }

  // Start NFC card reading
  Future<void> _startNFCScanning() async {
    try {
      // Check if NFC is available
      bool isAvailable = await NFCService.isNFCAvailable();
      
      if (!isAvailable) {
        setState(() {
          _statusMessage = 'NFC is not available on this device';
          _error = true;
          _isScanning = false;
          _detailedErrorMessage = 'This device does not support NFC or NFC is disabled';
        });
        return;
      }
      
      setState(() {
        _isScanning = true;
        _error = false;
        _success = false;
        _cardSerialNumber = null;
        _detailedErrorMessage = null;
        _existingPatientData = null;
        _statusMessage = 'Place NFC card on the back of your device';
      });
      
      try {
        final result = await NFCService.readNFC();
        
        // Handle the case when result is null
        if (result == null) {
          setState(() {
            _statusMessage = 'No card detected or scan failed';
            _error = true;
            _isScanning = false;
            _detailedErrorMessage = 'Please try again and ensure the card is properly positioned';
          });
          return;
        }
        
        // Debug output
        debugPrint('NFC Read Result: $result');
        
        // Extract serial number with priority order
        String? serialNumber;
        
        // First try to get dedicated card serial number field
        if (result.containsKey('cardSerialNumber') && result['cardSerialNumber'] != null) {
          serialNumber = result['cardSerialNumber'].toString();
        } 
        // Then try ID field
        else if (result.containsKey('id') && result['id'] != null) {
          serialNumber = result['id'].toString();
        }
        // Then try data field if it contains something
        else if (result.containsKey('data') && result['data'] != null) {
          serialNumber = result['data'].toString();
        }
        // If no usable data found, generate one based on tag discovery
        else {
          // Use a timestamp-based ID as fallback
          serialNumber = 'NFC-${DateTime.now().millisecondsSinceEpoch}';
          debugPrint('Generated fallback serial number: $serialNumber');
        }
        
        // Ensure serial number is not empty
        if (serialNumber.isEmpty) {
          serialNumber = 'NFC-${DateTime.now().millisecondsSinceEpoch}';
        }
        
        debugPrint('Final card serial number: $serialNumber');
        
        // Check if this card is already registered
        await _checkCardRegistration(serialNumber);
        
      } catch (e) {
        debugPrint('Error during NFC reading process: $e');
        setState(() {
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Error reading card';
          _detailedErrorMessage = e.toString();
        });
      }
    } catch (e) {
      debugPrint('Outer exception in _startNFCScanning: $e');
      setState(() {
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error initializing NFC';
        _detailedErrorMessage = e.toString();
      });
      
      // Make sure to stop the NFC session on error
      try {
        await NFCService.stopSession();
      } catch (stopError) {
        debugPrint('Error stopping NFC session: $stopError');
      }
    }
  }
  
  // Check if card is already registered
  Future<void> _checkCardRegistration(String serialNumber) async {
    try {
      final databaseService = DatabaseService();
      final cardCheck = await databaseService.checkCardRegistration(serialNumber);
      
      if (cardCheck != null && cardCheck['isRegistered'] == true) {
        // Card is already registered
        final existingPatient = cardCheck['patientData'] as Map<String, dynamic>;
        
        setState(() {
          _cardSerialNumber = serialNumber;
          _existingPatientData = existingPatient;
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Card already registered';
          _detailedErrorMessage = 'This NFC card is already registered to another patient';
        });
      } else {
        // Card is available for registration
        setState(() {
          _cardSerialNumber = serialNumber;
          _existingPatientData = null;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Card available for registration';
        });
      }
    } catch (e) {
      debugPrint('Error checking card registration: $e');
      setState(() {
        _cardSerialNumber = serialNumber;
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error validating card';
        _detailedErrorMessage = 'Could not check if card is already registered: ${e.toString()}';
      });
    }
  }
  
  // Cancel scanning
  void _cancelScanning() async {
    try {
      await NFCService.stopSession();
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scanning cancelled';
      });
    } catch (e) {
      debugPrint('Error cancelling scan: $e');
    }
  }
  
  // Navigate to patient registration with the card serial number
  void _proceedToRegistration() {
    final effectiveSerialNumber = _cardSerialNumber ?? 'MANUAL-${DateTime.now().millisecondsSinceEpoch}';
    
    debugPrint('Proceeding to registration with serial: $effectiveSerialNumber');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientRegistrationScreen(
          cardSerialNumber: effectiveSerialNumber,
        ),
      ),
    );
  }
  
  // Proceed without NFC card (manual entry)
  void _proceedWithoutCard() {
    final manualSerialNumber = 'MANUAL-${DateTime.now().millisecondsSinceEpoch}';
    
    debugPrint('Proceeding without NFC card, using manual serial: $manualSerialNumber');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientRegistrationScreen(
          cardSerialNumber: manualSerialNumber,
        ),
      ),
    );
  }
  
  // View existing patient details
  void _viewExistingPatient() {
    if (_existingPatientData != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person, color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text('Registered Patient'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This card is already registered to:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                SizedBox(height: 16),
                _buildPatientInfoRow('Name', _existingPatientData!['name'] ?? 'Unknown'),
                _buildPatientInfoRow('Patient ID', _existingPatientData!['patientId'] ?? 'Unknown'),
                _buildPatientInfoRow('Date of Birth', _existingPatientData!['dateOfBirth'] ?? 'Unknown'),
                _buildPatientInfoRow('Phone', _existingPatientData!['phone'] ?? 'Unknown'),
                _buildPatientInfoRow('Email', _existingPatientData!['email'] ?? 'Unknown'),
                
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Each NFC card can only be registered to one patient. Please use a different card for new registrations.',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _cardSerialNumber = null;
                  _existingPatientData = null;
                  _success = false;
                  _error = false;
                  _statusMessage = 'Tap "Scan Card" to begin';
                });
              },
              child: Text('Scan Different Card'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPatientInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Card Registration', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
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
                      'Each NFC card can only be registered to ONE patient. Before registering a new patient, scan their NFC card to ensure it\'s not already in use.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
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
                    _existingPatientData != null ? Icons.person : Icons.error,
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
              
              // Detailed error message if available
              if (_detailedErrorMessage != null && _error) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _detailedErrorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              
              SizedBox(height: 16),
              
              // Display card serial if available
              if (_cardSerialNumber != null && _success) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Card Available for Registration',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Serial Number:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      SelectableText(
                        _cardSerialNumber!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Show existing patient info if card is already registered
              if (_existingPatientData != null && _error) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Card Already Registered',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Registered to: ${_existingPatientData!['name'] ?? 'Unknown'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Patient ID: ${_existingPatientData!['patientId'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 40),
              
              // Action buttons
              if (_isScanning)
                ElevatedButton.icon(
                  onPressed: _cancelScanning,
                  icon: Icon(Icons.cancel),
                  label: Text('Cancel Scanning'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                )
              else if (_success && _cardSerialNumber != null)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _proceedToRegistration,
                        icon: Icon(Icons.arrow_forward),
                        label: Text('Proceed to Patient Registration'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _cardSerialNumber = null;
                            _success = false;
                            _statusMessage = 'Tap "Scan Card" to begin';
                          });
                          _startNFCScanning();
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Scan Different Card'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_error && _existingPatientData != null)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _viewExistingPatient,
                        icon: Icon(Icons.visibility),
                        label: Text('View Registered Patient'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _cardSerialNumber = null;
                            _existingPatientData = null;
                            _error = false;
                            _statusMessage = 'Tap "Scan Card" to begin';
                          });
                          _startNFCScanning();
                        },
                        icon: Icon(Icons.contactless),
                        label: Text('Try Different Card'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _proceedWithoutCard,
                        icon: Icon(Icons.person_add),
                        label: Text('Register Without NFC'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startNFCScanning,
                        icon: Icon(Icons.contactless),
                        label: Text('Scan NFC Card'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _proceedWithoutCard,
                        icon: Icon(Icons.person_add),
                        label: Text('Register Without NFC'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'A unique ID will be generated automatically',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}