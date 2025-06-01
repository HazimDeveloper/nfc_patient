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
  String _effectiveCardSerialNumber = '';
  final _icController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initializeCardSerial();
  }
  
  void _initializeCardSerial() {
    // Generate a realistic Malaysian IC number
    final now = DateTime.now();
    
    // Check if we received a valid card serial number
    String receivedSerial = widget.cardSerialNumber.trim();
    
    if (receivedSerial.isEmpty || 
        receivedSerial.startsWith('TAG-') ||
        receivedSerial.startsWith('CARD_') ||
        receivedSerial.startsWith('MANUAL_') ||
        receivedSerial.length < 5) {
      
      // Generate Malaysian IC format: YYMMDD-PB-GGGG
      String year = now.year.toString().substring(2);
      String month = now.month.toString().padLeft(2, '0');
      String day = now.day.toString().padLeft(2, '0');
      String placeOfBirth = (now.hour % 59 + 1).toString().padLeft(2, '0');
      String gender = now.second % 2 == 0 ? '1' : '2'; // 1=male, 2=female
      String lastDigits = (now.millisecond % 899 + 100).toString();
      
      _effectiveCardSerialNumber = '$year$month$day-$placeOfBirth-$gender$lastDigits';
    } else {
      _effectiveCardSerialNumber = receivedSerial;
    }
    
    // Set the IC in the controller
    _icController.text = _effectiveCardSerialNumber;
    
    print('Initialized patient registration with IC: $_effectiveCardSerialNumber');
    
    // Show the generated IC to user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient IC Number: $_effectiveCardSerialNumber'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    });
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
    _icController.dispose();
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
  
  // Generate a new IC number
  void _generateNewIC() {
    final now = DateTime.now();
    String year = now.year.toString().substring(2);
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    String placeOfBirth = (now.hour % 59 + 1).toString().padLeft(2, '0');
    String gender = now.second % 2 == 0 ? '1' : '2';
    String lastDigits = (now.millisecond % 899 + 100).toString();
    
    String newIC = '$year$month$day-$placeOfBirth-$gender$lastDigits';
    
    setState(() {
      _effectiveCardSerialNumber = newIC;
      _icController.text = newIC;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New IC generated: $newIC'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  // Validate IC format (basic Malaysian IC format check)
  bool _isValidICFormat(String ic) {
    // Basic format: YYMMDD-PB-GGGG or YYMMDDPBGGGG
    final icPattern = RegExp(r'^\d{6}-?\d{2}-?\d{4}$');
    return icPattern.hasMatch(ic) && ic.length >= 10;
  }
  
  // Submit form and register patient
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Get IC from the input field
    _effectiveCardSerialNumber = _icController.text.trim();
    
    // Ensure we have a valid IC number
    if (_effectiveCardSerialNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid IC number';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final databaseService = DatabaseService();
      
      print('Attempting to register patient with IC: "$_effectiveCardSerialNumber"');
      print('Patient name: "${_nameController.text.trim()}"');
      print('Patient email: "${_emailController.text.trim()}"');
      
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
            content: Text('✅ Patient registered successfully!\nIC: $_effectiveCardSerialNumber'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        
        // Navigate back to nurse dashboard
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: ${e.toString()}';
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
              // IC Number Management Card (Quick Actions)
              Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.blue.withOpacity(0.1), Colors.teal.withOpacity(0.1)],
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
                              Icons.info_outline,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Patient Registration Info',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Current IC Number: ${_icController.text.isNotEmpty ? _icController.text : 'Not set'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'You can edit the IC number in the form below or generate a new one.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _generateNewIC,
                              icon: Icon(Icons.refresh, size: 16),
                              label: Text('New IC', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              
              // IC Number in Basic Information
              TextFormField(
                controller: _icController,
                decoration: InputDecoration(
                  labelText: 'IC Number *',
                  hintText: 'e.g., 991231-01-1234',
                  prefixIcon: Icon(Icons.credit_card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.refresh, size: 20),
                        onPressed: _generateNewIC,
                        tooltip: 'Generate New IC',
                      ),
                      IconButton(
                        icon: Icon(Icons.help_outline, size: 20),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('IC Number Format'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Malaysian IC format:'),
                                  SizedBox(height: 8),
                                  Text('YYMMDD-PB-GGGG', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  Text('• YY: Year of birth'),
                                  Text('• MM: Month of birth'),
                                  Text('• DD: Day of birth'),
                                  Text('• PB: Place of birth code'),
                                  Text('• GGGG: Gender and serial number'),
                                  SizedBox(height: 8),
                                  Text('Example: 991231-01-1234'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                        tooltip: 'IC Format Help',
                      ),
                    ],
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _effectiveCardSerialNumber = value.trim();
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter IC number';
                  }
                  if (!_isValidICFormat(value.trim())) {
                    return 'Please enter a valid IC format (YYMMDD-PB-GGGG)';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8),
              // IC Validation feedback
              Row(
                children: [
                  Icon(
                    _isValidICFormat(_icController.text) 
                        ? Icons.check_circle 
                        : Icons.info,
                    size: 16,
                    color: _isValidICFormat(_icController.text) 
                        ? Colors.green 
                        : Colors.orange,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _isValidICFormat(_icController.text)
                          ? 'Valid IC format ✓'
                          : 'Enter IC in format: YYMMDD-PB-GGGG',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isValidICFormat(_icController.text) 
                            ? Colors.green[700] 
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
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
                  labelText: 'Email Address *',
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
                  labelText: 'Phone Number *',
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
                      labelText: 'Date of Birth *',
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
                  labelText: 'Gender *',
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
                  labelText: 'Address *',
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
              
              SizedBox(height: 16),
              
              // Help text
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fields marked with * are required. You can edit the IC number or generate a new one using the refresh button.',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 12,
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
                onFieldSubmitted: (_) => onAdd(),
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