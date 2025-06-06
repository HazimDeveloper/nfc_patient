// lib/screens/debug_patient_screen.dart - CREATE THIS NEW FILE
import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/database_service.dart';

class DebugPatientScreen extends StatefulWidget {
  @override
  _DebugPatientScreenState createState() => _DebugPatientScreenState();
}

class _DebugPatientScreenState extends State<DebugPatientScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _allPatients = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllPatients();
  }

  Future<void> _loadAllPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final patients = await _databaseService.getAllPatientsForDebug();
      setState(() {
        _allPatients = patients;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug: All Patients', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllPatients,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.orange.withOpacity(0.1),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Development Debug Tool',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Total Patients: ${_allPatients.length}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
          
          // Patient list
          Expanded(
            child: _buildPatientList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading all patients...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllPatients,
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_allPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No patients found in database',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _allPatients.length,
      itemBuilder: (context, index) {
        final patient = _allPatients[index];
        return _buildPatientDebugCard(patient, index);
      },
    );
  }

  Widget _buildPatientDebugCard(Map<String, dynamic> patient, int index) {
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
            // Header with index
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    patient['name'] ?? 'Unknown Name',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            Divider(),
            
            // Debug information
            _buildDebugRow('Document ID', patient['documentId'] ?? 'Unknown'),
            _buildDebugRow('Patient ID', patient['patientId'] ?? 'Not Set'),
            _buildDebugRow('IC Number', patient['icNumber'] ?? 'Not Set'),
            _buildDebugRow('Card Serial', patient['cardSerialNumber'] ?? 'Not Set'),
            _buildDebugRow('Email', patient['email'] ?? 'Not Set'),
            _buildDebugRow('Phone', patient['phone'] ?? 'Not Set'),
            _buildDebugRow('Status', patient['status'] ?? 'Unknown'),
            
            SizedBox(height: 12),
            
            // Test login button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _testPatientLogin(patient),
                icon: Icon(Icons.login),
                label: Text('Test Login with IC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
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
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: value.contains('DEV') || value.contains('NFC') ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _testPatientLogin(Map<String, dynamic> patient) {
    final icNumber = patient['icNumber'] ?? patient['patientId'] ?? '';
    
    if (icNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No IC number found for this patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Test Patient Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${patient['name']}'),
            SizedBox(height: 8),
            Text('IC Number: $icNumber'),
            SizedBox(height: 16),
            Text(
              'Use this IC number to test patient login:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                icNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to login
            },
            child: Text('Go to Login'),
          ),
        ],
      ),
    );
  }
}