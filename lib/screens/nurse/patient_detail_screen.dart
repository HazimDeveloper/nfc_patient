import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';

class PatientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDetailsScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  _PatientDetailsScreenState createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  Map<String, dynamic>? _appointmentDetails;
  Map<String, dynamic>? _doctorDetails;
  bool _isLoadingAppointment = false;

  @override
  void initState() {
    super.initState();
    _loadAppointmentDetails();
  }

  Future<void> _loadAppointmentDetails() async {
    if (widget.patient['currentAppointment'] != null) {
      setState(() {
        _isLoadingAppointment = true;
      });

      try {
        final appointmentData = await _databaseService.getAppointmentById(
          widget.patient['currentAppointment']
        );
        
        if (appointmentData != null) {
          final doctorData = await _databaseService.getDoctorById(
            appointmentData['doctorId']
          );
          
          setState(() {
            _appointmentDetails = appointmentData;
            _doctorDetails = doctorData;
          });
        }
      } catch (e) {
        print('Error loading appointment details: $e');
      } finally {
        setState(() {
          _isLoadingAppointment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final registrationDate = patient['registrationDate']?.toDate();
    final formattedRegDate = registrationDate != null
        ? '${registrationDate.day}/${registrationDate.month}/${registrationDate.year} at ${registrationDate.hour.toString().padLeft(2, '0')}:${registrationDate.minute.toString().padLeft(2, '0')}'
        : 'Unknown';

    final isAssigned = patient['currentAppointment'] != null;
    final hasCardSerial = patient['cardSerialNumber'] != null && 
                         patient['cardSerialNumber'].toString().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Details', style: TextStyle(color: Colors.white)),
        actions: [
          if (!isAssigned)
            IconButton(
              icon: Icon(Icons.assignment_ind),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssignDoctorScreen(
                      patientId: patient['patientId'],
                      patientName: patient['name'],
                    ),
                  ),
                ).then((_) => Navigator.pop(context));
              },
              tooltip: 'Assign Doctor',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Profile Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            patient['name']?.substring(0, 1).toUpperCase() ?? 'P',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isAssigned 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isAssigned ? 'Assigned to Doctor' : 'Awaiting Assignment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isAssigned ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    _buildProfileStat(
      icon: Icons.credit_card, // CHANGED: Use credit card icon for IC
      label: 'IC Number',
      value: patient['icNumber']?.substring(0, 8) ?? patient['patientId']?.substring(0, 8) ?? 'Unknown',
    ),
    _buildProfileStat(
      icon: Icons.calendar_today,
      label: 'Age',
      value: _calculateAge(patient['dateOfBirth']) ?? 'Unknown',
    ),
    _buildProfileStat(
      icon: Icons.wc,
      label: 'Gender',
      value: patient['gender'] ?? 'Unknown',
    ),
  ],
),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),

            // Basic Information
           _buildSection(
  title: 'Basic Information',
  icon: Icons.person,
  child: Column(
    children: [
      _buildDetailRow('Full Name', patient['name'] ?? 'Not recorded'),
      // ADDED: IC Number display
      _buildDetailRow(
        'IC Number', 
        patient['icNumber'] ?? patient['patientId'] ?? 'Not recorded',
        valueColor: Colors.blue[700],
      ),
      _buildDetailRow('Email', patient['email'] ?? 'Not recorded'),
      _buildDetailRow('Phone', patient['phone'] ?? 'Not recorded'),
      _buildDetailRow('Date of Birth', patient['dateOfBirth'] ?? 'Not recorded'),
      _buildDetailRow('Gender', patient['gender'] ?? 'Not recorded'),
      _buildDetailRow('Address', patient['address'] ?? 'Not recorded'),
      _buildDetailRow('Registration Date', formattedRegDate),
    ],
  ),
),

            SizedBox(height: 20),

            // Medical Information
            _buildSection(
              title: 'Medical Information',
              icon: Icons.medical_information,
              child: Column(
                children: [
                  _buildDetailRow(
                    'Blood Type', 
                    patient['bloodType'] ?? 'Not recorded',
                    valueColor: patient['bloodType'] != null ? Colors.red[700] : null,
                  ),
                  _buildDetailRow(
                    'Emergency Contact', 
                    patient['emergencyContact'] ?? 'Not recorded'
                  ),
                  SizedBox(height: 16),
                  _buildMedicalList(
                    'Allergies',
                    Icons.dangerous,
                    patient['allergies'] ?? [],
                    Colors.red,
                  ),
                  SizedBox(height: 12),
                  _buildMedicalList(
                    'Current Medications',
                    Icons.medication,
                    patient['medications'] ?? [],
                    Colors.blue,
                  ),
                  SizedBox(height: 12),
                  _buildMedicalList(
                    'Medical Conditions',
                    Icons.healing,
                    patient['conditions'] ?? [],
                    Colors.orange,
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // NFC Card Information
            if (hasCardSerial)
              _buildSection(
                title: 'NFC Card Information',
                icon: Icons.contactless,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.contactless,
                            color: Colors.blue,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Card Serial Number',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                SelectableText(
                                  patient['cardSerialNumber'].toString(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 20),

            // Current Assignment Information
            if (isAssigned)
              _buildSection(
                title: 'Current Assignment',
                icon: Icons.assignment_ind,
                child: _isLoadingAppointment
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _appointmentDetails != null
                        ? Column(
                            children: [
                              _buildDetailRow(
                                'Doctor', 
                                _doctorDetails != null 
                                    ? 'Dr. ${_doctorDetails!['name']}'
                                    : 'Loading...'
                              ),
                              if (_doctorDetails?['specialization'] != null)
                                _buildDetailRow(
                                  'Specialization', 
                                  _doctorDetails!['specialization']
                                ),
                              if (_doctorDetails?['department'] != null)
                                _buildDetailRow(
                                  'Department', 
                                  _doctorDetails!['department']
                                ),
                              _buildDetailRow(
                                'Room Number', 
                                _appointmentDetails!['roomNumber'] ?? 'Not assigned'
                              ),
                              if (_appointmentDetails?['notes'] != null && 
                                  _appointmentDetails!['notes'].toString().isNotEmpty)
                                _buildDetailRow(
                                  'Notes', 
                                  _appointmentDetails!['notes']
                                ),
                            ],
                          )
                        : Text(
                            'Unable to load assignment details',
                            style: TextStyle(
                              color: Colors.red,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
              ),

            SizedBox(height: 20),

            // Action Button
            if (!isAssigned)
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
                    ).then((_) => Navigator.pop(context));
                  },
                  icon: Icon(Icons.assignment_ind),
                  label: Text('Assign Doctor & Room'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 24,
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
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
                Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label, 
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
                color: valueColor ?? Colors.black87,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalList(
    String title,
    IconData icon,
    List<dynamic> items,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: color,
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'No $title recorded',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map<Widget>((item) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String? _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return null;
    
    try {
      // Parse date in format "dd/mm/yyyy"
      final parts = dateOfBirth.split('/');
      if (parts.length != 3) return null;
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      
      final birthDate = DateTime(year, month, day);
      final now = DateTime.now();
      
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month || 
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      
      return age.toString();
    } catch (e) {
      return null;
    }
  }
}