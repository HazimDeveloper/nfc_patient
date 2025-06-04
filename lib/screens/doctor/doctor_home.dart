import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/screens/common/enhance_nfc_patient_scanner.dart';
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
    final currentUserId = authService.currentUser?.uid;
    
    if (currentUserId != null) {
      _currentDoctorId = currentUserId; // Use Firebase UID as doctor ID
      _doctorInfo = await _databaseService.getDoctorById(_currentDoctorId!);
      
      if (_doctorInfo != null) {
        await _loadPatients();
      } else {
        setState(() {
          _error = 'Doctor profile not found';
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
   
        return null;
    
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

  // Handle NFC card scan - Connect to new scanner
  void _handleNFCScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedNFCPatientScanner(
          userRole: 'doctor',
          userId: _currentDoctorId,
          userName: _doctorInfo?['name'] ?? 'Doctor',
        ),
      ),
    ).then((_) => _loadPatients()); // Refresh patient list when returning
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
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
        
        // Quick actions section - Removed "All My Patients" button
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
                    icon: Icons.refresh,
                    label: 'Refresh Patient List',
                    onPressed: _loadPatients,
                    color: Colors.green,
                  ),
                  _buildActionButton(
                    icon: Icons.medication,
                    label: 'Quick Prescription',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Scan a patient card first to create prescription'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
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
                            Icon(Icons.contactless, color: Colors.blue, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Use NFC Scanner',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Scan any patient card to view their information and create prescriptions',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _handleNFCScan,
                        icon: Icon(Icons.contactless),
                        label: Text('Scan Patient Card'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadPatients,
                        icon: Icon(Icons.refresh),
                        label: Text('Check for New Assignments'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
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
                    // Use NFC scanner to view full patient details
                    _handleNFCScan();
                  },
                  icon: Icon(Icons.contactless),
                  label: Text('Scan Card'),
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