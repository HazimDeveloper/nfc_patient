import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/screens/common/enhance_nfc_patient_scanner.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';

class DoctorHome extends StatefulWidget {
  @override
  _DoctorHomeState createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _notAssignedPatients = [];
  List<Map<String, dynamic>> _assignedPatients = [];
  List<Map<String, dynamic>> _completedPatients = [];
  bool _isLoading = true;
  String? _error;
  String? _currentDoctorId;
  Map<String, dynamic>? _doctorInfo;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDoctor();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeDoctor() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.uid;
      
      if (currentUserId != null) {
        _currentDoctorId = currentUserId;
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

  Future<void> _loadPatients() async {
    if (_currentDoctorId == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get patients assigned to this doctor
      final assignedPatients = await _databaseService.getPatientsByDoctor(_currentDoctorId!);
      
      // Get all patients to find not assigned ones
      final allActivePatients = await _databaseService.getPatientsByStatus('active');
      final allRegisteredPatients = await _databaseService.getPatientsByStatus('registered');
      
      // Get completed patients assigned to this doctor
      final completedPatients = await _databaseService.getPatientsByStatus('completed');
      final doctorCompletedPatients = completedPatients.where(
        (patient) => patient['assignedDoctor'] == _currentDoctorId
      ).toList();
      
      // Find not assigned patients (registered but no doctor assigned)
      final notAssignedPatients = allRegisteredPatients.where(
        (patient) => patient['assignedDoctor'] == null
      ).toList();
      
      setState(() {
        _assignedPatients = assignedPatients;
        _notAssignedPatients = notAssignedPatients;
        _completedPatients = doctorCompletedPatients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading patients: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

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
    ).then((_) => _loadPatients());
  }

  Future<void> _completePatient(String patientId) async {
    try {
      await _databaseService.markPatientAsCompleted(patientId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient marked as completed'),
          backgroundColor: Colors.green,
        ),
      );
      _loadPatients();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.person_search),
              text: 'Not Assigned (${_notAssignedPatients.length})',
            ),
            Tab(
              icon: Icon(Icons.assignment_ind),
              text: 'My Patients (${_assignedPatients.length})',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'Completed (${_completedPatients.length})',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatients, 
        child: Column(
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
                  ],
                ),
              ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNotAssignedTab(),
                  _buildAssignedTab(),
                  _buildCompletedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleNFCScan,
        icon: Icon(Icons.contactless),
        label: Text('Scan Patient Card'),
        tooltip: 'Scan patient NFC card to view their information',
      ),
    );
  }

  Widget _buildNotAssignedTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading patients...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_notAssignedPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All patients have been assigned',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'No unassigned patients at the moment',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _notAssignedPatients.length,
      itemBuilder: (context, index) {
        final patient = _notAssignedPatients[index];
        return _buildPatientCard(patient, isAssigned: false);
      },
    );
  }

  Widget _buildAssignedTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_assignedPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_ind, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No patients assigned yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Patients assigned to you will appear here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _assignedPatients.length,
      itemBuilder: (context, index) {
        final patient = _assignedPatients[index];
        return _buildPatientCard(patient, isAssigned: true);
      },
    );
  }

  Widget _buildCompletedTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_completedPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No completed patients yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Completed patients will appear here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _completedPatients.length,
      itemBuilder: (context, index) {
        final patient = _completedPatients[index];
        return _buildPatientCard(patient, isCompleted: true);
      },
    );
  }

  Widget _buildErrorWidget() {
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

  Widget _buildPatientCard(Map<String, dynamic> patient, {bool isAssigned = false, bool isCompleted = false}) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isCompleted ? Colors.green : Theme.of(context).primaryColor,
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
                    color: (isCompleted ? Colors.green : isAssigned ? Colors.teal : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted ? 'COMPLETED' : isAssigned ? 'Room ${patient['roomNumber'] ?? 'N/A'}' : 'NOT ASSIGNED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green : isAssigned ? Colors.teal : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24),

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

            SizedBox(height: 16),

            if (!isCompleted) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _handleNFCScan();
                    },
                    icon: Icon(Icons.contactless),
                    label: Text('Scan Card'),
                  ),

                  if (isAssigned) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrescriptionForm(
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
                ],
              ),
              
              if (isAssigned) ...[
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _completePatient(patient['patientId']),
                    icon: Icon(Icons.check_circle),
                    label: Text('Complete Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ] else ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Treatment completed',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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