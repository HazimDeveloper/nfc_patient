import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/models/prescription.dart';
import 'package:nfc_patient_registration/services/database_service.dart';

class PrescriptionView extends StatefulWidget {
  final Prescription prescription;

  const PrescriptionView({
    Key? key, 
    required this.prescription,
  }) : super(key: key);

  @override
  _PrescriptionViewState createState() => _PrescriptionViewState();
}

class _PrescriptionViewState extends State<PrescriptionView> {
  bool _isUpdating = false;
  String _errorMessage = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _status = widget.prescription.status;
  }

  // Update prescription status
  Future<void> _updateStatus(String status) async {
    setState(() {
      _isUpdating = true;
      _errorMessage = '';
    });

    try {
      final databaseService = DatabaseService();
      await databaseService.updatePrescriptionStatus(
        widget.prescription.prescriptionId,
        status,
      );

      setState(() {
        _status = status;
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescription = widget.prescription;
    
    // Format timestamps
    final createdAt = prescription.createdAt;
    final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final formattedTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Prescription Details',style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Status: ${_status.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_status == 'pending') ...[
                    SizedBox(height: 8),
                    Text(
                      'Waiting for medication to be dispensed',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),

            // Patient and doctor info
            Card(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Patient Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Text(
                          '$formattedDate $formattedTime',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.person,
                      label: 'Patient',
                      value: prescription.patientName ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.numbers,
                      label: 'Patient ID',
                      value: prescription.patientId,
                    ),
                    _buildInfoRow(
                      icon: Icons.medical_services,
                      label: 'Doctor',
                      value: 'Dr. ${prescription.doctorName ?? 'Unknown'}',
                    ),
                    _buildInfoRow(
                      icon: Icons.medical_information,
                      label: 'Diagnosis',
                      value: prescription.diagnosis,
                    ),
                    if (prescription.notes != null && prescription.notes!.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.note,
                        label: 'Notes',
                        value: prescription.notes!,
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Medications
            Text(
              'Medications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            Divider(),
            SizedBox(height: 8),

            ...prescription.medications.map((medication) {
              return Card(
                margin: EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Divider(),
                      SizedBox(height: 8),
                      _buildMedicationInfoRow(
                        label: 'Dosage',
                        value: medication.dosage,
                      ),
                      _buildMedicationInfoRow(
                        label: 'Frequency',
                        value: medication.frequency,
                      ),
                      _buildMedicationInfoRow(
                        label: 'Duration',
                        value: '${medication.duration} days',
                      ),
                      if (medication.instructions != null &&
                          medication.instructions!.isNotEmpty)
                        _buildMedicationInfoRow(
                          label: 'Instructions',
                          value: medication.instructions!,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),

            SizedBox(height: 24),

            // Error message
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Action buttons
            if (_status == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating
                      ? null
                      : () => _updateStatus('dispensed'),
                  icon: _isUpdating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.check_circle),
                  label: Text('Mark as Dispensed'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),

            if (_status == 'dispensed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating
                      ? null
                      : () => _updateStatus('completed'),
                  icon: _isUpdating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.check_circle),
                  label: Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue,
                  ),
                ),
              ),

            SizedBox(height: 16),

            if (_status == 'completed')
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This prescription has been completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'The medications have been dispensed to the patient',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case 'pending':
        return Colors.orange;
      case 'dispensed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey[600],
          ),
          SizedBox(width: 8),
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

  Widget _buildMedicationInfoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
}