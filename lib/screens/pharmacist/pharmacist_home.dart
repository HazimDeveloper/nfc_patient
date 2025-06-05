import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/screens/common/enhance_nfc_patient_scanner.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/models/prescription.dart';
import 'package:nfc_patient_registration/screens/pharmacist/prescription_view.dart';

class PharmacistHome extends StatefulWidget {
  @override
  _PharmacistHomeState createState() => _PharmacistHomeState();
}

class _PharmacistHomeState extends State<PharmacistHome> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _pendingPrescriptions = [];
  List<Map<String, dynamic>> _completedPrescriptions = [];
  Map<String, int> _statistics = {};
  bool _isLoading = true;
  String? _error;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load all prescription data
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load prescriptions and statistics in parallel
      final results = await Future.wait([
        _databaseService.getPrescriptionsByStatus('pending'),
        _databaseService.getCompletedPrescriptions(limit: 50), // Recent 50
        _databaseService.getPrescriptionStatistics(),
      ]);
      
      setState(() {
        _pendingPrescriptions = results[0] as List<Map<String, dynamic>>;
        _completedPrescriptions = results[1] as List<Map<String, dynamic>>;
        _statistics = results[2] as Map<String, int>;
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
        title: Text('Pharmacist Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
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
              icon: Icon(Icons.pending_actions),
              text: 'Pending (${_statistics['pending'] ?? 0})',
            ),
            // FIXED: Show total completed instead of just today
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'Completed (${_completedPrescriptions.length})',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          // FIXED: Updated statistics bar
          _buildStatisticsBar(),
          
          // Tab content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingTab(),
                  _buildCompletedTab(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanPatientCard,
        icon: Icon(Icons.contactless,color: Colors.white,),
        // FIXED: Updated label for clarity
        label: Text('Scan Patient Card',style: TextStyle(color:Colors.white),),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
  
  // FIXED: Updated statistics bar with clearer labels
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
            icon: Icons.pending_actions,
            value: (_statistics['pending'] ?? 0).toString(),
            label: 'Pending',
            color: Colors.orange,
          ),
          _buildStatCard(
            icon: Icons.local_pharmacy,
            value: (_statistics['dispensed'] ?? 0).toString(),
            label: 'Dispensed',
            color: Colors.blue,
          ),
          // FIXED: Show today's completed separately from total
          _buildStatCard(
            icon: Icons.today,
            value: (_statistics['completedToday'] ?? 0).toString(),
            label: 'Today',
            color: Colors.green,
          ),
          // FIXED: Show total completed
          _buildStatCard(
            icon: Icons.check_circle,
            value: _completedPrescriptions.length.toString(),
            label: 'Total Done',
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
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildPendingTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_pendingPrescriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No pending prescriptions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'All prescriptions have been processed!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pendingPrescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _pendingPrescriptions[index];
        return _buildPrescriptionCard(prescription, isPending: true);
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

    if (_completedPrescriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No completed prescriptions yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Completed prescriptions will appear here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // FIXED: Group prescriptions by date for better organization
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // FIXED: Add summary info at the top
        Container(
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.green),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completed Prescriptions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Total: ${_completedPrescriptions.length} | Today: ${_statistics['completedToday'] ?? 0}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // List of completed prescriptions
        ...List.generate(
          _completedPrescriptions.length,
          (index) {
            final prescription = _completedPrescriptions[index];
            return _buildPrescriptionCard(prescription, isPending: false);
          },
        ),
      ],
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
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescriptionData, {required bool isPending}) {
    final prescription = Prescription.fromFirestore(
      prescriptionData,
      prescriptionData['prescriptionId'],
    );
    
    // Extract medication names for preview
    final medicationPreview = prescription.medications.length > 2
        ? '${prescription.medications[0].name}, ${prescription.medications[1].name}, and ${prescription.medications.length - 2} more'
        : prescription.medications.map((med) => med.name).join(', ');
    
    // Format timestamp with better date display
    final timestamp = isPending ? prescription.createdAt : prescription.updatedAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final prescriptionDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    String formattedDate;
    String formattedTime = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    
    // FIXED: Better date formatting
    if (prescriptionDate == today) {
      formattedDate = 'Today';
    } else if (prescriptionDate == today.subtract(Duration(days: 1))) {
      formattedDate = 'Yesterday';
    } else {
      formattedDate = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
    
    // Status color
    Color statusColor;
    String statusText;
    switch (prescription.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'PENDING';
        break;
      case 'dispensed':
        statusColor = Colors.blue;
        statusText = 'DISPENSED';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'COMPLETED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = prescription.status.toUpperCase();
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: isPending ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPending ? BorderSide(color: statusColor.withOpacity(0.3), width: 1) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionView(prescription: prescription),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Text(
                      prescription.patientName?.substring(0, 1).toUpperCase() ?? 'P',
                      style: TextStyle(
                        color: statusColor,
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
                          prescription.patientName ?? 'Unknown Patient',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Dr. ${prescription.doctorName ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 2),
                        // FIXED: Better date/time display
                        Row(
                          children: [
                            Text(
                              '${isPending ? 'Prescribed' : 'Completed'}: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: formattedDate == 'Today' ? Colors.green[600] : 
                                       formattedDate == 'Yesterday' ? Colors.orange[600] : 
                                       Colors.grey[500],
                                fontWeight: formattedDate == 'Today' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            Text(
                              ' at $formattedTime',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Diagnosis and medications
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.medical_information, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diagnosis:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                prescription.diagnosis,
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.medication, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medications (${prescription.medications.length}):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                medicationPreview,
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action button for pending prescriptions
              if (isPending) ...[
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrescriptionView(prescription: prescription),
                          ),
                        ).then((_) => _loadData());
                      },
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('Process'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusColor,
                        side: BorderSide(color: statusColor),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Scan patient card for prescription lookup
  void _scanPatientCard() {
    // Navigate to the enhanced NFC scanner
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedNFCPatientScanner(
          userRole: 'pharmacist',
          userId: 'pharmacist1', // Get from auth service
          userName: 'Pharmacist', // Get from auth service
        ),
      ),
    ).then((_) => _loadData());
  }
}