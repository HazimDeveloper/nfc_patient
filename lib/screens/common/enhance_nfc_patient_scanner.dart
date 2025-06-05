import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';
import 'package:nfc_patient_registration/screens/pharmacist/prescription_view.dart';

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
    with TickerProviderStateMixin {
  
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isScanning = false;
  bool _nfcAvailable = false;
  String _statusMessage = 'Tap "Start Scanning" to begin';
  Map<String, dynamic>? _patientData;
  List<Map<String, dynamic>> _patientHistory = [];
  String? _error;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeNFC();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isScanning) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  Future<void> _initializeNFC() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      setState(() {
        _nfcAvailable = isAvailable;
        if (!isAvailable) {
          _statusMessage = 'NFC is not available on this device';
          _error = 'Please ensure NFC is enabled in device settings';
        }
      });
    } catch (e) {
      setState(() {
        _nfcAvailable = false;
        _statusMessage = 'Error initializing NFC';
        _error = e.toString();
      });
    }
  }

  Future<void> _startScanning() async {
    if (!_nfcAvailable) {
      _showSnackBar('NFC is not available', Colors.red);
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold your device near the patient\'s NFC card...';
      _patientData = null;
      _patientHistory = [];
      _error = null;
    });

    _pulseController.repeat();

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          await _processNFCTag(tag);
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error starting NFC scan';
        _error = e.toString();
      });
      _pulseController.stop();
    }
  }

  Future<void> _processNFCTag(NfcTag tag) async {
    try {
      HapticFeedback.mediumImpact();
      
      // Extract card ID from NFC tag
      String? cardId = _extractCardId(tag);
      
      if (cardId == null || cardId.isEmpty) {
        throw Exception('Could not read card ID from NFC tag');
      }

      print('Card ID detected: $cardId');
      setState(() {
        _statusMessage = 'Card detected! Looking up patient...';
      });

      // FIXED: Find patient by card serial number
      final patientData = await _findPatientByCard(cardId);
      
      if (patientData == null) {
        setState(() {
          _statusMessage = 'Patient not found';
          _error = 'No patient is registered with this card.';
          _isScanning = false;
        });
        _pulseController.stop();
        await NfcManager.instance.stopSession(errorMessage: 'Patient not found');
        return;
      }

      // FIXED: Load patient history for all roles
      final history = await _loadPatientHistory(patientData['patientId']);

      setState(() {
        _patientData = patientData;
        _patientHistory = history;
        _statusMessage = 'Patient found: ${patientData['name']}';
        _isScanning = false;
      });

      _pulseController.stop();
      await NfcManager.instance.stopSession();
      
      HapticFeedback.selectionClick();

    } catch (e) {
      print('Error processing NFC tag: $e');
      setState(() {
        _statusMessage = 'Error reading card';
        _error = e.toString();
        _isScanning = false;
      });
      _pulseController.stop();
      await NfcManager.instance.stopSession();
    }
  }

  // FIXED: Find patient by card serial number
  Future<Map<String, dynamic>?> _findPatientByCard(String cardSerialNumber) async {
    try {
      print('Searching for patient with card: $cardSerialNumber');
      
      // Search for patient with this card serial number
      final snapshot = await _databaseService.patientsCollection
          .where('cardSerialNumber', isEqualTo: cardSerialNumber)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final patientData = snapshot.docs.first.data() as Map<String, dynamic>;
        print('Patient found: ${patientData['name']}');
        return patientData;
      }
      
      print('No patient found with card: $cardSerialNumber');
      return null;
      
    } catch (e) {
      print('Error finding patient by card: $e');
      return null;
    }
  }

  // FIXED: Load complete patient history
  Future<List<Map<String, dynamic>>> _loadPatientHistory(String patientId) async {
    try {
      print('Loading history for patient: $patientId');
      
      List<Map<String, dynamic>> history = [];
      
      // Load appointments
      final appointments = await _databaseService.getAppointmentsByPatient(patientId);
      for (var appointment in appointments) {
        appointment['type'] = 'appointment';
        history.add(appointment);
      }
      
      // Load prescriptions
      final prescriptions = await _databaseService.getPrescriptionsByPatient(patientId);
      for (var prescription in prescriptions) {
        prescription['type'] = 'prescription';
        history.add(prescription);
      }
      
      // Sort by date (newest first)
      history.sort((a, b) {
        final aDate = a['createdAt'] ?? a['appointmentDate'] ?? DateTime.now();
        final bDate = b['createdAt'] ?? b['appointmentDate'] ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      
      print('Loaded ${history.length} history items');
      return history;
      
    } catch (e) {
      print('Error loading patient history: $e');
      return [];
    }
  }

  String? _extractCardId(NfcTag tag) {
    try {
      // Try different methods to extract card ID
      if (tag.data['nfca'] != null) {
        final nfcaData = tag.data['nfca'] as Map<String, dynamic>;
        if (nfcaData['identifier'] != null) {
          final identifier = nfcaData['identifier'] as List<int>;
          return identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
        }
      }
      
      if (tag.data['nfcb'] != null) {
        final nfcbData = tag.data['nfcb'] as Map<String, dynamic>;
        if (nfcbData['identifier'] != null) {
          final identifier = nfcbData['identifier'] as List<int>;
          return identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
        }
      }
      
      if (tag.data['nfcf'] != null) {
        final nfcfData = tag.data['nfcf'] as Map<String, dynamic>;
        if (nfcfData['identifier'] != null) {
          final identifier = nfcfData['identifier'] as List<int>;
          return identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
        }
      }
      
      if (tag.data['nfcv'] != null) {
        final nfcvData = tag.data['nfcv'] as Map<String, dynamic>;
        if (nfcvData['identifier'] != null) {
          final identifier = nfcvData['identifier'] as List<int>;
          return identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
        }
      }
      
      return null;
    } catch (e) {
      print('Error extracting card ID: $e');
      return null;
    }
  }

  void _stopScanning() {
    if (_isScanning) {
      NfcManager.instance.stopSession();
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scanning stopped';
      });
      _pulseController.stop();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_getRoleTitle()} - Patient Scanner'),
        backgroundColor: _getRoleColor(),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header section
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
                  // NFC Scanning Area
                  _buildScanningArea(),
                  
                  SizedBox(height: 20),
                  
                  // Patient Information
                  if (_patientData != null) _buildPatientInfo(),
                  
                  // Patient History
                  if (_patientHistory.isNotEmpty) _buildPatientHistory(),
                  
                  // Error display
                  if (_error != null) _buildErrorDisplay(),
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
          // NFC Animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isScanning 
                      ? _getRoleColor().withOpacity(0.1 + (_pulseAnimation.value * 0.3))
                      : Colors.grey.withOpacity(0.1),
                  border: Border.all(
                    color: _isScanning ? _getRoleColor() : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.contactless,
                  size: 60,
                  color: _isScanning ? _getRoleColor() : Colors.grey,
                ),
              );
            },
          ),
          
          SizedBox(height: 20),
          
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 20),
          
          // Scan Button
          if (!_isScanning)
            ElevatedButton.icon(
              onPressed: _nfcAvailable ? _startScanning : null,
              icon: Icon(Icons.contactless),
              label: Text('Start Scanning'),
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
              onPressed: _stopScanning,
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
            ),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.green),
              SizedBox(width: 10),
              Text(
                'Patient Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildInfoRow('Name', _patientData!['name'] ?? 'Unknown'),
          _buildInfoRow('IC Number', _patientData!['icNumber'] ?? _patientData!['patientId'] ?? 'Unknown'),
          _buildInfoRow('Phone', _patientData!['phone'] ?? 'Not provided'),
          _buildInfoRow('Gender', _patientData!['gender'] ?? 'Not specified'),
          
          SizedBox(height: 15),
          
          // Role-specific action buttons
          _buildRoleSpecificActions(),
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
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSpecificActions() {
    return Row(
      children: [
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
                      doctorId: widget.userId,
                      doctorName: widget.userName,
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

  Widget _buildPatientHistory() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: _getRoleColor()),
              SizedBox(width: 10),
              Text(
                'Patient History (${_patientHistory.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          
          ...List.generate(
            _patientHistory.length > 5 ? 5 : _patientHistory.length,
            (index) => _buildHistoryItem(_patientHistory[index]),
          ),
          
          if (_patientHistory.length > 5)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Showing latest 5 of ${_patientHistory.length} records',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final isPresciption = item['type'] == 'prescription';
    final date = item['createdAt'] ?? item['appointmentDate'] ?? DateTime.now();
    
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPresciption ? Icons.medication : Icons.calendar_today,
                size: 16,
                color: isPresciption ? Colors.purple : Colors.blue,
              ),
              SizedBox(width: 5),
              Text(
                isPresciption ? 'Prescription' : 'Appointment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPresciption ? Colors.purple : Colors.blue,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          if (isPresciption) ...[
            Text(
              'Diagnosis: ${item['diagnosis'] ?? 'Not specified'}',
              style: TextStyle(fontSize: 13),
            ),
            if (item['medications'] != null && item['medications'].isNotEmpty)
              Text(
                'Medications: ${item['medications'].length} prescribed',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
          ] else ...[
            Text(
              'Doctor: ${item['doctorName'] ?? 'Unknown'}',
              style: TextStyle(fontSize: 13),
            ),
            Text(
              'Status: ${item['status'] ?? 'Unknown'}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
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
            'Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

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