import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';

class DoctorNFCCardScanner extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorNFCCardScanner({
    Key? key,
    required this.doctorId,
    required this.doctorName,
  }) : super(key: key);

  @override
  _DoctorNFCCardScannerState createState() => _DoctorNFCCardScannerState();
}

class _DoctorNFCCardScannerState extends State<DoctorNFCCardScanner> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Tap "Scan Patient Card" to begin';
  bool _success = false;
  bool _error = false;
  String? _cardId;
  String? _errorMessage;
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
    super.dispose();
  }

  // Start simple NFC scanning
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
        _existingPatientData = null;
        _statusMessage = 'Place patient\'s NFC card on the back of your device';
      });
      
      try {
        // Start NFC polling
        var tag = await FlutterNfcKit.poll();
        
        // Get the card ID - this is the simple approach you wanted
        String cardSerialNumber = tag.id;
        
        setState(() {
          _cardId = cardSerialNumber;
          _statusMessage = 'Card detected, checking patient information...';
        });
        
        // Check if this card is already registered
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
  
  // Simple card registration check
  Future<void> _checkCardRegistration(String cardId) async {
    try {
      final databaseService = DatabaseService();
      
      // Simple check: look for patient with this card ID
      final existingPatient = await databaseService.getPatientByIC(cardId);
      
      if (existingPatient != null) {
        // Card is already registered - patient found
        setState(() {
          _cardId = cardId;
          _existingPatientData = existingPatient;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Patient found';
        });
      } else {
        // Card is not registered - no patient found
        setState(() {
          _cardId = cardId;
          _existingPatientData = null;
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
        _statusMessage = 'Error checking patient information';
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
    if (_existingPatientData == null) return false;
    return _existingPatientData!['assignedDoctor'] == widget.doctorId;
  }
  
  // Navigate to prescription form
  void _createPrescription() {
    if (_existingPatientData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionForm(
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
        title: Text('Patient Card Scanner', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _cardId = null;
                _existingPatientData = null;
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
                              'Patient Information Scanner',
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
                        'Patient Card Scanner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Scan any patient\'s NFC card to view their medical information, assignment status, and create prescriptions if assigned to you.',
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
                
                // Display card info when successfully scanned
                if (_cardId != null && (_success || _error)) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_existingPatientData != null ? Colors.green : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (_existingPatientData != null ? Colors.green : Colors.orange).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _existingPatientData != null 
                                  ? Icons.person 
                                  : Icons.error,
                              color: _existingPatientData != null ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _existingPatientData != null 
                                  ? 'Patient Found' 
                                  : 'Patient Not Found',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: (_existingPatientData != null ? Colors.green : Colors.orange)[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        
                        Text(
                          'Card ID:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        SelectableText(
                          _cardId!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Display comprehensive patient information when found
                if (_existingPatientData != null && _success) ...[
                  SizedBox(height: 16),
                  
                  // Main Patient Card
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
                        // Patient Header with Photo
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                _existingPatientData!['name'].substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
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
                                    _existingPatientData!['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'IC: ${_existingPatientData!['patientId']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  if (_existingPatientData!['registrationDate'] != null) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      'Registered: ${_formatDate(_existingPatientData!['registrationDate'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Assignment Status Banner
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isPatientAssignedToThisDoctor() 
                                ? Colors.green.withOpacity(0.1)
                                : _existingPatientData!['assignedDoctor'] != null
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isPatientAssignedToThisDoctor() 
                                  ? Colors.green.withOpacity(0.3)
                                  : _existingPatientData!['assignedDoctor'] != null
                                      ? Colors.orange.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isPatientAssignedToThisDoctor() 
                                    ? Icons.check_circle
                                    : _existingPatientData!['assignedDoctor'] != null
                                        ? Icons.info
                                        : Icons.schedule,
                                color: _isPatientAssignedToThisDoctor() 
                                    ? Colors.green
                                    : _existingPatientData!['assignedDoctor'] != null
                                        ? Colors.orange
                                        : Colors.grey[600],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isPatientAssignedToThisDoctor() 
                                          ? 'ASSIGNED TO YOU'
                                          : _existingPatientData!['assignedDoctor'] != null
                                              ? 'ASSIGNED TO ANOTHER DOCTOR'
                                              : 'NOT ASSIGNED YET',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isPatientAssignedToThisDoctor() 
                                            ? Colors.green[800]
                                            : _existingPatientData!['assignedDoctor'] != null
                                                ? Colors.orange[800]
                                                : Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (_existingPatientData!['assignedDoctor'] != null && !_isPatientAssignedToThisDoctor())
                                      FutureBuilder<String>(
                                        future: _getDoctorName(_existingPatientData!['assignedDoctor']),
                                        builder: (context, snapshot) {
                                          return Text(
                                            'Doctor: ${snapshot.data ?? 'Loading...'}',
                                            style: TextStyle(
                                              color: Colors.orange[700],
                                              fontSize: 11,
                                            ),
                                          );
                                        },
                                      ),
                                    if (_existingPatientData!['assignedRoom'] != null)
                                      Text(
                                        'Room: ${_existingPatientData!['assignedRoom']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Personal Information Section
                  _buildInfoSection(
                    title: 'Personal Information',
                    icon: Icons.person,
                    color: Colors.blue,
                    children: [
                      _buildDetailRow('Date of Birth', _existingPatientData!['dateOfBirth'] ?? 'Not recorded'),
                      _buildDetailRow('Gender', _existingPatientData!['gender'] ?? 'Not recorded'),
                      _buildDetailRow('Phone', _existingPatientData!['phone'] ?? 'Not recorded'),
                      _buildDetailRow('Email', _existingPatientData!['email'] ?? 'Not recorded'),
                      _buildDetailRow('Address', _existingPatientData!['address'] ?? 'Not recorded'),
                      if (_existingPatientData!['emergencyContact'] != null)
                        _buildDetailRow('Emergency Contact', _existingPatientData!['emergencyContact']),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Medical Information Section
                  _buildInfoSection(
                    title: 'Medical Information',
                    icon: Icons.medical_information,
                    color: Colors.purple,
                    children: [
                      if (_existingPatientData!['bloodType'] != null)
                        _buildDetailRow('Blood Type', _existingPatientData!['bloodType'], 
                            valueColor: Colors.red[700], isBold: true),
                      _buildDetailRow('Registration Date', _formatDate(_existingPatientData!['registrationDate'])),
                      _buildDetailRow('Last Updated', _formatDate(_existingPatientData!['lastUpdated'])),
                    ],
                  ),
                  
                  // Critical Medical Alerts
                  if (_existingPatientData!['allergies'] != null && (_existingPatientData!['allergies'] as List).isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildMedicalAlert(
                      title: '⚠️ ALLERGIES WARNING',
                      items: _existingPatientData!['allergies'] as List,
                      color: Colors.red,
                      icon: Icons.dangerous,
                    ),
                  ],
                  
                  // Current Medications
                  if (_existingPatientData!['medications'] != null && (_existingPatientData!['medications'] as List).isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildMedicalAlert(
                      title: '💊 CURRENT MEDICATIONS',
                      items: _existingPatientData!['medications'] as List,
                      color: Colors.blue,
                      icon: Icons.medication,
                    ),
                  ],
                  
                  // Medical Conditions
                  if (_existingPatientData!['conditions'] != null && (_existingPatientData!['conditions'] as List).isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildMedicalAlert(
                      title: '🏥 MEDICAL CONDITIONS',
                      items: _existingPatientData!['conditions'] as List,
                      color: Colors.orange,
                      icon: Icons.healing,
                    ),
                  ],
                  
                  // Quick Stats
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Allergies',
                          (_existingPatientData!['allergies'] as List?)?.length.toString() ?? '0',
                          Colors.red,
                          Icons.dangerous,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Medications',
                          (_existingPatientData!['medications'] as List?)?.length.toString() ?? '0',
                          Colors.blue,
                          Icons.medication,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Conditions',
                          (_existingPatientData!['conditions'] as List?)?.length.toString() ?? '0',
                          Colors.orange,
                          Icons.healing,
                        ),
                      ),
                    ],
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
                else if (_success && _existingPatientData != null)
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
                                  _existingPatientData = null;
                                  _success = false;
                                  _error = false;
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
                          '• Create prescriptions for patients assigned to you',
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

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
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
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get doctor name
  Future<String> _getDoctorName(String doctorId) async {
    try {
      final databaseService = DatabaseService();
      final doctorData = await databaseService.getDoctorById(doctorId);
      return doctorData?['name'] ?? 'Unknown Doctor';
    } catch (e) {
      return 'Unknown Doctor';
    }
  }

  // Helper method to format dates
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Not available';
    
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
      
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Build information section
  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Build medical alert section
  Widget _buildMedicalAlert({
    required String title,
    required List items,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.black87, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...items.map<Widget>((item) {
            return Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Build stat card
  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}