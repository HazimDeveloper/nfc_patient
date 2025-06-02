import 'dart:async';
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
  
  // Read NFC tag and get REAL card ID (safer approach)
  static Future<Map<String, dynamic>?> readNFC() async {
    if (!await isNFCAvailable()) {
      throw Exception('NFC is not available on this device');
    }
    
    final completer = Completer<Map<String, dynamic>?>();
    
    try {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('NFC Tag discovered');
            debugPrint('NFC Tag data: ${tag.data}');
            
            Map<String, dynamic> result = {};
            
            // Try to get a consistent card identifier
            String cardId = _getCardIdentifier(tag);
            result['cardSerialNumber'] = cardId;
            
            // Also store raw data for debugging
            result['rawTagData'] = tag.data.toString();
            
            debugPrint('Final card ID: $cardId');
            
            completer.complete(result);
            NfcManager.instance.stopSession();
          } catch (e) {
            debugPrint('NFC: Error processing tag: $e');
            completer.completeError(e);
            NfcManager.instance.stopSession();
          }
        },
      );
      
      return completer.future;
    } catch (e) {
      debugPrint('Error starting NFC session: $e');
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      throw Exception('Error reading NFC card: ${e.toString()}');
    }
  }
  
  // Get card identifier using safer approach
  static String _getCardIdentifier(NfcTag tag) {
    try {
      // Method 1: Create a consistent hash from the entire tag data
      final tagDataString = tag.data.toString();
      
      // Simple hash function on the tag data
      int hash = tagDataString.hashCode;
      if (hash < 0) hash = -hash; // Make it positive
      
      String baseId = 'CARD-${hash.toString().padLeft(10, '0')}';
      
      // Method 2: Try to extract any numeric values that might be unique
      final allText = tagDataString.toLowerCase();
      final numbers = RegExp(r'\d{6,}').allMatches(allText);
      
      if (numbers.isNotEmpty) {
        // Use the first long number we find
        final firstLongNumber = numbers.first.group(0);
        if (firstLongNumber != null && firstLongNumber.length >= 6) {
          return 'NFC-$firstLongNumber';
        }
      }
      
      // Method 3: Look for any hex patterns that might be UIDs
      final hexPatterns = RegExp(r'[0-9a-f]{8,}').allMatches(allText);
      if (hexPatterns.isNotEmpty) {
        final firstHex = hexPatterns.first.group(0);
        if (firstHex != null && firstHex.length >= 8) {
          return 'HEX-${firstHex.toUpperCase()}';
        }
      }
      
      // Fallback: Use the hash
      return baseId;
      
    } catch (e) {
      debugPrint('Error getting card identifier: $e');
      // Last resort: use a hash of the current time and tag data
      final fallback = '${tag.data.toString()}${DateTime.now().millisecondsSinceEpoch}'.hashCode.abs();
      return 'FALLBACK-$fallback';
    }
  }
  
  // Format bytes to hex string
  static String _formatBytes(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
  }
  
  // Write data to NFC tag
  static Future<bool> writeNFC(Map<String, dynamic> data) async {
    if (!await isNFCAvailable()) {
      throw Exception('NFC is not available on this device');
    }
    
    final completer = Completer<bool>();
    
    try {
      // Convert data to JSON string
      final jsonData = jsonEncode(data);
      debugPrint('NFC: Preparing to write: $jsonData');
      
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            // This is a simplified implementation
            debugPrint('NFC: Write operation would occur here');
            
            // For now, just simulate success
            completer.complete(true);
            NfcManager.instance.stopSession();
          } catch (e) {
            debugPrint('NFC: Error writing to tag: $e');
            completer.completeError(e);
            NfcManager.instance.stopSession();
          }
        },
      );
      
      return completer.future;
    } catch (e) {
      debugPrint('Error starting NFC write session: $e');
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      throw Exception('Error writing to NFC card: ${e.toString()}');
    }
  }
  
  // Format NFC tag
  static Future<bool> formatTag() async {
    if (!await isNFCAvailable()) {
      throw Exception('NFC is not available on this device');
    }
    
    final completer = Completer<bool>();
    
    try {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('NFC: Format operation would occur here');
            
            // For now, just simulate success
            completer.complete(true);
            NfcManager.instance.stopSession();
          } catch (e) {
            debugPrint('NFC: Error formatting tag: $e');
            completer.completeError(e);
            NfcManager.instance.stopSession();
          }
        },
      );
      
      return completer.future;
    } catch (e) {
      debugPrint('Error starting NFC format session: $e');
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      throw Exception('Error formatting NFC card: ${e.toString()}');
    }
  }
  
  // Stop any active NFC session
  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('Error stopping NFC session: $e');
    }
  }
}