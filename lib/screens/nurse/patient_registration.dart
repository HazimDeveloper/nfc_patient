import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';

class PatientRegistrationScreen extends StatefulWidget {
  final String? cardSerialNumber;
  
  const PatientRegistrationScreen({
    Key? key, 
    this.cardSerialNumber,
  }) : super(key: key);

  @override
  _PatientRegistrationScreenState createState() => _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  String _effectiveCardSerialNumber = '';
  
  @override
  void initState() {
    super.initState();
    _initializeCardSerial();
  }
  
  void _initializeCardSerial() {
    if (widget.cardSerialNumber != null && widget.cardSerialNumber!.trim().isNotEmpty) {
      _effectiveCardSerialNumber = widget.cardSerialNumber!.trim();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('NFC card is required for patient registration'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      });
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_effectiveCardSerialNumber.isEmpty) {
      setState(() {
        _errorMessage = 'NFC card is required for registration';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final databaseService = DatabaseService();
      
      final patientData = await databaseService.registerPatient(
        name: _nameController.text.trim(),
        email: '${_nameController.text.trim().toLowerCase().replaceAll(' ', '')}@hospital.com',
        phone: '000-0000000',
        dateOfBirth: '01/01/2000',
        gender: 'Unknown',
        address: 'Hospital Registration',
        cardSerialNumber: _effectiveCardSerialNumber,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to assign doctor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AssignDoctorScreen(
              patientId: patientData['patientId'],
              patientName: patientData['name'],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register New Patient', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              // NFC Card Information
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.contactless, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'NFC Card Ready',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Card ID: $_effectiveCardSerialNumber',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Simple name input
              Text(
                'Patient Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 8),
              
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  labelStyle: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(Icons.person, color: Colors.red[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Patient name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Info note
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Quick Registration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Only patient name is required for quick registration. Other details can be added later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Error message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red[800], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Submit button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitForm,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.person_add),
                label: Text(_isLoading ? 'Registering...' : 'Register & Assign Doctor'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}