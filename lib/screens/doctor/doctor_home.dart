import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/screens/doctor/patient_list.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';
import 'package:nfc_patient_registration/screens/doctor/doctor_nfc_scanner.dart';

class DoctorHome extends StatefulWidget {
  @override
  _DoctorHomeState createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String? _error;
  String? _currentDoctorId;
  Map<String, dynamic>? _doctorInfo;

  @override
  void initState() {
    super.initState();
    _initializeDoctor();
  }

  // Initialize doctor and load patients
  Future<void> _initializeDoctor() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userEmail = authService.currentUser?.email;
      
      if (userEmail != null) {
        // Map email to doctor ID (you should store this mapping in your auth system)
        _currentDoctorId = _mapEmailToDoctorId(userEmail);
        _doctorInfo = await _databaseService.getDoctorById(_currentDoctorId!);
        
        if (_currentDoctorId != null) {
          await _loadPatients();
        } else {
          setState(() {
            _error = 'Unable to identify doctor profile';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'No user logged in';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error initializing: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Map email to doctor ID (in real app, this should be stored in database)
  String? _mapEmailToDoctorId(String email) {
    switch (email) {
      case 'doctor1@hospital.com':
        return 'doctor1';
      case 'doctor2@hospital.com':
        return 'doctor2';
      case 'doctor3@hospital.com':
        return 'doctor3';
      default:
        return null;
    }
  }

  // Load assigned patients
  Future<void> _loadPatients() async {
    if (_currentDoctorId == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final patients = await _databaseService.getPatientsByDoctor(_currentDoctorId!);
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading patients: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Handle NFC card scan
  void _handleNFCScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorNFCScanner(
          doctorId: _currentDoctorId!,
          doctorName: _doctorInfo?['name'] ?? 'Doctor',
        ),
      ),
    ).then((_) => _loadPatients()); // Refresh patient list when returning
  }

  // Handle scanned patient data
  Future<void> _handleScannedPatientData(Map<String, dynamic> data) async {
    try {
      String? patientIC;
      
      // Extract IC from various possible fields
      if (data.containsKey('cardSerialNumber') && data['cardSerialNumber'] != null) {
        patientIC = data['cardSerialNumber'].toString();
      } else if (data.containsKey('patientId') && data['patientId'] != null) {
        patientIC = data['patientId'].toString();
      } else if (data.containsKey('id') && data['id'] != null) {
        patientIC = data['id'].toString();
      }

      if (patientIC == null || patientIC.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to read patient IC from card'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Looking up patient...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Get patient data using IC
      final patientData = await _databaseService.getPatientByIC(patientIC);

      // Close loading dialog
      Navigator.pop(context);

      if (patientData != null) {
        // Check if patient is assigned to this doctor
        final isAssignedToThisDoctor = patientData['assignedDoctor'] == _currentDoctorId;
        
        if (isAssignedToThisDoctor) {
          // Show patient details dialog with actions
          _showPatientDetailsDialog(patientData);
        } else {
          // Show patient info but limited actions
          _showUnassignedPatientDialog(patientData);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient not found with IC: $patientIC'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error looking up patient: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show patient details dialog for assigned patients
  void _showPatientDetailsDialog(Map<String, dynamic> patientData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                patientData['name'].substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientData['name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'IC: ${patientData['patientId']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                        'This patient is assigned to you',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              _buildPatientInfoRow('Date of Birth', patientData['dateOfBirth'] ?? 'Unknown'),
              _buildPatientInfoRow('Gender', patientData['gender'] ?? 'Unknown'),
              _buildPatientInfoRow('Phone', patientData['phone'] ?? 'Unknown'),
              _buildPatientInfoRow('Room', patientData['assignedRoom'] ?? 'Not assigned'),
              if (patientData['bloodType'] != null)
                _buildPatientInfoRow('Blood Type', patientData['bloodType']),
              
              // Show allergies if any
              if (patientData['allergies'] != null && (patientData['allergies'] as List).isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  'Allergies:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: (patientData['allergies'] as List).map<Widget>((allergy) {
                      return Text(
                        '• $allergy',
                        style: TextStyle(color: Colors.red[700]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrescriptionForm(
                    patientId: patientData['patientId'],
                    patientName: patientData['name'],
                  ),
                ),
              );
            },
            icon: Icon(Icons.medication),
            label: Text('Prescribe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog for unassigned patients
  void _showUnassignedPatientDialog(Map<String, dynamic> patientData) {
    final isAssigned = patientData['assignedDoctor'] != null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(
                patientData['name'].substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientData['name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'IC: ${patientData['patientId']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAssigned 
                          ? 'This patient is assigned to another doctor'
                          : 'This patient is not assigned to any doctor yet',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildPatientInfoRow('Date of Birth', patientData['dateOfBirth'] ?? 'Unknown'),
            _buildPatientInfoRow('Gender', patientData['gender'] ?? 'Unknown'),
            _buildPatientInfoRow('Phone', patientData['phone'] ?? 'Unknown'),
            if (isAssigned)
              _buildPatientInfoRow('Assigned Room', patientData['assignedRoom'] ?? 'Not assigned'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
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
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PatientList()),
              );
            },
            tooltip: 'View All Patients',
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadPatients, child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleNFCScan,
        icon: Icon(Icons.contactless),
        label: Text('Scan Patient Card'),
        tooltip: 'Scan patient NFC card to view their information',
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your patients...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPatients,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Doctor Profile Section
        if (_doctorInfo != null)
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.8),
                  Theme.of(context).primaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _doctorInfo!['name'] ?? 'Doctor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _doctorInfo!['specialization'] ?? 'General Medicine',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_patients.length} Patients',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Quick actions section
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: Icons.contactless,
                    label: 'Scan Patient Card',
                    onPressed: _handleNFCScan,
                    color: Colors.blue,
                  ),
                  _buildActionButton(
                    icon: Icons.people,
                    label: 'All My Patients',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PatientList()),
                      );
                    },
                    color: Colors.green,
                  ),
                  _buildActionButton(
                    icon: Icons.refresh,
                    label: 'Refresh List',
                    onPressed: _loadPatients,
                    color: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Patient count header
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assigned Patients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _patients.isEmpty 
                      ? Colors.grey.withOpacity(0.1)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_patients.length} patients',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _patients.isEmpty 
                        ? Colors.grey[600]
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Patient list
        Expanded(
          child: _patients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_ind,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No patients assigned yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'When a nurse assigns patients to you,\nthey will appear here automatically',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 24),
                            SizedBox(height: 8),
                            Text(
                              'You can still scan patient cards to view their information',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadPatients,
                        icon: Icon(Icons.refresh),
                        label: Text('Check for New Assignments'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _patients.length,
                  itemBuilder: (context, index) {
                    final patient = _patients[index];
                    return _buildPatientCard(patient);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: CircleBorder(),
            padding: EdgeInsets.all(16),
          ),
          child: Icon(
            icon,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient name and basic info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    patient['name'].substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
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
                        patient['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'IC: ${patient['patientId']}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Room ${patient['roomNumber'] ?? patient['assignedRoom'] ?? 'N/A'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24),

            // Patient details
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Date of Birth',
              value: patient['dateOfBirth'] ?? 'Not recorded',
            ),
            _buildInfoRow(
              icon: Icons.wc,
              label: 'Gender',
              value: patient['gender'] ?? 'Not recorded',
            ),
            if (patient['bloodType'] != null)
              _buildInfoRow(
                icon: Icons.bloodtype,
                label: 'Blood Type',
                value: patient['bloodType'],
              ),

            // Show if patient was recently assigned
            if (patient['lastUpdated'] != null)
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment_ind, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Recently assigned to you by nurse',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // View patient history (to be implemented)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Patient history feature coming soon'),
                      ),
                    );
                  },
                  icon: Icon(Icons.history),
                  label: Text('History'),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => PrescriptionForm(
                              patientId: patient['patientId'],
                              patientName: patient['name'],
                            ),
                      ),
                    );
                  },
                  icon: Icon(Icons.medication),
                  label: Text('Prescribe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}