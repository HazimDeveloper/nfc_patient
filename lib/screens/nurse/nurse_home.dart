import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/nfc_card_registration.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';
import 'package:nfc_patient_registration/screens/nurse/nurse_patient_list_screen.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart';

class NurseHome extends StatefulWidget {
  @override
  _NurseHomeState createState() => _NurseHomeState();
}

class _NurseHomeState extends State<NurseHome> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  
  // Data for different patient categories
  List<Map<String, dynamic>> _newPatients = [];
  List<Map<String, dynamic>> _activePatients = [];
  List<Map<String, dynamic>> _completedPatients = [];
  Map<String, int> _statistics = {};
  
  bool _isLoading = true;
  String? _error;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load all patient data
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all data in parallel
      final results = await Future.wait([
        _databaseService.getNewPatients(), // registered but not assigned
        _databaseService.getPatientsByStatus('active'), // assigned but not completed
        _databaseService.getPatientsByStatus('completed'), // completed patients
        _databaseService.getPatientStatistics(), // statistics
      ]);
      
      setState(() {
        _newPatients = results[0] as List<Map<String, dynamic>>;
        _activePatients = results[1] as List<Map<String, dynamic>>;
        _completedPatients = results[2] as List<Map<String, dynamic>>;
        _statistics = results[3] as Map<String, int>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Nurse Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
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
              icon: Icon(Icons.person_add),
              text: 'New (${_statistics['unassigned'] ?? 0})',
            ),
            Tab(
              icon: Icon(Icons.assignment_ind),
              text: 'Active (${_statistics['active'] ?? 0})',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'Completed (${_statistics['completed'] ?? 0})',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          // Statistics bar
          _buildStatisticsBar(),
          
          // Tab content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNewPatientsTab(),
                  _buildActivePatientsTab(),
                  _buildCompletedPatientsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NFCCardRegistration(),
            ),
          ).then((_) => _loadAllData());
        },
        icon: Icon(Icons.person_add,color: Colors.white,),
        label: Text('Register Patient',style: TextStyle(color: Colors.white),),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Widget _buildStatisticsBar() {
    if (_isLoading) {
      return Container(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            icon: Icons.people,
            value: (_statistics['total'] ?? 0).toString(),
            label: 'Total Patients',
            color: Colors.blue,
          ),
          _buildStatCard(
            icon: Icons.person_add,
            value: (_statistics['unassigned'] ?? 0).toString(),
            label: 'Need Assignment',
            color: Colors.orange,
          ),
          _buildStatCard(
            icon: Icons.assignment_ind,
            value: (_statistics['active'] ?? 0).toString(),
            label: 'Active',
            color: Colors.green,
          ),
          _buildStatCard(
            icon: Icons.check_circle,
            value: (_statistics['completed'] ?? 0).toString(),
            label: 'Completed',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  // New Patients Tab (Need Assignment)
  Widget _buildNewPatientsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_newPatients.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'All Caught Up!',
        subtitle: 'All patients have been assigned to doctors',
        color: Colors.green,
        actionButton: _buildQuickActionButtons(),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _newPatients.length,
      itemBuilder: (context, index) {
        final patient = _newPatients[index];
        return _buildNewPatientCard(patient, index);
      },
    );
  }
  
  // Active Patients Tab
  Widget _buildActivePatientsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_activePatients.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_ind,
        title: 'No Active Patients',
        subtitle: 'Patients currently being treated will appear here',
        color: Colors.blue,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _activePatients.length,
      itemBuilder: (context, index) {
        final patient = _activePatients[index];
        return _buildActivePatientCard(patient);
      },
    );
  }
  
  // Completed Patients Tab
  Widget _buildCompletedPatientsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_completedPatients.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Completed Patients Yet',
        subtitle: 'Completed patient treatments will appear here',
        color: Colors.grey,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _completedPatients.length,
      itemBuilder: (context, index) {
        final patient = _completedPatients[index];
        return _buildCompletedPatientCard(patient);
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
            onPressed: _loadAllData,
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    Widget? actionButton,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: color),
          ),
          SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (actionButton != null) ...[
            SizedBox(height: 24),
            actionButton,
          ],
        ],
      ),
    );
  }
  
  Widget _buildQuickActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NursePatientListScreen(),
              ),
            ).then((_) => _loadAllData());
          },
          icon: Icon(Icons.people),
          label: Text('View All Patients'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _handleNFCScan,
          icon: Icon(Icons.contactless),
          label: Text('Scan Patient Card'),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPatientCard(Map<String, dynamic> patient, int index) {
    final registrationDate = patient['registrationDate']?.toDate();
    final formattedDate = registrationDate != null
        ? '${registrationDate.day}/${registrationDate.month}/${registrationDate.year}'
        : 'Unknown';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.orange.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient header
                Row(
                  children: [
                    Hero(
                      tag: 'patient_avatar_${patient['patientId']}',
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange,
                              Colors.orange.withOpacity(0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            patient['name'].substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Registered: $formattedDate',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                          SizedBox(width: 4),
                          Text(
                            'NEW',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Patient details
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
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
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: patient['phone'] ?? 'Not recorded',
                      ),
                      if (patient['cardSerialNumber'] != null)
                        _buildInfoRow(
                          icon: Icons.contactless,
                          label: 'Card ID',
                          value: patient['cardSerialNumber'],
                          valueStyle: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AssignDoctorScreen(
                            patientId: patient['patientId'],
                            patientName: patient['name'],
                          ),
                        ),
                      ).then((_) => _loadAllData());
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
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivePatientCard(Map<String, dynamic> patient) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'IC: ${patient['patientId']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    // FIXED: Remove duplicate "Room" text
                    patient['roomNumber'] ?? 'No Room',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            // FIXED: Show doctor name instead of ID
            if (patient['assignedDoctor'] != null)
              FutureBuilder<Map<String, dynamic>?>(
                future: _databaseService.getDoctorById(patient['assignedDoctor']),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final doctorData = snapshot.data!;
                    return Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.medical_services, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Assigned to: Dr. ${doctorData['name'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Loading doctor info...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Doctor info not available',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientDetailsScreen(
                          patient: patient,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedPatientCard(Map<String, dynamic> patient) {
    final completedDate = patient['completedAt']?.toDate();
    final formattedDate = completedDate != null
        ? '${completedDate.day}/${completedDate.month}/${completedDate.year}'
        : 'Unknown';
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.check, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'IC: ${patient['patientId']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'COMPLETED',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Completed on: $formattedDate',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            
            // FIXED: Show doctor name for completed patients too
            if (patient['assignedDoctor'] != null) ...[
              SizedBox(height: 4),
              FutureBuilder<Map<String, dynamic>?>(
                future: _databaseService.getDoctorById(patient['assignedDoctor']),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Text(
                      'Treated by: Dr. ${snapshot.data!['name'] ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    );
                  }
                  return Text(
                    'Treated by: Loading...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
            
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientDetailsScreen(
                          patient: patient,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.history, size: 16),
                  label: Text('View History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced NFC scanning method
  void _handleNFCScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NFCCardRegistration(),
      ),
    ).then((_) => _loadAllData());
  }
}