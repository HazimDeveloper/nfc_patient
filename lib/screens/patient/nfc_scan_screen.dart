import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/nfc_service.dart';
import 'package:nfc_patient_registration/services/database_service.dart';

enum NFCAction {
  read,
  write,
  format,
}

class NFCScanScreen extends StatefulWidget {
  final NFCAction action;
  final Map<String, dynamic>? dataToWrite;
  final Function(Map<String, dynamic>)? onDataRead;
  final Function(bool)? onWriteComplete;

  const NFCScanScreen({
    Key? key,
    required this.action,
    this.dataToWrite,
    this.onDataRead,
    this.onWriteComplete,
  }) : super(key: key);

  @override
  _NFCScanScreenState createState() => _NFCScanScreenState();
}

class _NFCScanScreenState extends State<NFCScanScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = '';
  bool _success = false;
  bool _error = false;
  String? _detailedErrorMessage;
  Map<String, dynamic>? _scannedData;
  
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
    
    // Start NFC operation
    _startNFCOperation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    NFCService.stopSession(); // Make sure to stop any active session
    super.dispose();
  }

  // Start NFC operation based on action type
  Future<void> _startNFCOperation() async {
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
        _scannedData = null;
        _detailedErrorMessage = null;
        
        switch (widget.action) {
          case NFCAction.read:
            _statusMessage = 'Place NFC card on the back of your device';
            break;
          case NFCAction.write:
            _statusMessage = 'Place NFC card on the back of your device to write data';
            break;
          case NFCAction.format:
            _statusMessage = 'Place NFC card on the back of your device to format';
            break;
        }
      });
      
      switch (widget.action) {
        case NFCAction.read:
          _readNFC();
          break;
        case NFCAction.write:
          if (widget.dataToWrite != null) {
            _writeNFC(widget.dataToWrite!);
          } else {
            setState(() {
              _statusMessage = 'No data provided to write';
              _error = true;
              _isScanning = false;
            });
          }
          break;
        case NFCAction.format:
          _formatNFC();
          break;
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _detailedErrorMessage = e.toString();
        _error = true;
        _isScanning = false;
      });
    }
  }
  
  // Read NFC card
  Future<void> _readNFC() async {
    try {
      final result = await NFCService.readNFC();
      
      if (result != null) {
        setState(() {
          _scannedData = result;
          _success = true;
          _error = false;
          _isScanning = false;
          _statusMessage = 'Card read successfully';
        });
        
        // Call onDataRead callback if provided
        if (widget.onDataRead != null) {
          widget.onDataRead!(result);
        }
        
        // If patientId is present, fetch patient data
        if (result.containsKey('patientId')) {
          _fetchPatientData(result['patientId']);
        }
      } else {
        setState(() {
          _success = false;
          _error = true;
          _isScanning = false;
          _statusMessage = 'Failed to read card data';
        });
      }
    } catch (e) {
      setState(() {
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error reading card';
        _detailedErrorMessage = e.toString();
      });
    }
  }
  
  // Write data to NFC card
  Future<void> _writeNFC(Map<String, dynamic> data) async {
    try {
      final success = await NFCService.writeNFC(data);
      
      setState(() {
        _success = success;
        _error = !success;
        _isScanning = false;
        _statusMessage = success 
            ? 'Data written successfully' 
            : 'Failed to write data to card';
      });
      
      // Call onWriteComplete callback if provided
      if (widget.onWriteComplete != null) {
        widget.onWriteComplete!(success);
      }
    } catch (e) {
      setState(() {
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error writing to card';
        _detailedErrorMessage = e.toString();
      });
      
      // Call onWriteComplete callback with failure
      if (widget.onWriteComplete != null) {
        widget.onWriteComplete!(false);
      }
    }
  }
  
  // Format NFC card
  Future<void> _formatNFC() async {
    try {
      final success = await NFCService.formatTag();
      
      setState(() {
        _success = success;
        _error = !success;
        _isScanning = false;
        _statusMessage = success 
            ? 'Card formatted successfully' 
            : 'Failed to format card';
      });
      
      // Call onWriteComplete callback if provided
      if (widget.onWriteComplete != null) {
        widget.onWriteComplete!(success);
      }
    } catch (e) {
      setState(() {
        _success = false;
        _error = true;
        _isScanning = false;
        _statusMessage = 'Error formatting card';
        _detailedErrorMessage = e.toString();
      });
      
      // Call onWriteComplete callback with failure
      if (widget.onWriteComplete != null) {
        widget.onWriteComplete!(false);
      }
    }
  }
  
  // Fetch patient data from database
  Future<void> _fetchPatientData(String patientId) async {
    try {
      DatabaseService databaseService = DatabaseService();
      Map<String, dynamic>? patientData = await databaseService.getPatientById(patientId);
      
      if (patientData != null) {
        setState(() {
          _scannedData = {
            ..._scannedData!,
            ...patientData,
          };
        });
        
        // Call onDataRead callback with updated data
        if (widget.onDataRead != null) {
          widget.onDataRead!(_scannedData!);
        }
      }
    } catch (e) {
      print('Error fetching patient data: ${e.toString()}');
    }
  }
  
  // Reset and try again
  void _resetAndTryAgain() {
    setState(() {
      _isScanning = false;
      _error = false;
      _success = false;
      _scannedData = null;
      _statusMessage = '';
      _detailedErrorMessage = null;
    });
    
    _startNFCOperation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.action == NFCAction.read
              ? 'Scan Patient Card'
              : widget.action == NFCAction.write
                  ? 'Write to Card'
                  : 'Format Card',
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // NFC animation
              if (_isScanning)
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
                      Icons.contactless,
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
              
              SizedBox(height: 24),
              
              // Display scanned data if available
              if (_scannedData != null && _success) ...[
                Text(
                  'Card Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView(
                      children: _scannedData!.entries.map((entry) {
                        // Skip large or complex values
                        if (entry.value is Map || entry.value is List) {
                          return SizedBox.shrink();
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.key}:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.value}',
                                  style: TextStyle(
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ] else if (!_isScanning) 
                // Fixed: Using Spacer() instead of Expanded
                Spacer(),
              
              // Action buttons
              if (_success || _error)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _resetAndTryAgain,
                        icon: Icon(Icons.refresh),
                        label: Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 16),
                      
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Done'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
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
}