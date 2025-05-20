import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/patient/nfc_scan_screen.dart';

class PatientRegistrationScreen extends StatefulWidget {
  final String cardSerialNumber;
  
  const PatientRegistrationScreen({
    Key? key, 
    required this.cardSerialNumber,
  }) : super(key: key);

  @override
  _PatientRegistrationScreenState createState() => _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  
  String _selectedGender = 'Male';
  String? _bloodType;
  final _emergencyContactController = TextEditingController();
  
  final List<String> _allergies = [];
  final List<String> _medications = [];
  final List<String> _conditions = [];
  
  final _newAllergyController = TextEditingController();
  final _newMedicationController = TextEditingController();
  final _newConditionController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  DateTime? _selectedDate;
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _newAllergyController.dispose();
    _newMedicationController.dispose();
    _newConditionController.dispose();
    super.dispose();
  }
  
  // Show date picker for Date of Birth
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }
  
  // Add a new item to a list (allergy, medication, condition)
  void _addItem(TextEditingController controller, List<String> list) {
    final value = controller.text.trim();
    if (value.isNotEmpty) {
      setState(() {
        list.add(value);
        controller.clear();
      });
    }
  }
  
  // Remove an item from a list
  void _removeItem(int index, List<String> list) {
    setState(() {
      list.removeAt(index);
    });
  }
  
  // Submit form and register patient
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
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
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        gender: _selectedGender,
        address: _addressController.text.trim(),
        bloodType: _bloodType,
        emergencyContact: _emergencyContactController.text.trim(),
        allergies: _allergies,
        medications: _medications,
        conditions: _conditions,
        cardSerialNumber: widget.cardSerialNumber,
      );
      
      // Navigate to NFC writer screen with the patient data
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NFCScanScreen(
              action: NFCAction.write,
              dataToWrite: patientData,
              onWriteComplete: (success) {
                if (success) {
                  // Reset form on success
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Patient registered successfully and NFC card written'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Navigate back to the nurse home screen
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                }
              },
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
        title: Text('Register New Patient'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Card serial number display
              Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 24),
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
                            Icons.contactless,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'NFC Card Serial Number',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          widget.cardSerialNumber,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              
              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter patient name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Date of Birth
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dobController,
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please select date of birth';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Address
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              
              // Medical Information Section
              _buildSectionHeader('Medical Information'),
              
              // Blood Type
              DropdownButtonFormField<String>(
                value: _bloodType,
                decoration: InputDecoration(
                  labelText: 'Blood Type',
                  prefixIcon: Icon(Icons.bloodtype),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [null, 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type ?? 'Unknown'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _bloodType = value;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Emergency Contact
              TextFormField(
                controller: _emergencyContactController,
                decoration: InputDecoration(
                  labelText: 'Emergency Contact',
                  prefixIcon: Icon(Icons.emergency),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              // Allergies
              _buildListSection(
                title: 'Allergies',
                icon: Icons.dangerous,
                items: _allergies,
                controller: _newAllergyController,
                onAdd: () => _addItem(_newAllergyController, _allergies),
                onRemove: (index) => _removeItem(index, _allergies),
              ),
              SizedBox(height: 16),
              
              // Current Medications
              _buildListSection(
                title: 'Current Medications',
                icon: Icons.medication,
                items: _medications,
                controller: _newMedicationController,
                onAdd: () => _addItem(_newMedicationController, _medications),
                onRemove: (index) => _removeItem(index, _medications),
              ),
              SizedBox(height: 16),
              
              // Medical Conditions
              _buildListSection(
                title: 'Medical Conditions',
                icon: Icons.healing,
                items: _conditions,
                controller: _newConditionController,
                onAdd: () => _addItem(_newConditionController, _conditions),
                onRemove: (index) => _removeItem(index, _conditions),
              ),
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
                label: Text('Register Patient'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build section header
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Divider(color: Theme.of(context).primaryColor),
        SizedBox(height: 16),
      ],
    );
  }
  
  // Build list section (allergies, medications, conditions)
  Widget _buildListSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        
        // Add new item
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Add $title',
                  prefixIcon: Icon(icon),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: onAdd,
              icon: Icon(Icons.add_circle),
              color: Theme.of(context).primaryColor,
              iconSize: 32,
            ),
          ],
        ),
        SizedBox(height: 8),
        
        // List of items
        if (items.isNotEmpty)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(icon, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(item),
                      ),
                      IconButton(
                        onPressed: () => onRemove(index),
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}