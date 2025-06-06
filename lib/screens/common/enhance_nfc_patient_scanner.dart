import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';

class EnhancedNFCPatientScanner extends StatefulWidget {
  final String userRole; // 'doctor', 'nurse', 'pharmacist'
  final String userId;
  final String userName;

  const EnhancedNFCPatientScanner({
    Key? key,
    required this.userRole,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  _EnhancedNFCPatientScannerState createState() => _EnhancedNFCPatientScannerState();
}

class _EnhancedNFCPatientScannerState extends State<EnhancedNFCPatientScanner> 
    with SingleTickerProviderStateMixin {
  
  final DatabaseService _databaseService = DatabaseService();
  
  // Simple state variables - like NFCCardRegistration
  bool _isScanning = false;
  String _statusMessage = 'Tap "Scan Patient Card" to begin';
  bool _success = false;
  bool _error = false;
  String? _cardId;
  String? _errorMessage;
  Map<String, dynamic>? _patientData;
  
  // Animation controller for scanning animation
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
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
    if (_isScanning) {
      FlutterNfcKit.finish();
    }
    super.dispose();
  }

  // Start NFC scanning - similar to NFCCardRegistration
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
      
      // Start scanning
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
        // Scan for NFC card
        var tag = await FlutterNfcKit.poll();
        String cardSerialNumber = tag.id;
        
        setState(() {
          _cardId = cardSerialNumber;
          _statusMessage = 'Card detected, looking up patient...';
        });
        
        // Find patient by card ID
        await _findPatient(cardSerialNumber);
        
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

  // Find patient by card serial number - simple and clear
  Future<void> _findPatient(String cardId) async {
    try {
      print('Looking for patient with card: $cardId');
      
      // Search for patient with this card
      final patientData = await _databaseService.findPatientByCardSerial(cardId);
      
      if (patientData != null) {
        // Patient found!
        setState(() {
          _cardId = cardId;
          _patientData = patientData;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Patient found: ${patientData['name']}';
        });
        
        // Add haptic feedback for success
        HapticFeedback.selectionClick();
      } else {
        // Patient not found
        setState(() {
          _cardId = cardId;
          _patientData = null;
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Patient not found';
          _errorMessage = 'No patient is registered with this card.';
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

  // Reset to scan again
  void _resetScanner() {
    setState(() {
      _cardId = null;
      _patientData = null;
      _success = false;
      _error = false;
      _isScanning = false;
      _statusMessage = 'Tap "Scan Patient Card" to begin';
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_getRoleTitle()} - Patient Scanner'),
        backgroundColor: _getRoleColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetScanner,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section - same design as before
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getRoleColor(),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _getRoleIcon(),
                  size: 50,
                  color: Colors.white,
                ),
                SizedBox(height: 10),
                Text(
                  widget.userRole.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // NFC Scanning Area - same design as NFCCardRegistration
                  _buildScanningArea(),
                  
                  SizedBox(height: 20),
                  
                  // Show patient info if found
                  if (_patientData != null) _buildPatientInfoCard(),
                  
                  // Show error if any
                  if (_error && _errorMessage != null) _buildErrorCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningArea() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // NFC Animation - same as NFCCardRegistration
          if (_isScanning)
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: _getRoleColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.contactless,
                  size: 100,
                  color: _getRoleColor(),
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
          
          SizedBox(height: 20),
          
          // Status message
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _error ? Colors.red : _success ? Colors.green : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 20),
          
          // Scan/Action Buttons
          if (_isScanning)
            ElevatedButton.icon(
              onPressed: _cancelScanning,
              icon: Icon(Icons.stop),
              label: Text('Stop Scanning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            )
          else if (_success || _error)
            ElevatedButton.icon(
              onPressed: _resetScanner,
              icon: Icon(Icons.refresh),
              label: Text('Scan Another Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getRoleColor(),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _startNFCScanning,
              icon: Icon(Icons.contactless),
              label: Text('Scan Patient Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getRoleColor(),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.person, color: Colors.green),
              SizedBox(width: 10),
              Text(
                'Patient Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          
          // Patient basic info
          _buildInfoRow('Name', _patientData!['name'] ?? 'Unknown'),
          _buildInfoRow('IC Number', _patientData!['icNumber'] ?? _patientData!['patientId'] ?? 'Unknown'),
          _buildInfoRow('Phone', _patientData!['phone'] ?? 'Not provided'),
          _buildInfoRow('Gender', _patientData!['gender'] ?? 'Not specified'),
          
          SizedBox(height: 15),
          
          // Action buttons based on role
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        children: [
          Icon(Icons.error, color: Colors.red, size: 50),
          SizedBox(height: 10),
          Text(
            'Patient Not Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
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
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // View Details button - available for all roles
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientDetailsScreen(
                    patient: _patientData!,
                  ),
                ),
              );
            },
            icon: Icon(Icons.visibility),
            label: Text('View Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        
        // Doctor-specific action
        if (widget.userRole == 'doctor') ...[
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrescriptionForm(
                      patientId: _patientData!['patientId'],
                      patientName: _patientData!['name'],
                    ),
                  ),
                );
              },
              icon: Icon(Icons.medical_services),
              label: Text('Prescribe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Helper methods for role-based styling
  String _getRoleTitle() {
    switch (widget.userRole) {
      case 'doctor':
        return 'Doctor';
      case 'nurse':
        return 'Nurse';
      case 'pharmacist':
        return 'Pharmacist';
      default:
        return 'Staff';
    }
  }

  Color _getRoleColor() {
    switch (widget.userRole) {
      case 'doctor':
        return Colors.blue;
      case 'nurse':
        return Colors.green;
      case 'pharmacist':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  IconData _getRoleIcon() {
    switch (widget.userRole) {
      case 'doctor':
        return Icons.medical_services;
      case 'nurse':
        return Icons.local_hospital;
      case 'pharmacist':
        return Icons.medication;
      default:
        return Icons.person;
    }
  }
}