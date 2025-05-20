import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/patient/nfc_scan_screen.dart';
import 'package:nfc_patient_registration/screens/nurse/nfc_card_registration.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';

class NurseHome extends StatefulWidget {
  @override
  _NurseHomeState createState() => _NurseHomeState();
}

class _NurseHomeState extends State<NurseHome> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _newPatients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNewPatients();
  }

  // Load new patients that need doctor assignment
  Future<void> _loadNewPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final patients = await _databaseService.getNewPatients();
      setState(() {
        _newPatients = patients;
        _isLoading = false;
      });
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
        title: Text('Nurse Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNewPatients,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NFCCardRegistration(),
            ),
          ).then((_) => _loadNewPatients());
        },
        icon: Icon(Icons.person_add),
        label: Text('Register Patient'),
      ),
    );
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
              onPressed: _loadNewPatients,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Quick actions bar
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: Icons.contactless,
                    label: 'Scan NFC Card',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NFCScanScreen(
                            action: NFCAction.read,
                            onDataRead: (data) {
                              // Handle NFC data read
                              if (data.containsKey('cardSerialNumber') || data.containsKey('id')) {
                                final cardSerialNumber = data['cardSerialNumber'] ?? data['id'];
                                _checkPatientByCardSerial(cardSerialNumber);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.person_add,
                    label: 'New Patient',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NFCCardRegistration(),
                        ),
                      ).then((_) => _loadNewPatients());
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.format_list_bulleted,
                    label: 'All Patients',
                    onPressed: () {
                      // TODO: Navigate to all patients screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('All patients view coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // New patients section
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Patients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_newPatients.length} need assignment',
                style: TextStyle(
                  color: _newPatients.isNotEmpty
                      ? Colors.orange
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Patient list
        Expanded(
          child: _newPatients.isEmpty
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
                        'All patients have been assigned',
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
                  itemCount: _newPatients.length,
                  itemBuilder: (context, index) {
                    final patient = _newPatients[index];
                    return _buildPatientCard(patient);
                  },
                ),
        ),
      ],
    );
  }

  // Check if a patient exists by card serial number
  Future<void> _checkPatientByCardSerial(String cardSerialNumber) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final patient = await _databaseService.getPatientByCardSerial(cardSerialNumber);
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (patient != null) {
        // Patient found - show details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Patient Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This card is already registered to:'),
                SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.person,
                  label: 'Name',
                  value: patient['name'] ?? 'Unknown',
                ),
                _buildInfoRow(
                  icon: Icons.numbers,
                  label: 'ID',
                  value: patient['patientId'] ?? 'Unknown',
                ),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'DOB',
                  value: patient['dateOfBirth'] ?? 'Unknown',
                ),
                SizedBox(height: 8),
                Text(
                  'You can view the patient details or assign a doctor if needed.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
              if (patient['currentAppointment'] == null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignDoctorScreen(
                          patientId: patient['patientId'],
                          patientName: patient['name'],
                        ),
                      ),
                    ).then((_) => _loadNewPatients());
                  },
                  child: Text('Assign Doctor'),
                ),
            ],
          ),
        );
      } else {
        // Card not registered - proceed to registration
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('New Card Detected'),
            content: Text('This NFC card is not registered yet. Would you like to register a new patient with this card?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NFCCardRegistration(),
                    ),
                  ).then((_) => _loadNewPatients());
                },
                child: Text('Register Patient'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking card: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: CircleBorder(),
            padding: EdgeInsets.all(16),
          ),
          child: Icon(
            icon,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final registrationDate = patient['registrationDate']?.toDate();
    final formattedDate = registrationDate != null
        ? '${registrationDate.day}/${registrationDate.month}/${registrationDate.year}'
        : 'Unknown';

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
            // Patient name and registration date
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
                        'Registered: $formattedDate',
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
                    'New',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
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
              ),
            
            SizedBox(height: 16),
            
            // Assign doctor button
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
                  ).then((_) => _loadNewPatients());
                },
                icon: Icon(Icons.assignment_ind),
                label: Text('Assign Doctor & Room'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
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
          Icon(
            icon,
            size: 18,
            color: Colors.grey[600],
          ),
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