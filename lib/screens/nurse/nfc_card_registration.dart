import 'dart:async';
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
        _statusMessage = 'Place NFC card on the back of your device';
      });
      
      try {
        // Start NFC polling
        var tag = await FlutterNfcKit.poll();
        
        // Get the card ID - this is the simple approach you wanted
        String cardSerialNumber = tag.id;
        
        setState(() {
          _cardId = cardSerialNumber;
          _statusMessage = 'Card detected, checking registration...';
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
        // Card is already registered
        setState(() {
          _cardId = cardId;
          _existingPatientData = existingPatient;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Patient found with this card';
        });
      } else {
        // Card is not registered - available for new registration
        setState(() {
          _cardId = cardId;
          _existingPatientData = null;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Card is available for new patient registration';
        });
      }
    } catch (e) {
      setState(() {
        _cardId = cardId;
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error checking card registration';
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
  
  // Navigate to patient registration
  void _proceedToRegistration() {
    if (_cardId == null || _cardId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No card ID detected. Please scan the card again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check that this is not an already registered card
    if (_existingPatientData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This card is already registered to ${_existingPatientData!['name']}. Please use a different card.'),
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
  
  // View existing patient details
  void _viewExistingPatient() {
    if (_existingPatientData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientDetailsScreen(
            patient: _existingPatientData!,
          ),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Card Registration', style: TextStyle(color: Colors.white)),
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
                        'NFC Card Registration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Scan an NFC card to register a new patient or view existing patient information. Each card can only be registered to one patient.',
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
                      color: (_existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (_existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _existingPatientData != null 
                                  ? Icons.person 
                                  : _success 
                                      ? Icons.check_circle 
                                      : Icons.credit_card,
                              color: _existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _existingPatientData != null 
                                  ? 'Patient Found' 
                                  : _success 
                                      ? 'Card Available for Registration'
                                      : 'Error Reading Card',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: (_existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange)[800],
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
                            color: _existingPatientData!['assignedDoctor'] != null
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _existingPatientData!['assignedDoctor'] != null
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _existingPatientData!['assignedDoctor'] != null
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color: _existingPatientData!['assignedDoctor'] != null
                                    ? Colors.green
                                    : Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _existingPatientData!['assignedDoctor'] != null
                                          ? 'ASSIGNED TO DOCTOR'
                                          : 'NOT ASSIGNED YET',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _existingPatientData!['assignedDoctor'] != null
                                            ? Colors.green[800]
                                            : Colors.orange[800],
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (_existingPatientData!['assignedDoctor'] != null)
                                      FutureBuilder<String>(
                                        future: _getDoctorName(_existingPatientData!['assignedDoctor']),
                                        builder: (context, snapshot) {
                                          return Text(
                                            'Doctor: ${snapshot.data ?? 'Loading...'}',
                                            style: TextStyle(
                                              color: Colors.green[700],
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
                      label: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (_success && _cardId != null && _existingPatientData != null)
                  // Existing patient actions
                  Column(
                    children: [
                      // Check if patient needs doctor assignment
                      if (_existingPatientData!['currentAppointment'] == null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AssignDoctorScreen(
                                    patientId: _existingPatientData!['patientId'],
                                    patientName: _existingPatientData!['name'],
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.assignment_ind),
                            label: Text('Assign Doctor & Room'),
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
                      ] else
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Patient already assigned to doctor',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _viewExistingPatient,
                              icon: Icon(Icons.visibility),
                              label: Text('View Details'),
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
                              label: Text('Scan Different'),
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
                else if (_success && _cardId != null && _existingPatientData == null)
                  // Card available for new registration
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _proceedToRegistration,
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
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _cardId = null;
                              _existingPatientData = null;
                              _success = false;
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
                          '• Place the NFC card flat against the back of your device\n'
                          '• Keep the card in contact until scanning completes\n'
                          '• If the card is already registered, view patient details\n'
                          '• If the card is new, proceed to patient registration',
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
                    color: Colors.grey[800],
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
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}