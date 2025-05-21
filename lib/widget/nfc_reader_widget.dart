import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/nfc_service.dart';

class NFCReaderWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onTagRead;
  final Function()? onCancel;
  final String? instruction;

  const NFCReaderWidget({
    Key? key,
    required this.onTagRead,
    this.onCancel,
    this.instruction,
  }) : super(key: key);

  @override
  _NFCReaderWidgetState createState() => _NFCReaderWidgetState();
}

class _NFCReaderWidgetState extends State<NFCReaderWidget> with SingleTickerProviderStateMixin {
  bool _isScanning = true;
  String _statusMessage = 'Scanning for NFC tag...';
  bool _error = false;
  String? _errorMessage;
  
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
    
    // Start NFC scanning
    _startNfcScan();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    NFCService.stopSession();
    super.dispose();
  }
  
  // Start NFC scanning
  Future<void> _startNfcScan() async {
    try {
      // Check if NFC is available
      final isAvailable = await NFCService.isNFCAvailable();
      
      if (!isAvailable) {
        setState(() {
          _isScanning = false;
          _error = true;
          _statusMessage = 'NFC is not available on this device';
        });
        return;
      }
      
      // Read NFC tag
      final tagData = await NFCService.readNFC();
      
      if (tagData != null) {
        // Call the callback and pass the tag data
        widget.onTagRead(tagData);
      } else {
        setState(() {
          _isScanning = false;
          _error = true;
          _statusMessage = 'Failed to read NFC tag';
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _error = true;
        _statusMessage = 'Error reading NFC tag';
        _errorMessage = e.toString();
      });
    }
  }
  
  // Cancel scanning
  void _cancelScanning() {
    NFCService.stopSession();
    if (widget.onCancel != null) {
      widget.onCancel!();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // NFC icon with animation
          if (_isScanning)
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.contactless,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            )
          else if (_error)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error,
                size: 50,
                color: Colors.red,
              ),
            ),
          
          SizedBox(height: 24),
          
          // Instruction text
          Text(
            widget.instruction ?? 'Place the NFC card on the back of your device',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          SizedBox(height: 16),
          
          // Status message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _error ? Colors.red : Colors.grey[600],
            ),
          ),
          
          // Error message if any
          if (_errorMessage != null && _error) ...[
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
              ),
            ),
          ],
          
          SizedBox(height: 24),
          
          // Cancel button
          TextButton.icon(
            onPressed: _cancelScanning,
            icon: Icon(Icons.cancel),
            label: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}