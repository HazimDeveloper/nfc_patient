import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart'; 

class PatientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDetailsScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  // Real-time streams
  late Stream<DocumentSnapshot> _patientStream;
  late Stream<QuerySnapshot> _prescriptionsStream;
  late Stream<QuerySnapshot> _medicalRecordsStream;
  
  Map<String, dynamic>? _currentPatientData;
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _medicalRecords = [];

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    // Get patient ID from either 'patientId' or 'documentId'
    String patientId = widget.patient['patientId'] ?? widget.patient['documentId'] ?? '';
    
    if (patientId.isEmpty) {
      print('ERROR: No patient ID found');
      return;
    }
    
    print('Setting up streams for patient: $patientId');
    
    // Stream for patient data updates
    _patientStream = FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .snapshots();
    
    // Stream for prescriptions
    _prescriptionsStream = FirebaseFirestore.instance
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('prescriptionDate', descending: true)
        .snapshots();
    
    // Stream for medical records
    _medicalRecordsStream = FirebaseFirestore.instance
        .collection('medicalRecords')
        .where('patientId', isEqualTo: patientId)
        .orderBy('recordDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Details'),
        backgroundColor: const Color(0xFF2E8B8B),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _patientStream,
        builder: (context, patientSnapshot) {
          // Use real-time data if available, otherwise use initial data
          Map<String, dynamic> patientData = widget.patient;
          
          if (patientSnapshot.hasData && patientSnapshot.data!.exists) {
            patientData = patientSnapshot.data!.data() as Map<String, dynamic>;
            patientData['documentId'] = patientSnapshot.data!.id;
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Basic Info
                _buildPatientBasicInfo(patientData),
                const SizedBox(height: 20),
                
                // Medical Information with real-time updates
                _buildMedicalInformation(patientData),
                const SizedBox(height: 20),
                
                // Real-time Prescriptions
                _buildPrescriptionsSection(),
                const SizedBox(height: 20),
                
                // Real-time Medical Records
                _buildMedicalRecordsSection(),
                const SizedBox(height: 20),
                
                // NFC Card Information
                _buildNFCCardInfo(patientData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientBasicInfo(Map<String, dynamic> patient) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient['name'] ?? 'Unknown',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('IC: ${patient['icNumber'] ?? 'Not available'}'),
            Text('Email: ${patient['email'] ?? 'Not available'}'),
            Text('Phone: ${patient['phone'] ?? 'Not available'}'),
            Text('DOB: ${patient['dateOfBirth'] ?? 'Not available'}'),
            Text('Gender: ${patient['gender'] ?? 'Not available'}'),
            Text('Address: ${patient['address'] ?? 'Not available'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInformation(Map<String, dynamic> patient) {
    return Column(
      children: [
        // Blood Type & Emergency Contact
        Row(
          children: [
            Expanded(
              child: Text(
                'Blood Type: ${patient['bloodType'] ?? 'Not recorded'}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Emergency Contact: ${patient['emergencyContact'] ?? 'Not recorded'}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Allergies
        _buildMedicalSection(
          'Allergies',
          patient['allergies'] ?? [],
          'No Allergies recorded',
          Colors.red.shade100,
          Icons.cancel,
          Colors.red,
        ),
        const SizedBox(height: 12),
        
        // Current Medications
        _buildMedicalSection(
          'Current Medications',
          patient['medications'] ?? [],
          'No Current Medications recorded',
          Colors.blue.shade100,
          Icons.medication,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        
        // Medical Conditions
        _buildMedicalSection(
          'Medical Conditions',
          patient['conditions'] ?? [],
          'No Medical Conditions recorded',
          Colors.orange.shade100,
          Icons.medical_services,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMedicalSection(
    String title,
    List<dynamic> items,
    String emptyMessage,
    Color backgroundColor,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title ${items.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            )
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${item.toString()}'),
                )),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _prescriptionsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading prescriptions: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final prescriptions = snapshot.data?.docs ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medication, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Prescriptions (${prescriptions.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (prescriptions.isEmpty)
                  const Text(
                    'No prescriptions found',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  )
                else
                  ...prescriptions.take(5).map((doc) {
                    final prescription = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${prescription['doctorName'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Medicine: ${prescription['medicineName'] ?? 'N/A'}'),
                          Text('Dosage: ${prescription['dosage'] ?? 'N/A'}'),
                          Text('Instructions: ${prescription['instructions'] ?? 'N/A'}'),
                          if (prescription['prescriptionDate'] != null)
                            Text(
                              'Date: ${_formatTimestamp(prescription['prescriptionDate'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicalRecordsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _medicalRecordsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading medical records: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final records = snapshot.data?.docs ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_information, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Medical Records (${records.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const Text(
                    'No medical records found',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  )
                else
                  ...records.take(3).map((doc) {
                    final record = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${record['doctorName'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Diagnosis: ${record['diagnosis'] ?? 'N/A'}'),
                          Text('Treatment: ${record['treatment'] ?? 'N/A'}'),
                          if (record['recordDate'] != null)
                            Text(
                              'Date: ${_formatTimestamp(record['recordDate'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNFCCardInfo(Map<String, dynamic> patient) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.nfc, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'NFC Card Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.nfc, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Card Serial Number',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patient['cardSerialNumber'] ?? 'Not available',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Invalid date';
      }
      
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}