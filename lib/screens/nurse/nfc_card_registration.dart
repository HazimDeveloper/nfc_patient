import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/nfc_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/services/card_security_sevice.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_registration.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart';

class NFCCardRegistration extends StatefulWidget {
  @override
  _NFCCardRegistrationState createState() => _NFCCardRegistrationState();
}

class _NFCCardRegistrationState extends State<NFCCardRegistration> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Tap "Scan Card" to begin';
  bool _success = false;
  bool _error = false;
  String? _cardSerialNumber;
  String? _detailedErrorMessage;
  Map<String, dynamic>? _existingPatientData;
  bool _isInitializing = false;
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    NFCService.stopSession(); // Stop NFC session if active
    super.dispose();
  }

  // Start NFC card reading
  Future<void> _startNFCScanning() async {
    try {
      // Check if NFC is available
      bool isAvailable = await NFCService.isNFCAvailable();
      
      if (!isAvailable) {
        setState(() {
          _statusMessage = 'NFC is not available on this device';
          _error = true;
          _isScanning = false;
          _detailedErrorMessage = 'This device does not support NFC or NFC is disabled. Please enable NFC in device settings and try again.';
        });
        return;
      }
      
      setState(() {
        _isScanning = true;
        _error = false;
        _success = false;
        _cardSerialNumber = null;
        _detailedErrorMessage = null;
        _existingPatientData = null;
        _statusMessage = 'Place NFC card on the back of your device';
      });
      
      try {
        final result = await NFCService.readNFC();
        
        // Handle the case when result is null
        if (result == null) {
          setState(() {
            _statusMessage = 'No card detected or scan failed';
            _error = true;
            _isScanning = false;
            _detailedErrorMessage = 'Please try again and ensure the card is properly positioned on the back of your device.';
          });
          return;
        }
        
        // Debug output
        debugPrint('NFC Read Result: $result');
        
        // Extract serial number with priority order
        String? serialNumber;
        
        // First try to get dedicated card serial number field
        if (result.containsKey('cardSerialNumber') && result['cardSerialNumber'] != null) {
          serialNumber = result['cardSerialNumber'].toString();
        } 
        // Then try ID field
        else if (result.containsKey('id') && result['id'] != null) {
          serialNumber = result['id'].toString();
        }
        // Then try data field if it contains something
        else if (result.containsKey('data') && result['data'] != null) {
          serialNumber = result['data'].toString();
        }
        // If no usable data found, generate one based on tag discovery
        else {
          // Use a timestamp-based ID as fallback
          serialNumber = 'NFC-${DateTime.now().millisecondsSinceEpoch}';
          debugPrint('Generated fallback serial number: $serialNumber');
        }
        
        // Ensure serial number is not empty
        if (serialNumber.isEmpty) {
          serialNumber = 'NFC-${DateTime.now().millisecondsSinceEpoch}';
        }
        
        debugPrint('Final card serial number: $serialNumber');
        
        // Check if this card is already registered with enhanced security
        await _checkCardRegistration(serialNumber);
        
      } catch (e) {
        debugPrint('Error during NFC reading process: $e');
        setState(() {
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Error reading card';
          _detailedErrorMessage = e.toString();
        });
      }
    } catch (e) {
      debugPrint('Outer exception in _startNFCScanning: $e');
      setState(() {
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error initializing NFC';
        _detailedErrorMessage = e.toString();
      });
      
      // Make sure to stop the NFC session on error
      try {
        await NFCService.stopSession();
      } catch (stopError) {
        debugPrint('Error stopping NFC session: $stopError');
      }
    }
  }
  
  // 🔐 Enhanced card registration check with full security validation
  Future<void> _checkCardRegistration(String serialNumber) async {
    try {
      final databaseService = DatabaseService();
      final cardCheck = await databaseService.checkCardRegistration(serialNumber);
      
      if (cardCheck != null) {
        final status = cardCheck['registrationStatus'];
        final isRegistered = cardCheck['isRegistered'] == true;
        
        switch (status) {
          case 'LOCKED':
            // Card is permanently locked
            final lockInfo = cardCheck['lockInfo'];
            setState(() {
              _cardSerialNumber = serialNumber;
              _existingPatientData = cardCheck['patientData'];
              _success = false;
              _error = true;
              _isScanning = false;
              _statusMessage = 'Card is permanently locked';
              _detailedErrorMessage = 'This card is permanently locked to ${lockInfo['patientName']} since ${lockInfo['registrationDate']}';
            });
            _showLockedCardDialog(lockInfo);
            break;
            
          case 'CARD_DATA_FOUND':
          case 'DATABASE_FOUND':
            // Patient already registered
            final existingPatient = cardCheck['patientData'] as Map<String, dynamic>;
            setState(() {
              _cardSerialNumber = serialNumber;
              _existingPatientData = existingPatient;
              _success = true;
              _error = false;
              _isScanning = false;
              _statusMessage = 'Registered patient found';
              _detailedErrorMessage = null;
            });
            break;
            
          case 'TOKEN_AVAILABLE':
            // Card has valid registration token - ready for registration
            setState(() {
              _cardSerialNumber = serialNumber;
              _existingPatientData = null;
              _success = true;
              _error = false;
              _isScanning = false;
              _statusMessage = 'Card ready for registration';
              _detailedErrorMessage = 'Valid registration token found';
            });
            break;
            
          case 'BLANK_CARD':
            // Card needs initialization - but we'll offer auto-initialization
            setState(() {
              _cardSerialNumber = serialNumber;
              _existingPatientData = null;
              _success = false;
              _error = true;
              _isScanning = false;
              _statusMessage = 'Card needs initialization';
              _detailedErrorMessage = 'This card needs to be initialized with a registration token first';
            });
            break;
            
          default:
            // Unknown status
            setState(() {
              _cardSerialNumber = serialNumber;
              _existingPatientData = null;
              _success = false;
              _error = true;
              _isScanning = false;
              _statusMessage = 'Unknown card status';
              _detailedErrorMessage = cardCheck['message'] ?? 'Unable to determine card status';
            });
        }
      } else {
        // Null response - treat as blank card
        setState(() {
          _cardSerialNumber = serialNumber;
          _existingPatientData = null;
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Card needs initialization';
          _detailedErrorMessage = 'This appears to be a blank card that needs initialization';
        });
      }
    } catch (e) {
      debugPrint('Error checking card registration: $e');
      setState(() {
        _cardSerialNumber = serialNumber;
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error validating card';
        _detailedErrorMessage = 'Could not check card status: ${e.toString()}';
      });
    }
  }
  
  // Auto-initialize blank cards
  Future<void> _autoInitializeCard(String serialNumber) async {
    try {
      setState(() {
        _isInitializing = true;
        _statusMessage = 'Initializing card automatically...';
        _error = false;
      });
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Initializing Card'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Setting up this card for patient registration...'),
              SizedBox(height: 16),
              LinearProgressIndicator(),
              SizedBox(height: 8),
              Text(
                'Please keep the card on your device',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
      
      // Wait a moment for UI to update
      await Future.delayed(Duration(milliseconds: 500));
      
      // Initialize the card
      final databaseService = DatabaseService();
      final success = await databaseService.initializeBlankCard(serialNumber);
      
      // Close progress dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (success) {
        setState(() {
          _cardSerialNumber = serialNumber;
          _existingPatientData = null;
          _success = true;
          _error = false;
          _isInitializing = false;
          _statusMessage = 'Card initialized successfully!';
          _detailedErrorMessage = 'This card is now ready for patient registration';
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Card initialized successfully! Ready for patient registration.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Register Patient',
              textColor: Colors.white,
              onPressed: _proceedToRegistration,
            ),
          ),
        );
      } else {
        setState(() {
          _cardSerialNumber = serialNumber;
          _success = false;
          _error = true;
          _isInitializing = false;
          _statusMessage = 'Failed to initialize card';
          _detailedErrorMessage = 'Could not prepare card for registration. Please try again or use a different card.';
        });
        
        // Show retry dialog
        _showInitializationFailedDialog(serialNumber);
      }
    } catch (e) {
      // Close progress dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _cardSerialNumber = serialNumber;
        _success = false;
        _error = true;
        _isInitializing = false;
        _statusMessage = 'Error initializing card';
        _detailedErrorMessage = 'Initialization failed: ${e.toString()}';
      });
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Initialization Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to initialize the card:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  e.toString(),
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _autoInitializeCard(serialNumber); // Retry
              },
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }
  }
  
  // Show dialog when initialization fails
  void _showInitializationFailedDialog(String serialNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Initialization Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.credit_card, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text('Could not initialize the card automatically.'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Possible causes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Card is damaged or incompatible'),
                  Text('• NFC connection was interrupted'),
                  Text('• Card has corrupted data'),
                  Text('• Card is not NFC-compatible'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cardSerialNumber = null;
                _existingPatientData = null;
                _success = false;
                _error = false;
                _statusMessage = 'Tap "Scan Card" to begin';
              });
            },
            child: Text('Use Different Card'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _autoInitializeCard(serialNumber); // Retry
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Retry Initialization'),
          ),
        ],
      ),
    );
  }
  
  // Show dialog for locked cards
  void _showLockedCardDialog(Map<String, dynamic> lockInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Card Permanently Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                children: [
                  Icon(Icons.security, color: Colors.red, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '🔒 SECURITY LOCK ACTIVE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('This NFC card is permanently locked to:'),
                  SizedBox(height: 8),
                  Text(
                    lockInfo['patientName'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('Patient ID: ${lockInfo['patientId']}'),
                  Text('Locked on: ${lockInfo['registrationDate']}'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚠️ This card cannot be used for new patient registrations. Each card can only be registered to one patient for security purposes.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      textAlign: TextAlign.center,
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
              setState(() {
                _cardSerialNumber = null;
                _existingPatientData = null;
                _success = false;
                _error = false;
                _statusMessage = 'Tap "Scan Card" to begin';
              });
            },
            child: Text('Use Different Card'),
          ),
        ],
      ),
    );
  }
  
  // Cancel scanning
  void _cancelScanning() async {
    try {
      await NFCService.stopSession();
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scanning cancelled';
      });
    } catch (e) {
      debugPrint('Error cancelling scan: $e');
    }
  }
  
  // Navigate to patient registration with the card serial number
  void _proceedToRegistration() {
    if (_cardSerialNumber == null || _cardSerialNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid card serial number. Please scan the card again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Double-check that this is not an already registered card
    if (_existingPatientData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This card is already registered to ${_existingPatientData!['name']}. Use patient actions instead.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    debugPrint('Proceeding to registration with serial: $_cardSerialNumber');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientRegistrationScreen(
          cardSerialNumber: _cardSerialNumber!,
        ),
      ),
    );
  }
  
  // View existing patient details
  void _viewExistingPatient() {
    if (_existingPatientData != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person, color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text('Registered Patient'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This card is already registered to:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                SizedBox(height: 16),
                _buildPatientInfoRow('Name', _existingPatientData!['name'] ?? 'Unknown'),
                _buildPatientInfoRow('Patient ID', _existingPatientData!['patientId'] ?? 'Unknown'),
                _buildPatientInfoRow('Date of Birth', _existingPatientData!['dateOfBirth'] ?? 'Unknown'),
                _buildPatientInfoRow('Phone', _existingPatientData!['phone'] ?? 'Unknown'),
                _buildPatientInfoRow('Email', _existingPatientData!['email'] ?? 'Unknown'),
                
                SizedBox(height: 16),
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
                          'Each NFC card can only be registered to one patient. Please use a different card for new registrations.',
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _cardSerialNumber = null;
                  _existingPatientData = null;
                  _success = false;
                  _error = false;
                  _statusMessage = 'Tap "Scan Card" to begin';
                });
              },
              child: Text('Scan Different Card'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPatientInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Card Registration', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _cardSerialNumber = null;
                _existingPatientData = null;
                _success = false;
                _error = false;
                _isScanning = false;
                _isInitializing = false;
                _statusMessage = 'Tap "Scan Card" to begin';
                _detailedErrorMessage = null;
              });
            },
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SingleChildScrollView( // 🔧 SCROLLABLE CONTENT
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Instructions
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '🔒 Enhanced Security System',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Scan an NFC card to register a new patient or view existing patient information. Each card is cryptographically secured and can only be registered to one patient.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 40),
                
                // NFC animation or status icon
                if (_isScanning || _isInitializing)
                  ScaleTransition(
                    scale: _animation,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isInitializing ? Icons.settings : Icons.contactless,
                        size: 100,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                else if (_success)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green,
                    ),
                  )
                else if (_error)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: (_existingPatientData != null ? Colors.blue : Colors.orange).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _existingPatientData != null ? Icons.person : Icons.credit_card,
                      size: 80,
                      color: _existingPatientData != null ? Colors.blue : Colors.orange,
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contactless,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                
                SizedBox(height: 24),
                
                // Status message
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _error
                        ? (_existingPatientData != null ? Colors.blue : Colors.red)
                        : _success
                            ? Colors.green
                            : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Detailed error message if available
                if (_detailedErrorMessage != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_error && _existingPatientData == null ? Colors.red : Colors.blue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (_error && _existingPatientData == null ? Colors.red : Colors.blue).withOpacity(0.3)),
                    ),
                    child: Text(
                      _detailedErrorMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        color: _error && _existingPatientData == null ? Colors.red[700] : Colors.blue[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                SizedBox(height: 24),
                
                // Display card info when successfully scanned
                if (_cardSerialNumber != null && (_success || _error)) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (_existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _existingPatientData != null 
                                  ? Icons.person 
                                  : _success 
                                      ? Icons.check_circle 
                                      : Icons.credit_card,
                              color: _existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _existingPatientData != null 
                                  ? 'Patient Found' 
                                  : _success 
                                      ? 'Card Ready for Registration'
                                      : 'Card Needs Initialization',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: (_existingPatientData != null ? Colors.blue : _success ? Colors.green : Colors.orange)[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        
                        if (_existingPatientData != null) ...[
                          // Show patient info
                          Text(
                            'Patient: ${_existingPatientData!['name'] ?? 'Unknown'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'ID: ${_existingPatientData!['patientId'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_existingPatientData!['phone'] != null) ...[
                            SizedBox(height: 4),
                            Text(
                              'Phone: ${_existingPatientData!['phone']}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ] else ...[
                          // Show card serial for new registration or initialization
                          Text(
                            'Card Serial Number:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          SelectableText(
                            _cardSerialNumber!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 40),
                
                // Action buttons
                if (_isScanning || _isInitializing)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        NFCService.stopSession();
                        setState(() {
                          _isScanning = false;
                          _isInitializing = false;
                          _statusMessage = 'Tap "Scan Card" to begin';
                        });
                      },
                      icon: Icon(Icons.cancel),
                      label: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else if (_success && _cardSerialNumber != null && _existingPatientData != null)
                  // Existing patient actions
                  Column(
                    children: [
                      // Check if patient needs doctor assignment
                      if (_existingPatientData!['currentAppointment'] == null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AssignDoctorScreen(
                                    patientId: _existingPatientData!['patientId'],
                                    patientName: _existingPatientData!['name'],
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.assignment_ind),
                            label: Text('Assign Doctor & Room'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                      ] else
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Patient already assigned to doctor',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientDetailsScreen(
                                      patient: _existingPatientData!,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.visibility),
                              label: Text('View Details'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _cardSerialNumber = null;
                                  _existingPatientData = null;
                                  _success = false;
                                  _error = false;
                                  _statusMessage = 'Tap "Scan Card" to begin';
                                });
                              },
                              icon: Icon(Icons.refresh),
                              label: Text('Scan Different'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else if (_error && _cardSerialNumber != null && _existingPatientData == null)
                  // Blank card detected - show initialization options
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.credit_card, color: Colors.orange, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'NEW Card Detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'This card needs to be initialized for patient registration',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      // Initialize button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _autoInitializeCard(_cardSerialNumber!),
                          icon: Icon(Icons.settings),
                          label: Text('Initialize Card Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Use different card button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _cardSerialNumber = null;
                              _existingPatientData = null;
                              _success = false;
                              _error = false;
                              _statusMessage = 'Tap "Scan Card" to begin';
                            });
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Use Different Card'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_success && _cardSerialNumber != null && _existingPatientData == null)
                  // Card ready for registration
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _proceedToRegistration,
                          icon: Icon(Icons.person_add),
                          label: Text('Register New Patient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _cardSerialNumber = null;
                              _existingPatientData = null;
                              _success = false;
                              _statusMessage = 'Tap "Scan Card" to begin';
                            });
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Scan Different Card'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Default scan button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startNFCScanning,
                      icon: Icon(Icons.contactless),
                      label: Text('Scan NFC Card'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                
                // Help text
                if (!_isScanning && !_isInitializing) ...[
                  SizedBox(height: 32),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.grey[600], size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Place the NFC card flat against the back of your device\n'
                          '• Keep the card in contact until scanning completes\n'
                          '• New cards will be automatically initialized\n'
                          '• Each card can only be registered to one patient\n'
                          '• Ensure NFC is enabled in your device settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Add bottom padding for scrolling
                SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}