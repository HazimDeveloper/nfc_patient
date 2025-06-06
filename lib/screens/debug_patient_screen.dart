import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart';
import '../services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart';

class DebugPatientScreen extends StatefulWidget {
  const DebugPatientScreen({Key? key}) : super(key: key);

  @override
  State<DebugPatientScreen> createState() => _DebugPatientScreenState();
}

class _DebugPatientScreenState extends State<DebugPatientScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _allPatients = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-load patients when screen opens (if authenticated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _loadAllPatients();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check authentication state first
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Debug: All Patients'),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If no user is logged in, show login prompt
        if (authSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Debug: All Patients'),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_off,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Not Logged In',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You need to be logged in to view patients.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to login screen
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    child: const Text('Go to Login'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        // User is logged in - show the normal debug screen
        return _buildDebugScreen(authSnapshot.data!);
      },
    );
  }

  Widget _buildDebugScreen(User user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: All Patients'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllPatients,
          ),
        ],
      ),
      body: Column(
        children: [
          // User info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.green.shade100,
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logged in as: ${user.email}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'UID: ${user.uid}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
          
          // Debug info card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bug_report, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Development Debug Tool',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Total Patients: ${_allPatients.length}'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _loadAllPatients,
                        child: const Text('Reload Patients'),
                      ),
                      ElevatedButton(
                        onPressed: _checkAuthenticationStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Check Auth'),
                      ),
                    ],
                  ),
                ],
              ),
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading patients...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllPatients,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allPatients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No patients found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add patients using the registration form',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _allPatients.length,
      itemBuilder: (context, index) {
        final patient = _allPatients[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                (patient['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(patient['name'] ?? 'Unknown Name'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IC: ${patient['icNumber'] ?? 'N/A'}'),
                Text('ID: ${patient['patientId'] ?? 'N/A'}'),
                if (patient['status'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(patient['status']),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      patient['status'].toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientDetailsScreen(patient: patient),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'registered':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadAllPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Starting debug patient load...');
      
      // Check authentication first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Not logged in. Please login first.';
          _isLoading = false;
        });
        return;
      }
      
      print('User is logged in: ${currentUser.email}');
      
      // Run full debug check
      await _databaseService.fullDebugCheck();
      
      // Try to get patients
      final patients = await _databaseService.getPatientsWithoutOrdering();
      
      setState(() {
        _allPatients = patients;
        _isLoading = false;
      });
      
      if (patients.isEmpty) {
        setState(() {
          _error = 'No patients found in database.\n\n'
                 'This could mean:\n'
                 '• Database is empty\n'
                 '• Firestore rules are blocking access\n'
                 '• User doesn\'t have proper role\n\n'
                 'Check console logs for more details.';
        });
      } else {
        print('Successfully loaded ${patients.length} patients');
      }
    } catch (e) {
      print('Error in _loadAllPatients: $e');
      setState(() {
        _error = 'Error: ${e.toString()}\n\n'
                 'Check console logs for details.';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    String message = '';
    if (currentUser == null) {
      message = 'No user logged in.\n\nPlease login first.';
    } else {
      message = 'Logged in as:\n'
               'Email: ${currentUser.email}\n'
               'UID: ${currentUser.uid}\n'
               'Email Verified: ${currentUser.emailVerified}';
    }
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Authentication Status'),
          content: Text(message),
          actions: [
            if (currentUser == null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Go to Login'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (currentUser != null) {
                  _loadAllPatients();
                }
              },
              child: Text(currentUser != null ? 'Try Again' : 'OK'),
            ),
          ],
        ),
      );
    }
  }
}