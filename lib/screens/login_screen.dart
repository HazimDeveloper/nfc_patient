import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _icController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true; // toggle between login and register
  bool _isPatientLogin = false; // toggle between staff and patient login
  String _errorMessage = '';
  String _selectedRole = 'nurse'; // default role for registration

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _icController.dispose();
    super.dispose();
  }

  // Toggle between login and register
  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = '';
    });
  }

  // Toggle between staff and patient login
  void _toggleLoginType() {
    setState(() {
      _isPatientLogin = !_isPatientLogin;
      _errorMessage = '';
      _emailController.clear();
      _passwordController.clear();
      _icController.clear();
    });
  }

  // Handle form submission
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (_isPatientLogin) {
        // Patient login using IC number
        await authService.signInPatientWithIC(_icController.text.trim());
      } else {
        if (_isLogin) {
          // Staff login
          await authService.signInWithEmailAndPassword(
            _emailController.text.trim(), 
            _passwordController.text,
          );
        } else {
          // Staff register
          await authService.registerWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
            'New User',
            _selectedRole,
          );
        }
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo
                  Hero(
                    tag: 'logo',
                    child: Icon(
                      Icons.local_hospital,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Login type toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPatientLogin = false),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isPatientLogin ? Theme.of(context).primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Staff Login',
                                style: TextStyle(
                                  color: !_isPatientLogin ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPatientLogin = true),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isPatientLogin ? Theme.of(context).primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Patient Login',
                                style: TextStyle(
                                  color: _isPatientLogin ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Title
                  Text(
                    _isPatientLogin 
                        ? 'Patient Access'
                        : _isLogin ? 'Staff Login' : 'Create Staff Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    _isPatientLogin
                        ? 'Enter your IC number to view your information'
                        : _isLogin
                            ? 'Sign in to continue'
                            : 'Register to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  
                  // Patient IC field or Staff email/password
                  if (_isPatientLogin) ...[
                    TextFormField(
                      controller: _icController,
                      decoration: InputDecoration(
                        labelText: 'IC Number',
                        prefixIcon: Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText: 'Enter your IC number (same as on your NFC card)',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your IC number';
                        }
                        if (value.length < 6) {
                          return 'Please enter a valid IC number';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    // Email field
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
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (!_isLogin && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Role selection for registration
                    if (!_isLogin)
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'doctor',
                            child: Text('Doctor'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'nurse',
                            child: Text('Nurse'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'pharmacist',
                            child: Text('Pharmacist'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedRole = value;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a role';
                          }
                          return null;
                        },
                      ),
                  ],
                  
                  if (!_isLogin && !_isPatientLogin) SizedBox(height: 16),
                  
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
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isPatientLogin 
                                ? 'Access My Information'
                                : _isLogin ? 'Sign In' : 'Register',
                            style: TextStyle(fontSize: 16),
                          ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  // Toggle button for staff only
                  if (!_isPatientLogin) ...[
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _toggleAuthMode,
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Register'
                            : 'Already have an account? Sign In',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  
                  // Help text for patients
                  if (_isPatientLogin) ...[
                    SizedBox(height: 24),
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
                                'Patient Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Use the same IC number that was registered with your NFC card to view your medical information and appointments.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}