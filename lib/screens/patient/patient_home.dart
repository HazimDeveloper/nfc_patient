import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/models/prescription.dart';
import 'package:nfc_patient_registration/models/patient.dart';

class PatientHome extends StatefulWidget {
  @override
  _PatientHomeState createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  final DatabaseService _databaseService = DatabaseService();
  Patient? _patient;
  List<Prescription> _prescriptions = [];
  Map<String, dynamic>? _appointment;
  Map<String, dynamic>? _doctorInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final patientId = await authService.getCurrentUserId();

      if (patientId == null) {
        throw Exception('Unable to identify patient');
      }

      print('Loading data for patient ID: $patientId');

      final patientData = await _databaseService.getPatientById(patientId);
      
      if (patientData != null) {
        _patient = Patient.fromFirestore(patientData);
        
        final prescriptionsData = await _databaseService.getPrescriptionsByPatient(patientId);
        
        _prescriptions = prescriptionsData
            .map((data) => Prescription.fromFirestore(
                  data,
                  data['prescriptionId'],
                ))
            .toList();
        
        _prescriptions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        if (_patient!.currentAppointment != null) {
          final appointmentData = await _databaseService.getAppointmentById(_patient!.currentAppointment!);
          if (appointmentData != null) {
            _appointment = appointmentData;
            
            final doctorData = await _databaseService.getDoctorById(appointmentData['doctorId']);
            if (doctorData != null) {
              _doctorInfo = doctorData;
            }
          }
        }
      } else {
        throw Exception('Patient data not found. Please contact the hospital.');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatientData,
        child: _buildBody(),
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
            Text('Loading your information...'),
          ],
        ),
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
              onPressed: _loadPatientData,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_patient == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No patient data found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Please contact the hospital registration desk',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Patient profile card
        _buildProfileCard(),
        SizedBox(height: 24),
        
        // Assignment status card
        _buildAssignmentStatusCard(),
        
        SizedBox(height: 24),
        
        // Prescriptions section
        Text(
          'Recent Prescriptions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Divider(),
        SizedBox(height: 8),
        
        // Prescription cards
        if (_prescriptions.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No prescriptions yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(
            _prescriptions.length > 5 ? 5 : _prescriptions.length,
            (index) => _buildPrescriptionCard(_prescriptions[index]),
          ),
        
        if (_prescriptions.length > 5)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Full prescription history coming soon'),
                  ),
                );
              },
              child: Text('View All Prescriptions'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        
        SizedBox(height: 24),
        
        // Medical info section
        Text(
          'Medical Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Divider(),
        SizedBox(height: 8),
        
        _buildMedicalInfoCard(
          title: 'Allergies',
          icon: Icons.dangerous,
          items: _patient!.allergies,
        ),
        SizedBox(height: 16),
        
        _buildMedicalInfoCard(
          title: 'Current Medications',
          icon: Icons.medication,
          items: _patient!.medications,
        ),
        SizedBox(height: 16),
        
        _buildMedicalInfoCard(
          title: 'Medical Conditions',
          icon: Icons.healing,
          items: _patient!.conditions,
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Card(
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
                  radius: 32,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    _patient!.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _patient!.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'IC Number: ${_patient!.patientId}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            'DOB: ${_patient!.dateOfBirth}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProfileInfoItem(
                  icon: Icons.wc,
                  label: 'Gender',
                  value: _patient!.gender,
                ),
                if (_patient!.bloodType != null)
                  _buildProfileInfoItem(
                    icon: Icons.bloodtype,
                    label: 'Blood Type',
                    value: _patient!.bloodType!,
                  ),
                _buildProfileInfoItem(
                  icon: Icons.phone,
                  label: 'Contact',
                  value: _patient!.phone,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentStatusCard() {
    // Check patient status
    String status = _patient?.currentAppointment != null ? 'assigned' : 'waiting';
    
    if (_appointment != null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_ind,
                      color: Colors.green,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'You are assigned!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 8),
                
                if (_doctorInfo != null) ...[
                  _buildAssignmentInfoRow(
                    icon: Icons.medical_services,
                    label: 'Doctor',
                    value: 'Dr. ${_doctorInfo!['name']}',
                  ),
                  SizedBox(height: 8),
                  _buildAssignmentInfoRow(
                    icon: Icons.local_hospital,
                    label: 'Specialty',
                    value: _doctorInfo!['specialization'] ?? 'General',
                  ),
                  SizedBox(height: 8),
                ],
                
                _buildAssignmentInfoRow(
                  icon: Icons.meeting_room,
                  label: 'Room',
                  value: _appointment!['roomNumber'] ?? 'Not assigned',
                  isHighlighted: true,
                ),
                
                if (_appointment?['notes'] != null && _appointment!['notes'].toString().isNotEmpty) ...[
                  SizedBox(height: 8),
                  _buildAssignmentInfoRow(
                    icon: Icons.note,
                    label: 'Notes',
                    value: _appointment!['notes'],
                  ),
                ],
                
                SizedBox(height: 12),
                
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please proceed to your assigned room for consultation.',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.orange.withOpacity(0.1),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.schedule,
                  size: 48,
                  color: Colors.orange,
                ),
                SizedBox(height: 12),
                Text(
                  'Waiting for Assignment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You are currently in the queue. A nurse will assign you to a doctor and room shortly.',
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please wait in the waiting area. You will be notified when ready.',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildAssignmentInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
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
        Expanded(
          child: isHighlighted
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionCard(Prescription prescription) {
    final createdAt = prescription.createdAt;
    final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    
    Color statusColor;
    switch (prescription.status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'dispensed':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }
    
    final medicationsText = prescription.medications.length > 1
        ? '${prescription.medications[0].name} and ${prescription.medications.length - 1} more'
        : prescription.medications[0].name;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    prescription.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Diagnosis: ${prescription.diagnosis}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Medications: $medicationsText',
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
            if (prescription.doctorName != null) ...[
              SizedBox(height: 4),
              Text(
                'Doctor: Dr. ${prescription.doctorName}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfoCard({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Card(
      elevation: 1,
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
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No $title recorded',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(item),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}