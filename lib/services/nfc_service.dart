import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NFCService {
  // Check if NFC is available on the device
  static Future<bool> isNFCAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('Error checking NFC availability: $e');
      return false;
    }
  }
  
  // Start NFC session for reading with improved error handling
  static Future<Map<String, dynamic>?> readNFC() async {
    if (!await isNFCAvailable()) {
      throw Exception('NFC is not available on this device');
    }
    
    Map<String, dynamic>? result;
    
    try {
      // Start session
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('NFC Tag discovered: ${tag.data}');
            
            // Try to get NDEF message from the tag if available
            final ndefTag = Ndef.from(tag);
            
            if (ndefTag != null) {
              debugPrint('NFC: NDEF tag found');
              
              // Try to get cached NDEF message
              if (ndefTag.cachedMessage != null) {
                debugPrint('NFC: NDEF cached message found');
                
                // Try to read from the first record
                try {
                  final record = ndefTag.cachedMessage!.records.first;
                  
                  if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown && 
                      record.payload.isNotEmpty) {
                    // Skip first byte (indicates text encoding)
                    final payload = String.fromCharCodes(record.payload.skip(1));
                    debugPrint('NFC: Raw payload: $payload');
                    
                    // Try to parse as JSON
                    try {
                      result = jsonDecode(payload);
                      debugPrint('NFC: JSON parsed successfully');
                    } catch (e) {
                      debugPrint('NFC: Not valid JSON, using as plain text');
                      // If not JSON, return as plain text
                      result = {'data': payload};
                    }
                  } else {
                    debugPrint('NFC: NDEF record found but in unsupported format');
                    
                    // Try to extract raw payload anyway
                    if (record.payload.isNotEmpty) {
                      final rawPayload = record.payload;
                      final payloadString = String.fromCharCodes(rawPayload);
                      result = {'data': payloadString, 'raw': true};
                    }
                  }
                } catch (e) {
                  debugPrint('NFC: Error processing NDEF record: $e');
                }
              } else {
                debugPrint('NFC: No cached NDEF message found');
              }
              
              // If we still don't have a result, try to read directly
              if (result == null) {
                try {
                  final ndefMessage = await ndefTag.read();
                  debugPrint('NFC: Read NDEF message directly');
                  
                  if (ndefMessage.records.isNotEmpty) {
                    final record = ndefMessage.records.first;
                    
                    if (record.payload.isNotEmpty) {
                      // Skip first byte for text records
                      final payload = record.typeNameFormat == NdefTypeNameFormat.nfcWellknown 
                          ? String.fromCharCodes(record.payload.skip(1))
                          : String.fromCharCodes(record.payload);
                          
                      debugPrint('NFC: Direct read payload: $payload');
                      
                      // Try to parse as JSON
                      try {
                        result = jsonDecode(payload);
                      } catch (e) {
                        // If not JSON, return as plain text
                        result = {'data': payload};
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('NFC: Error reading NDEF message directly: $e');
                }
              }
            } else {
              debugPrint('NFC: Not an NDEF tag, trying to get tag ID');
            }
            
            // If we still don't have a result, try to get the card ID/serial number
            if (result == null) {
              // Comprehensive approach to get card ID from various tag technologies
              Map<String, dynamic> tagData = tag.data;
              String? idString;
              
              // Check for Mifare technology first (most common)
              if (tagData.containsKey('mifare')) {
                final mifare = tagData['mifare'];
                if (mifare != null && mifare.containsKey('identifier')) {
                  final identifier = mifare['identifier'];
                  if (identifier != null) {
                    idString = _formatIdentifier(identifier);
                    debugPrint('NFC: Found Mifare identifier: $idString');
                  }
                }
              }
              
              // If no Mifare ID, check other technologies systematically
              if (idString == null) {
                // List of common technologies that might contain an identifier
                final techsToCheck = [
                  'iso7816', 'iso15693', 'iso14443', 'nfcA', 'nfcB', 'nfcF', 'nfcV', 'mifareClassic', 'mifareUltralight'
                ];
                
                // Try each technology
                for (var tech in techsToCheck) {
                  if (tagData.containsKey(tech)) {
                    final techData = tagData[tech];
                    if (techData != null && techData is Map) {
                      // Common identifier keys
                      final idKeys = ['identifier', 'id', 'uid', 'serialNumber'];
                      
                      for (var key in idKeys) {
                        if (techData.containsKey(key) && techData[key] != null) {
                          idString = _formatIdentifier(techData[key]);
                          debugPrint('NFC: Found identifier in $tech using key $key: $idString');
                          break;
                        }
                      }
                      
                      if (idString != null) break;
                    }
                  }
                }
              }
              
              // If we found an ID
              if (idString != null) {
                result = {'id': idString, 'cardSerialNumber': idString};
              } else {
                // If no ID found, return available technologies for debugging
                debugPrint('NFC: Unable to find card serial number in any technology');
                result = {
                  'error': 'Could not find card serial number',
                  'availableTech': tagData.keys.toList().join(', ')
                };
              }
            }
            
            // If we still have no result, create a fallback one
            if (result == null) {
              debugPrint('NFC: Creating fallback serial number');
              // Generate a unique random ID as last resort
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              result = {
                'id': 'generated-$timestamp',
                'cardSerialNumber': 'generated-$timestamp',
                'generated': true
              };
            }
            
          } catch (e) {
            debugPrint('NFC: Error processing tag: $e');
            result = {'error': 'Error processing tag: $e'};
          } finally {
            // Stop session regardless of result
            try {
              await NfcManager.instance.stopSession();
              debugPrint('NFC: Session stopped');
            } catch (e) {
              debugPrint('NFC: Error stopping session: $e');
            }
          }
        },
      );
      
      // Return final result (might be null if no tag was scanned)
      return result;
    } catch (e) {
      debugPrint('Error reading NFC: $e');
      try {
        await NfcManager.instance.stopSession();
      } catch (sessionError) {
        debugPrint('Error stopping NFC session: $sessionError');
      }
      throw Exception('Error reading NFC card: ${e.toString()}');
    }
  }
  
  // Helper method to format identifier byte array to string
  static String _formatIdentifier(dynamic identifier) {
    if (identifier is Uint8List || identifier is List<int>) {
      return identifier.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
    } else if (identifier is String) {
      return identifier;
    } else {
      return identifier.toString();
    }
  }
  
  // Write data to NFC tag with improved error handling
  static Future<bool> writeNFC(Map<String, dynamic> data) async {
    if (!await isNFCAvailable()) {
      throw Exception('NFC is not available on this device');
    }
    
    bool success = false;
    
    try {
      // Convert data to JSON string
      final jsonData = jsonEncode(data);
      debugPrint('NFC: Preparing to write: $jsonData');
      
      // Start session
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('NFC: Tag discovered for writing');
            final ndef = Ndef.from(tag);
            
            if (ndef == null) {
              debugPrint('NFC: Tag is not NDEF compatible');
              throw Exception('Tag is not NDEF compatible');
            }
            
            if (!ndef.isWritable) {
              debugPrint('NFC: Tag is not writable');
              throw Exception('Tag is not writable');
            }
            
            // Check if we have enough space
            final maxSize = ndef.maxSize;
            final messageSize = jsonData.length + 7; // Approximate NDEF overhead
            
            if (maxSize != null && messageSize > maxSize) {
              debugPrint('NFC: Data too large for tag (${messageSize} > ${maxSize} bytes)');
              throw Exception('Data too large for tag (${messageSize} > ${maxSize} bytes)');
            }
            
            // Create NDEF message
            final message = NdefMessage([
              NdefRecord.createText(jsonData),
            ]);
            
            // Write to tag
            debugPrint('NFC: Writing to tag...');
            await ndef.write(message);
            debugPrint('NFC: Write successful');
            
            success = true;
          } catch (e) {
            debugPrint('NFC: Error writing to tag: $e');
            throw Exception('Error writing to tag: $e');
          } finally {
            // Stop session regardless of result
            try {
              await NfcManager.instance.stopSession();
              debugPrint('NFC: Write session stopped');
            } catch (e) {
              debugPrint('NFC: Error stopping write session: $e');
            }
          }
        },
      );
      
      return success;
    } catch (e) {
      debugPrint('Error writing NFC: $e');
      try {
        await NfcManager.instance.stopSession();
      } catch (sessionError) {
        debugPrint('Error stopping NFC session after write error: $sessionError');
      }
      throw Exception('Error writing to NFC card: ${e.toString()}');
    }
  }
  
  // Format NFC tag with improved error handling
  static Future<bool> formatTag() async {
    if (!await isNFCAvailable()) {
      throw Exception('NFC is not available on this device');
    }
    
    bool success = false;
    
    try {
      debugPrint('NFC: Starting format session');
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('NFC: Tag discovered for formatting');
            final ndef = Ndef.from(tag);
            
            if (ndef == null) {
              debugPrint('NFC: Tag is not NDEF compatible');
              throw Exception('Tag is not NDEF compatible');
            }
            
            if (!ndef.isWritable) {
              debugPrint('NFC: Tag is not writable');
              throw Exception('Tag is not writable');
            }
            
            // Format tag with empty message
            debugPrint('NFC: Formatting tag...');
            final message = NdefMessage([
              NdefRecord.createText(''),
            ]);
            
            await ndef.write(message);
            debugPrint('NFC: Format successful');
            
            success = true;
          } catch (e) {
            debugPrint('NFC: Error formatting tag: $e');
            throw Exception('Error formatting tag: $e');
          } finally {
            // Stop session regardless of result
            try {
              await NfcManager.instance.stopSession();
              debugPrint('NFC: Format session stopped');
            } catch (e) {
              debugPrint('NFC: Error stopping format session: $e');
            }
          }
        },
      );
      
      return success;
    } catch (e) {
      debugPrint('Error formatting NFC: $e');
      try {
        await NfcManager.instance.stopSession();
      } catch (sessionError) {
        debugPrint('Error stopping NFC session after format error: $sessionError');
      }
      throw Exception('Error formatting NFC card: ${e.toString()}');
    }
  }
  
  // Stop any active NFC session
  static Future<void> stopSession() async {
    try {
      debugPrint('NFC: Manually stopping session');
      await NfcManager.instance.stopSession();
      debugPrint('NFC: Session stopped successfully');
      return;
    } catch (e) {
      debugPrint('Error stopping NFC session: $e');
      throw Exception('Error stopping NFC session: ${e.toString()}');
    }
  }
}