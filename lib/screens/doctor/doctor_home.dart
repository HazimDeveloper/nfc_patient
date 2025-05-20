import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/screens/doctor/patient_list.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/doctor/prescription_form.dart';

class DoctorHome extends StatefulWidget {
  @override
  _DoctorHomeState createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  // Load assigned patients
  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final doctorId = authService.currentUser?.uid;

      if (doctorId != null) {
        final patients = await _databaseService.getPatientsByDoctor(doctorId);
        setState(() {
          _patients = patients;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Unable to identify doctor';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading patients: ${e.toString()}';
        _isLoading = false;
      });
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
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
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

    if (_patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No patients assigned to you yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPatients,
              icon: Icon(Icons.refresh),
              label: Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        return _buildPatientCard(patient);
      },
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
                        'ID: ${patient['patientId']}',
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
                    'Room ${patient['roomNumber'] ?? 'N/A'}',
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

            // Collapsible sections
            _buildExpandableSection(
              title: 'Allergies',
              icon: Icons.dangerous,
              items:
                  (patient['allergies'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
            ),
            _buildExpandableSection(
              title: 'Current Medications',
              icon: Icons.medication,
              items:
                  (patient['medications'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
            ),
            _buildExpandableSection(
              title: 'Medical Conditions',
              icon: Icons.healing,
              items:
                  (patient['conditions'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
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

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 8),
          Text(
            '(${items.length})',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
      children:
          items.isEmpty
              ? [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No $title recorded',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ]
              : items.map((item) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Expanded(child: Text(item)),
                    ],
                  ),
                );
              }).toList(),
    );
  }
}
