import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/database_service.dart';

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
    _initializeCardSerial();
  }
  
  void _initializeCardSerial() {
    if (widget.cardSerialNumber != null && widget.cardSerialNumber!.trim().isNotEmpty) {
      _effectiveCardSerialNumber = widget.cardSerialNumber!.trim();
      _validateCard();
    } else {
      // No card serial provided - navigate back with error
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
  
  Future<void> _validateCard() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final databaseService = DatabaseService();
      final cardCheck = await databaseService.checkCardRegistration(_effectiveCardSerialNumber);
      
      if (cardCheck != null && cardCheck['isRegistered'] == true) {
        final existingPatient = cardCheck['patientData'] as Map<String, dynamic>;
        _showCardAlreadyRegisteredDialog(existingPatient);
        setState(() {
          _isCardValidated = false;
          _errorMessage = 'This NFC card is already registered to ${existingPatient['name']}.';
        });
      } else {
        setState(() {
          _isCardValidated = true;
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _isCardValidated = false;
        _errorMessage = 'Unable to validate NFC card: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showCardAlreadyRegisteredDialog(Map<String, dynamic> existingPatient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.orange),
            SizedBox(width: 8),
            Text('Patient Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This NFC card is already registered to:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${existingPatient['name'] ?? 'Unknown'}', 
                       style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Patient ID: ${existingPatient['patientId'] ?? 'Unknown'}'),
                  Text('Phone: ${existingPatient['phone'] ?? 'Unknown'}'),
                  if (existingPatient['email'] != null)
                    Text('Email: ${existingPatient['email']}'),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The patient data is already in the system. You can view their details or assign them to a doctor if needed.',
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to scan screen
            },
            child: Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to scan screen
              // The scan screen will handle showing patient options
            },
            child: Text('View Patient'),
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
  
  void _addItem(TextEditingController controller, List<String> list) {
    final value = controller.text.trim();
    if (value.isNotEmpty) {
      setState(() {
        list.add(value);
        controller.clear();
      });
    }
  }
  
  void _removeItem(int index, List<String> list) {
    setState(() {
      list.removeAt(index);
    });
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isCardValidated) {
      setState(() {
        _errorMessage = 'Please use a valid NFC card for registration';
      });
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
        _showSuccessDialog(patientData);
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

  void _showSuccessDialog(Map<String, dynamic> patientData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('Registration Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                children: [
                  Icon(Icons.person_add, color: Colors.green, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Patient Successfully Registered',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text('Patient: ${patientData['name']}'),
                  Text('ID: ${patientData['patientId']}'),
                  Text('Card: ${patientData['cardSerialNumber']}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.popUntil(context, (route) => route.isFirst); // Go to home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Complete'),
          ),
        ],
      ),
    );
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
              _buildNFCCardInfoCard(),
              SizedBox(height: 24),
              
              // Card validation status
              if (_isLoading)
                _buildLoadingCard()
              else if (!_isCardValidated && _errorMessage.isNotEmpty)
                _buildValidationErrorCard()
              else if (_isCardValidated)
                _buildValidationSuccessCard(),
              
              if (_isCardValidated) ...[
                SizedBox(height: 24),
                
                // Required Fields Section
                _buildSectionHeader('Required Information', Icons.star, Colors.red),
                
                _buildRequiredTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
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
                
                _buildRequiredTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email address is required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                _buildRequiredTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Date of Birth with required indicator
                _buildRequiredDateField(),
                SizedBox(height: 16),
                
                // Gender with required indicator
                _buildRequiredGenderField(),
                SizedBox(height: 16),
                
                _buildRequiredTextField(
                  controller: _addressController,
                  label: 'Address',
                  icon: Icons.home,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                
                // Optional Medical Information Section
                _buildSectionHeader('Medical Information (Optional)', Icons.medical_information, Colors.blue),
                
                _buildOptionalDropdown(
                  value: _bloodType,
                  label: 'Blood Type',
                  icon: Icons.bloodtype,
                  items: [null, 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                  onChanged: (value) => setState(() => _bloodType = value),
                ),
                SizedBox(height: 16),
                
                _buildOptionalTextField(
                  controller: _emergencyContactController,
                  label: 'Emergency Contact',
                  icon: Icons.emergency,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 24),
                
                // Medical Lists Section
                _buildSectionHeader('Medical History (Optional)', Icons.history, Colors.orange),
                
                _buildListSection(
                  title: 'Allergies',
                  icon: Icons.dangerous,
                  items: _allergies,
                  controller: _newAllergyController,
                  onAdd: () => _addItem(_newAllergyController, _allergies),
                  onRemove: (index) => _removeItem(index, _allergies),
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                
                _buildListSection(
                  title: 'Current Medications',
                  icon: Icons.medication,
                  items: _medications,
                  controller: _newMedicationController,
                  onAdd: () => _addItem(_newMedicationController, _medications),
                  onRemove: (index) => _removeItem(index, _medications),
                  color: Colors.blue,
                ),
                SizedBox(height: 16),
                
                _buildListSection(
                  title: 'Medical Conditions',
                  icon: Icons.healing,
                  items: _conditions,
                  controller: _newConditionController,
                  onAdd: () => _addItem(_newConditionController, _conditions),
                  onRemove: (index) => _removeItem(index, _conditions),
                  color: Colors.orange,
                ),
                SizedBox(height: 32),
                
                // Error message
                if (_errorMessage.isNotEmpty && _isCardValidated) _buildErrorMessage(),
                
                // Submit button
                _buildSubmitButton(),
                SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNFCCardInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.contactless,
                  color: _isCardValidated ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  'NFC Card Registration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isCardValidated ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isCardValidated ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isCardValidated ? Colors.green : Colors.orange,
                  width: 1
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card Serial Number: $_effectiveCardSerialNumber',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _isCardValidated 
                        ? 'This NFC card is available and will be linked to the patient.'
                        : 'Validating NFC card...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
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

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validating Card',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Checking if this card is already registered...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
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

  Widget _buildValidationSuccessCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
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
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Card Available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'This NFC card is available for patient registration.',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationErrorCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Card Already Registered',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back),
                label: Text('Go Back and Use Different Card'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (title.contains('Required')) ...[
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'REQUIRED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildRequiredTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '$label *',
        labelStyle: TextStyle(
          color: Colors.red[700],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: Colors.red[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
    );
  }
  
  Widget _buildOptionalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '$label (Optional)',
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  Widget _buildRequiredDateField() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        child: TextFormField(
          controller: _dobController,
          decoration: InputDecoration(
            labelText: 'Date of Birth *',
            labelStyle: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.calendar_today, color: Colors.red[700]),
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
              return 'Date of birth is required';
            }
            return null;
          },
        ),
      ),
    );
  }
  
  Widget _buildRequiredGenderField() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        labelText: 'Gender *',
        labelStyle: TextStyle(
          color: Colors.red[700],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.wc, color: Colors.red[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      items: ['Male', 'Female', 'Other']
          .map((gender) => DropdownMenuItem(
                value: gender,
                child: Text(gender),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedGender = value!),
    );
  }
  
  Widget _buildOptionalDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String?> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: '$label (Optional)',
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item ?? 'Select $label'),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
  
  Widget _buildListSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Add $title',
                  prefixIcon: Icon(icon, color: color),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onFieldSubmitted: (value) {
                  if (value.trim().isNotEmpty) onAdd();
                },
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: onAdd,
              icon: Icon(Icons.add_circle, color: color),
              iconSize: 32,
            ),
          ],
        ),
        SizedBox(height: 8),
        
        if (items.isNotEmpty)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      SizedBox(width: 8),
                      Expanded(child: Text(item)),
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
  
  Widget _buildErrorMessage() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
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
    );
  }
  
  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: (_isLoading || !_isCardValidated) ? null : _submitForm,
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
      label: Text(_isLoading ? 'Registering...' : 'Register Patient with NFC Card'),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _isCardValidated ? Theme.of(context).primaryColor : Colors.grey,
        foregroundColor: Colors.white,
      ),
    );
  }
}