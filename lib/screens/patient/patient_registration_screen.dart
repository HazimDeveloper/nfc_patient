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
  bool _isCardValidated = false;
  
  DateTime? _selectedDate;
  String _effectiveCardSerialNumber = '';
  
  @override
  void initState() {
    super.initState();
    // Store the card serial number and validate it
    _effectiveCardSerialNumber = widget.cardSerialNumber.trim();
    print('Received card serial number: "$_effectiveCardSerialNumber"');
    
    // If card serial number is empty, generate a temporary one for testing
    if (_effectiveCardSerialNumber.isEmpty) {
      _effectiveCardSerialNumber = 'CARD_${DateTime.now().millisecondsSinceEpoch}';
      print('Generated card serial number: $_effectiveCardSerialNumber');
      
      // Show a warning to the user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: No card serial detected. Using generated ID: $_effectiveCardSerialNumber'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      });
    } else {
      // Validate the card before allowing registration
      _validateCard();
    }
  }
  
  // Validate that the card is not already registered
  Future<void> _validateCard() async {
    try {
      final databaseService = DatabaseService();
      final cardCheck = await databaseService.checkCardRegistration(_effectiveCardSerialNumber);
      
      if (cardCheck != null && cardCheck['isRegistered'] == true) {
        final existingPatient = cardCheck['patientData'] as Map<String, dynamic>;
        
        // Card is already registered - show error and prevent registration
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCardAlreadyRegisteredDialog(existingPatient);
        });
        
        setState(() {
          _isCardValidated = false;
          _errorMessage = 'This NFC card is already registered to another patient.';
        });
      } else {
        setState(() {
          _isCardValidated = true;
          _errorMessage = '';
        });
      }
    } catch (e) {
      print('Error validating card: $e');
      setState(() {
        _isCardValidated = false;
        _errorMessage = 'Unable to validate NFC card. Please try again.';
      });
    }
  }
  
  // Show dialog when card is already registered
  void _showCardAlreadyRegisteredDialog(Map<String, dynamic> existingPatient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Card Already Registered'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This NFC card is already registered to:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${existingPatient['name'] ?? 'Unknown'}'),
                  Text('Patient ID: ${existingPatient['patientId'] ?? 'Unknown'}'),
                  Text('Date of Birth: ${existingPatient['dateOfBirth'] ?? 'Unknown'}'),
                  Text('Phone: ${existingPatient['phone'] ?? 'Unknown'}'),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Each NFC card can only be registered to one patient. Please use a different card or register without NFC.',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to NFC scan screen
            },
            child: Text('Use Different Card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
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
    
    // Final validation of card serial number and registration status
    if (_effectiveCardSerialNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Card serial number cannot be empty. Please scan a valid NFC card first.';
      });
      return;
    }
    
    if (!_isCardValidated && !_effectiveCardSerialNumber.startsWith('CARD_') && !_effectiveCardSerialNumber.startsWith('MANUAL_')) {
      setState(() {
        _errorMessage = 'Please validate the NFC card before proceeding.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final databaseService = DatabaseService();
      
      print('Registering patient with card serial: "$_effectiveCardSerialNumber"');
      
      final patientData = await databaseService.registerPatient(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        gender: _selectedGender,
        address: _addressController.text.trim(),
        bloodType: _bloodType,
        emergencyContact: _emergencyContactController.text.trim().isNotEmpty 
            ? _emergencyContactController.text.trim() 
            : null,
        allergies: _allergies,
        medications: _medications,
        conditions: _conditions,
        cardSerialNumber: _effectiveCardSerialNumber,
      );
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to NFC writer screen with the patient data if using real NFC card
        if (!_effectiveCardSerialNumber.startsWith('CARD_') && !_effectiveCardSerialNumber.startsWith('MANUAL_')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NFCScanScreen(
                action: NFCAction.write,
                dataToWrite: patientData,
                onWriteComplete: (success) {
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('NFC card written successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Go back to nurse home
                    Navigator.popUntil(context, (route) => route.isFirst);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to write to NFC card, but patient is registered'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    
                    // Go back to nurse home
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                },
              ),
            ),
          );
        } else {
          // For generated or manual IDs, just go back
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        print('Error registering patient: $_errorMessage');
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
                            color: _isCardValidated 
                                ? Colors.green
                                : _effectiveCardSerialNumber.startsWith('CARD_') || _effectiveCardSerialNumber.startsWith('MANUAL_')
                                    ? Colors.orange 
                                    : Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'NFC Card Serial Number',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isCardValidated 
                                  ? Colors.green[800]
                                  : _effectiveCardSerialNumber.startsWith('CARD_') || _effectiveCardSerialNumber.startsWith('MANUAL_')
                                      ? Colors.orange[800]
                                      : Colors.red[800],
                            ),
                          ),
                          Spacer(),
                          if (_isCardValidated)
                            Icon(Icons.check_circle, color: Colors.green, size: 20)
                          else if (!_effectiveCardSerialNumber.startsWith('CARD_') && !_effectiveCardSerialNumber.startsWith('MANUAL_'))
                            Icon(Icons.error, color: Colors.red, size: 20),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isCardValidated 
                              ? Colors.green.withOpacity(0.1)
                              : _effectiveCardSerialNumber.startsWith('CARD_') || _effectiveCardSerialNumber.startsWith('MANUAL_')
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isCardValidated 
                                ? Colors.green
                                : _effectiveCardSerialNumber.startsWith('CARD_') || _effectiveCardSerialNumber.startsWith('MANUAL_')
                                    ? Colors.orange
                                    : Colors.red,
                            width: 1
                          ),
                        ),
                        child: SelectableText(
                          _effectiveCardSerialNumber,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: _isCardValidated 
                                ? Colors.green[800]
                                : _effectiveCardSerialNumber.startsWith('CARD_') || _effectiveCardSerialNumber.startsWith('MANUAL_')
                                    ? Colors.orange[800]
                                    : Colors.red[800],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _isCardValidated 
                            ? '✓ Card is available for registration'
                            : _effectiveCardSerialNumber.startsWith('CARD_')
                                ? 'Note: This is a generated ID since no NFC card was detected.'
                                : _effectiveCardSerialNumber.startsWith('MANUAL_')
                                    ? 'Note: Manual registration without NFC card.'
                                    : '⚠ This card is already registered to another patient.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isCardValidated 
                              ? Colors.green[700]
                              : _effectiveCardSerialNumber.startsWith('CARD_') || _effectiveCardSerialNumber.startsWith('MANUAL_')
                                  ? Colors.orange[700]
                                  : Colors.red[700],
                          fontStyle: FontStyle.italic,
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
                            style: TextStyle(
                              color: Colors.red[800],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Submit button
              ElevatedButton.icon(
                onPressed: (_isLoading || (!_isCardValidated && !_effectiveCardSerialNumber.startsWith('CARD_') && !_effectiveCardSerialNumber.startsWith('MANUAL_')))
                    ? null 
                    : _submitForm,
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
              
              // Help text for disabled button
              if (!_isCardValidated && !_effectiveCardSerialNumber.startsWith('CARD_') && !_effectiveCardSerialNumber.startsWith('MANUAL_'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Registration is disabled because the NFC card is already registered to another patient. Please use a different card.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[700],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
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