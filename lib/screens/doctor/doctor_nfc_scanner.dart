import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';

class DoctorNFCScanner extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorNFCScanner({
    Key? key,
    required this.doctorId,
    required this.doctorName,
  }) : super(key: key);

  @override
  _DoctorNFCScannerState createState() => _DoctorNFCScannerState();
}

class _DoctorNFCScannerState extends State<DoctorNFCScanner> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Tap "Scan Patient Card" to begin';
  bool _success = false;
  bool _error = false;
  String? _cardId;
  String? _errorMessage;
  Map<String, dynamic>? _patientData;
  
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
    super.dispose();
  }

  // Start NFC scanning
  Future<void> _startNFCScanning() async {
    try {
      // Check if NFC is available
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
        _patientData = null;
        _statusMessage = 'Place patient\'s NFC card on the back of your device';
      });
      
      try {
        // Start NFC polling
        var tag = await FlutterNfcKit.poll();
        
        // Get the card ID
        String cardSerialNumber = tag.id;
        
        setState(() {
          _cardId = cardSerialNumber;
          _statusMessage = 'Card detected, checking patient information...';
        });
        
        // Check patient data
        await _checkPatientData(cardSerialNumber);
        
      } catch (e) {
        setState(() {
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Error reading card';
          _errorMessage = e.toString();
        });
      } finally {
        // Always finish the NFC session
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
  
  // Check patient data
  Future<void> _checkPatientData(String cardId) async {
    try {
      final databaseService = DatabaseService();
      
      // Look for patient with this card ID
      final patientData = await databaseService.getPatientByIC(cardId);
      
      if (patientData != null) {
        // Patient found
        setState(() {
          _cardId = cardId;
          _patientData = patientData;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Patient found';
        });
      } else {
        // Patient not found
        setState(() {
          _cardId = cardId;
          _patientData = null;
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Patient not found';
          _errorMessage = 'No patient is registered with this card. Please contact the registration desk.';
        });
      }
    } catch (e) {
      setState(() {
        _cardId = cardId;
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error checking patient data';
        _errorMessage = e.toString();
      });
    }
  }
  
  // Cancel scanning
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
  
  // Check if patient is assigned to this doctor
  bool _isPatientAssignedToThisDoctor() {
    if (_patientData == null) return false;
    return _patientData!['assignedDoctor'] == widget.doctorId;
  }
  
  // Navigate to prescription form
  void _createPrescription() {
    if (_patientData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionForm(
            patientId: _patientData!['patientId'],
            patientName: _patientData!['name'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Card Scanner', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _cardId = null;
                _patientData = null;
                _success = false;
                _error = false;
                _isScanning = false;
                _statusMessage = 'Tap "Scan Patient Card" to begin';
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
                // Doctor info header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.8),
                        Theme.of(context).primaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Icon(
                          Icons.local_hospital,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.doctorName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Patient Card Scanner',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.contactless,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 32),
                
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
                        'Patient Information Scanner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Scan any patient\'s NFC card to view their medical information, current assignment status, and create prescriptions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
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
                
                // Error message if available
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
                
                // Display patient info when found
                if (_patientData != null && _success) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Patient header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                _patientData!['name'].substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _patientData!['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'IC: ${_patientData!['patientId']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Assignment status
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isPatientAssignedToThisDoctor() 
                                ? Colors.green.withOpacity(0.1)
                                : _patientData!['assignedDoctor'] != null
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isPatientAssignedToThisDoctor() 
                                  ? Colors.green.withOpacity(0.3)
                                  : _patientData!['assignedDoctor'] != null
                                      ? Colors.orange.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isPatientAssignedToThisDoctor() 
                                    ? Icons.check_circle
                                    : _patientData!['assignedDoctor'] != null
                                        ? Icons.info
                                        : Icons.schedule,
                                color: _isPatientAssignedToThisDoctor() 
                                    ? Colors.green
                                    : _patientData!['assignedDoctor'] != null
                                        ? Colors.orange
                                        : Colors.grey[600],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isPatientAssignedToThisDoctor() 
                                      ? 'This patient is assigned to you'
                                      : _patientData!['assignedDoctor'] != null
                                          ? 'This patient is assigned to another doctor'
                                          : 'This patient is not assigned to any doctor yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isPatientAssignedToThisDoctor() 
                                        ? Colors.green[800]
                                        : _patientData!['assignedDoctor'] != null
                                            ? Colors.orange[800]
                                            : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Patient details
                        _buildPatientInfoRow('Date of Birth', _patientData!['dateOfBirth'] ?? 'Not recorded'),
                        _buildPatientInfoRow('Gender', _patientData!['gender'] ?? 'Not recorded'),
                        _buildPatientInfoRow('Phone', _patientData!['phone'] ?? 'Not recorded'),
                        if (_patientData!['bloodType'] != null)
                          _buildPatientInfoRow('Blood Type', _patientData!['bloodType']),
                        if (_patientData!['assignedRoom'] != null)
                          _buildPatientInfoRow('Assigned Room', _patientData!['assignedRoom']),
                        
                        // Allergies warning if any
                        if (_patientData!['allergies'] != null && (_patientData!['allergies'] as List).isNotEmpty) ...[
                          SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'ALLERGIES WARNING',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[800],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                ...(_patientData!['allergies'] as List).map<Widget>((allergy) {
                                  return Text(
                                    '• $allergy',
                                    style: TextStyle(color: Colors.red[700]),
                                  );
                                }).toList(),
                              ],
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
                      label: Text('Cancel Scanning'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (_success && _patientData != null)
                  // Patient found actions
                  Column(
                    children: [
                      if (_isPatientAssignedToThisDoctor()) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _createPrescription,
                            icon: Icon(Icons.medication),
                            label: Text('Create Prescription'),
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
                        SizedBox(height: 12),
                      ],
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _cardId = null;
                                  _patientData = null;
                                  _success = false;
                                  _statusMessage = 'Tap "Scan Patient Card" to begin';
                                });
                              },
                              icon: Icon(Icons.refresh),
                              label: Text('Scan Another'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back),
                              label: Text('Back'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      label: Text('Scan Patient Card'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                
                // Help text
                if (!_isScanning) ...[
                  SizedBox(height: 32),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.grey[600], size: 20),
                            SizedBox(width: 8),
                            Text(
                              'How to scan:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Place the patient\'s NFC card flat against the back of your device\n'
                          '• Keep the card in contact until scanning completes\n'
                          '• View patient information and assignment status\n'
                          '• Create prescriptions for assigned patients',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Add bottom padding for scrolling
                SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
                fontWeight: label == 'Blood Type' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}