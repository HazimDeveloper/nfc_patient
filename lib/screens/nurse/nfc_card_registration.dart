import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/nfc_service.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_registration.dart';

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
        });
        return;
      }
      
      setState(() {
        _isScanning = true;
        _error = false;
        _success = false;
        _cardSerialNumber = null;
        _detailedErrorMessage = null;
        _statusMessage = 'Place NFC card on the back of your device';
      });
      
      // Use async/await correctly and implement proper error handling
      try {
        final result = await NFCService.readNFC();
        
        // Handle the case when result is null
        if (result == null) {
          setState(() {
            _statusMessage = 'No card detected';
            _error = true;
            _isScanning = false;
          });
          return;
        }
        
        // Debug output
        debugPrint('NFC Read Result: $result');
        
        // Check for error in the result
        if (result.containsKey('error')) {
          setState(() {
            _statusMessage = 'Failed to read card';
            _detailedErrorMessage = result['error'];
            _error = true;
            _isScanning = false;
          });
          return;
        }
        
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
        // If no usable data found
        else {
          // Use a timestamp as fallback
          serialNumber = 'CARD-${DateTime.now().millisecondsSinceEpoch}';
        }
        
        setState(() {
          _cardSerialNumber = serialNumber;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Card scanned successfully';
        });
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
        _statusMessage = 'Error reading card';
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
    if (_cardSerialNumber != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientRegistrationScreen(cardSerialNumber: _cardSerialNumber!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Card Registration'),
        centerTitle: true,
      ),
      body: Center(
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
                      'Before registering a new patient, please scan their NFC card to get the card serial number.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 40),
              
              // NFC animation
              if (_isScanning)
                ScaleTransition(
                  scale: _animation,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contactless,
                      size: 100,
                      color: Colors.teal,
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
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error,
                    size: 80,
                    color: Colors.red,
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
                      ? Colors.red
                      : _success
                          ? Colors.green
                          : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Detailed error message if available
              if (_detailedErrorMessage != null && _error) ...[
                SizedBox(height: 8),
                Text(
                  _detailedErrorMessage!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              SizedBox(height: 16),
              
              // Display card serial if available
              if (_cardSerialNumber != null && _success) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Card Serial Number:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      SelectableText(
                        _cardSerialNumber!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 40),
              
              // Action buttons
              if (_isScanning)
                ElevatedButton(
                  onPressed: _cancelScanning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Cancel Scanning'),
                )
              else if (_success && _cardSerialNumber != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _startNFCScanning,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text('Scan Again'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _proceedToRegistration,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text('Proceed to Registration'),
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: _startNFCScanning,
                  icon: Icon(Icons.contactless),
                  label: Text('Scan Card'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}