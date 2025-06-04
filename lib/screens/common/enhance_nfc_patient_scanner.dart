import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';

class EnhancedNFCPatientScanner extends StatefulWidget {
  final String userRole; // 'doctor', 'nurse', 'pharmacist'
  final String? userId; // current user ID
  final String? userName; // current user name

  const EnhancedNFCPatientScanner({
    Key? key,
    required this.userRole,
    this.userId,
    this.userName,
  }) : super(key: key);

  @override
  _EnhancedNFCPatientScannerState createState() => _EnhancedNFCPatientScannerState();
}

class _EnhancedNFCPatientScannerState extends State<EnhancedNFCPatientScanner> 
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Tap "Scan Patient Card" to begin';
  bool _success = false;
  bool _error = false;
  String? _cardId;
  String? _errorMessage;
  Map<String, dynamic>? _patientData;
  List<Map<String, dynamic>>? _prescriptions;
  Map<String, dynamic>? _assignmentInfo;
  
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

  // Start NFC scanning
  Future<void> _startNFCScanning() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      
      if (availability != NFCAvailability.available) {
        setState(() {
          _statusMessage = 'NFC is not available on this device';
          _error = true;
          _isScanning = false;
          _errorMessage = 'Please enable NFC and try again.';
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
        _prescriptions = null;
        _assignmentInfo = null;
        _statusMessage = 'Place patient\'s NFC card on the back of your device';
      });
      
      try {
        var tag = await FlutterNfcKit.poll();
        String cardSerialNumber = tag.id;
        
        setState(() {
          _cardId = cardSerialNumber;
          _statusMessage = 'Card detected, loading patient information...';
        });
        
        await _loadPatientData(cardSerialNumber);
        
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
  
  // Load all patient data including prescriptions and assignments
  Future<void> _loadPatientData(String cardId) async {
    try {
      final databaseService = DatabaseService();
      
      // Get patient basic info
      final patientInfo = await databaseService.getPatientByIC(cardId);
      
      if (patientInfo == null) {
        setState(() {
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Patient not found';
          _errorMessage = 'No patient is registered with this card.';
        });
        return;
      }
      
      // Get patient prescriptions
      final prescriptions = await databaseService.getPrescriptionsByPatient(cardId);
      
      // Get assignment/appointment info if exists
      Map<String, dynamic>? assignmentInfo;
      if (patientInfo['currentAppointment'] != null) {
        assignmentInfo = await databaseService.getAppointmentById(patientInfo['currentAppointment']);
        
        // Get doctor info for the assignment
        if (assignmentInfo != null && assignmentInfo['doctorId'] != null) {
          final doctorInfo = await databaseService.getDoctorById(assignmentInfo['doctorId']);
          if (doctorInfo != null) {
            assignmentInfo['doctorName'] = doctorInfo['name'];
            assignmentInfo['doctorSpecialization'] = doctorInfo['specialization'];
          }
        }
      }
      
      setState(() {
        _patientData = patientInfo;
        _prescriptions = prescriptions;
        _assignmentInfo = assignmentInfo;
        _success = true;
        _error = false;
        _isScanning = false;
        _statusMessage = 'Patient information loaded successfully';
      });
      
    } catch (e) {
      setState(() {
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error loading patient data';
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
  
  // Get role-specific title
  String _getRoleTitle() {
    switch (widget.userRole) {
      case 'doctor':
        return 'Doctor - Patient Scanner';
      case 'nurse':
        return 'Nurse - Patient Scanner';
      case 'pharmacist':
        return 'Pharmacist - Patient Scanner';
      default:
        return 'Patient Scanner';
    }
  }
  
  // Check if current user can perform actions on this patient
  bool _canPerformActions() {
    if (_patientData == null) return false;
    
    if (widget.userRole == 'doctor') {
      // Doctor can only act on patients assigned to them
      return _assignmentInfo?['doctorId'] == widget.userId;
    } else if (widget.userRole == 'nurse') {
      // Nurse can assign doctors to unassigned patients
      return true;
    } else if (widget.userRole == 'pharmacist') {
      // Pharmacist can dispense to any patient with prescriptions
      return _prescriptions != null && _prescriptions!.isNotEmpty;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getRoleTitle(), style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _cardId = null;
                _patientData = null;
                _prescriptions = null;
                _assignmentInfo = null;
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // User info header
              if (widget.userName != null)
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
                          widget.userRole == 'doctor' ? Icons.medical_services :
                          widget.userRole == 'nurse' ? Icons.local_hospital :
                          Icons.medication,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.userRole.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              SizedBox(height: 24),
              
              // NFC animation or status icon
              if (_isScanning)
                ScaleTransition(
                  scale: _animation,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contactless,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                )
              else if (_success)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green,
                  ),
                )
              else if (_error)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error,
                    size: 60,
                    color: Colors.red,
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.contactless,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              
              SizedBox(height: 24),
              
              // Status message
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _error ? Colors.red : _success ? Colors.green : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Error message
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
              
              // Patient Information (when successful)
              if (_patientData != null && _success) ...[
                _buildPatientInfoCard(),
                SizedBox(height: 16),
                
                // Assignment Information
                if (_assignmentInfo != null)
                  _buildAssignmentInfoCard(),
                
                SizedBox(height: 16),
                
                // Prescriptions Information
                if (_prescriptions != null && _prescriptions!.isNotEmpty)
                  _buildPrescriptionsCard(),
                
                SizedBox(height: 24),
              ],
              
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
                    ),
                  ),
                )
              else if (_success && _patientData != null)
                _buildActionButtons()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startNFCScanning,
                    icon: Icon(Icons.contactless),
                    label: Text('Scan Patient Card'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPatientInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    _patientData!['name'].substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _patientData!['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'IC: ${_patientData!['patientId']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            _buildInfoRow('Date of Birth', _patientData!['dateOfBirth'] ?? 'Not recorded'),
            _buildInfoRow('Gender', _patientData!['gender'] ?? 'Not recorded'),
            _buildInfoRow('Phone', _patientData!['phone'] ?? 'Not recorded'),
            if (_patientData!['bloodType'] != null)
              _buildInfoRow('Blood Type', _patientData!['bloodType'], 
                  valueColor: Colors.red[700]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAssignmentInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_ind, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Current Assignment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            Divider(),
            _buildInfoRow('Doctor', _assignmentInfo!['doctorName'] ?? 'Unknown'),
            if (_assignmentInfo!['doctorSpecialization'] != null)
              _buildInfoRow('Specialization', _assignmentInfo!['doctorSpecialization']),
            _buildInfoRow('Room', _assignmentInfo!['roomNumber'] ?? 'Not assigned'),
            if (_assignmentInfo!['notes'] != null && _assignmentInfo!['notes'].toString().isNotEmpty)
              _buildInfoRow('Notes', _assignmentInfo!['notes']),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrescriptionsCard() {
    final pendingPrescriptions = _prescriptions!.where((p) => p['status'] == 'pending').toList();
    final completedPrescriptions = _prescriptions!.where((p) => p['status'] != 'pending').toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Prescriptions (${_prescriptions!.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            Divider(),
            
            if (pendingPrescriptions.isNotEmpty) ...[
              Text(
                'Pending (${pendingPrescriptions.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              SizedBox(height: 8),
              ...pendingPrescriptions.take(2).map((prescription) => 
                _buildPrescriptionSummary(prescription)),
            ],
            
            if (completedPrescriptions.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                'Completed (${completedPrescriptions.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              SizedBox(height: 8),
              ...completedPrescriptions.take(2).map((prescription) => 
                _buildPrescriptionSummary(prescription)),
            ],
            
            if (_prescriptions!.length > 4) ...[
              SizedBox(height: 8),
              Text(
                'And ${_prescriptions!.length - 4} more prescriptions...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrescriptionSummary(Map<String, dynamic> prescription) {
    final status = prescription['status'] ?? 'pending';
    final color = status == 'pending' ? Colors.orange : 
                  status == 'dispensed' ? Colors.blue : Colors.green;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  prescription['diagnosis'] ?? 'No diagnosis',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (prescription['medications'] != null) ...[
            SizedBox(height: 4),
            Text(
              '${(prescription['medications'] as List).length} medication(s)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    List<Widget> buttons = [];
    
    if (widget.userRole == 'doctor' && _canPerformActions()) {
      buttons.add(
        ElevatedButton.icon(
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
          icon: Icon(Icons.medication),
          label: Text('Create Prescription'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }
    
    if (widget.userRole == 'nurse') {
      if (_assignmentInfo == null) {
        buttons.add(
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignDoctorScreen(
                    patientId: _patientData!['patientId'],
                    patientName: _patientData!['name'],
                  ),
                ),
              );
            },
            icon: Icon(Icons.assignment_ind),
            label: Text('Assign Doctor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        );
      }
    }
    
    buttons.add(
      OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _cardId = null;
            _patientData = null;
            _prescriptions = null;
            _assignmentInfo = null;
            _success = false;
            _statusMessage = 'Tap "Scan Patient Card" to begin';
          });
        },
        icon: Icon(Icons.refresh),
        label: Text('Scan Another'),
      ),
    );
    
    return Column(
      children: buttons.map((button) => 
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: SizedBox(width: double.infinity, child: button),
        )
      ).toList(),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
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
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontSize: 13,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}