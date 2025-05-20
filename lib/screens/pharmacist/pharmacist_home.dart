import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/models/prescription.dart';
import 'package:nfc_patient_registration/screens/pharmacist/prescription_view.dart';
import 'package:nfc_patient_registration/screens/patient/nfc_scan_screen.dart';

class PharmacistHome extends StatefulWidget {
  @override
  _PharmacistHomeState createState() => _PharmacistHomeState();
}

class _PharmacistHomeState extends State<PharmacistHome> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _pendingPrescriptions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingPrescriptions();
  }

  // Load pending prescriptions
  Future<void> _loadPendingPrescriptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prescriptions = await _databaseService.getPendingPrescriptions();
      setState(() {
        _pendingPrescriptions = prescriptions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading prescriptions: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Pharmacist Dashboard',style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingPrescriptions,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NFCScanScreen(
                action: NFCAction.read,
                onDataRead: (data) {
                  // When a patient card is scanned, look up their pending prescriptions
                  if (data.containsKey('patientId')) {
                    final patientId = data['patientId'];
                    _loadPatientPrescriptions(patientId);
                  }
                },
              ),
            ),
          );
        },
        icon: Icon(Icons.contactless),
        label: Text('Scan Patient Card'),
      ),
    );
  }

  // Load prescriptions for a specific patient
  Future<void> _loadPatientPrescriptions(String patientId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prescriptions = await _databaseService.getPrescriptionsByPatient(patientId);
      
      if (prescriptions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No prescriptions found for this patient'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Navigate to the first pending prescription or show a message
      final pendingPrescriptions = prescriptions.where(
        (prescription) => prescription['status'] == 'pending',
      ).toList();
      
      if (pendingPrescriptions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No pending prescriptions for this patient'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Navigate to the first pending prescription
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionView(
            prescription: Prescription.fromFirestore(
              pendingPrescriptions.first,
              pendingPrescriptions.first['prescriptionId'],
            ),
          ),
        ),
      ).then((_) => _loadPendingPrescriptions());
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading patient prescriptions: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPendingPrescriptions,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Statistics bar
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                icon: Icons.receipt,
                value: _pendingPrescriptions.length.toString(),
                label: 'Pending',
                color: Colors.orange,
              ),
              _buildStatCard(
                icon: Icons.check_circle,
                value: '0', // Placeholder, would need to fetch this data
                label: 'Completed Today',
                color: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.people,
                value: '0', // Placeholder, would need to fetch this data
                label: 'Patients Served',
                color: Colors.blue,
              ),
            ],
          ),
        ),
        
        // Pending prescriptions header
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending Prescriptions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_pendingPrescriptions.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_pendingPrescriptions.length} pending',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Prescription list
        Expanded(
          child: _pendingPrescriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 60,
                        color: Colors.green,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No pending prescriptions',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pendingPrescriptions.length,
                  itemBuilder: (context, index) {
                    final prescription = _pendingPrescriptions[index];
                    return _buildPrescriptionCard(prescription);
                  },
                ),
        ),
      ],
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
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
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
        ),
      ],
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescriptionData) {
    final prescription = Prescription.fromFirestore(
      prescriptionData,
      prescriptionData['prescriptionId'],
    );
    
    // Extract medication names for preview
    final medicationPreview = prescription.medications.length > 2
        ? '${prescription.medications[0].name}, ${prescription.medications[1].name}, and ${prescription.medications.length - 2} more'
        : prescription.medications.map((med) => med.name).join(', ');
    
    // Format timestamp
    final createdAt = prescription.createdAt;
    final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final formattedTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionView(
                prescription: prescription,
              ),
            ),
          ).then((_) => _loadPendingPrescriptions());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient and doctor info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      prescription.patientName?.substring(0, 1).toUpperCase() ?? 'P',
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
                          prescription.patientName ?? 'Unknown Patient',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Dr. ${prescription.doctorName ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$formattedDate at $formattedTime',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 24),
              
              // Diagnosis and medications
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.medical_information,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnosis:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          prescription.diagnosis,
                          style: TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.medication,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medications:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          medicationPreview,
                          style: TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrescriptionView(
                            prescription: prescription,
                          ),
                        ),
                      ).then((_) => _loadPendingPrescriptions());
                    },
                    icon: Icon(Icons.remove_red_eye),
                    label: Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}