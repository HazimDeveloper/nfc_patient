import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:nfc_patient_registration/services/nfc_service.dart';

class CardSecurityService {
  static const String HOSPITAL_SECRET = 'NFC_PATIENT_HOSPITAL_SECRET_2024_V1';
  static const String HOSPITAL_ID = 'NFC_HOSPITAL_001';
  
  // Generate cryptographic signature for patient-card binding
  static String generatePatientCardSignature({
    required String patientId,
    required String name,
    required String email,
    required String cardSerialNumber,
  }) {
    final bindingData = {
      'patientId': patientId,
      'name': name.toUpperCase().trim(),
      'email': email.toLowerCase().trim(),
      'cardSerial': cardSerialNumber,
      'hospitalSecret': HOSPITAL_SECRET,
      'hospitalId': HOSPITAL_ID,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    final jsonData = jsonEncode(bindingData);
    final bytes = utf8.encode(jsonData);
    final signature = sha256.convert(bytes).toString();
    
    return signature.substring(0, 32); // Use first 32 chars for card storage
  }
  
  // Verify cryptographic binding between card and patient
  static bool verifyCardBinding(
    Map<String, dynamic> cardData,
    Map<String, dynamic> patientData,
  ) {
    try {
      if (!cardData.containsKey('SECURITY_SIGNATURE')) return false;
      
      final cardSignature = cardData['SECURITY_SIGNATURE'];
      
      final expectedSignature = generatePatientCardSignature(
        patientId: patientData['patientId'],
        name: patientData['name'],
        email: patientData['email'],
        cardSerialNumber: patientData['cardSerialNumber'],
      );
      
      return cardSignature == expectedSignature;
    } catch (e) {
      print('Error verifying card binding: $e');
      return false;
    }
  }
  
  // Generate registration token for new cards
  static Map<String, dynamic> generateRegistrationToken(String cardSerialNumber) {
    final tokenId = _generateUniqueToken();
    
    return {
      'REGISTRATION_TOKEN': {
        'cardId': cardSerialNumber,
        'tokenId': tokenId,
        'generatedAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
        'status': 'ACTIVE',
        'maxUses': 1,
        'usedCount': 0,
        'hospitalId': HOSPITAL_ID,
        'version': '1.0',
      }
    };
  }
  
  // Check if registration token is valid and available
  static Future<Map<String, dynamic>?> validateRegistrationToken(String cardSerialNumber) async {
    try {
      final cardData = await NFCService.readNFC();
      
      if (cardData == null || !cardData.containsKey('REGISTRATION_TOKEN')) {
        return null;
      }
      
      final tokenInfo = cardData['REGISTRATION_TOKEN'];
      
      // Validate token data
      if (tokenInfo['cardId'] != cardSerialNumber) {
        return {'valid': false, 'reason': 'Card ID mismatch'};
      }
      
      // Check expiration
      final expiresAt = DateTime.parse(tokenInfo['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) {
        return {'valid': false, 'reason': 'Token expired'};
      }
      
      // Check usage count
      final usedCount = tokenInfo['usedCount'] ?? 0;
      final maxUses = tokenInfo['maxUses'] ?? 1;
      if (usedCount >= maxUses) {
        return {'valid': false, 'reason': 'Token already used'};
      }
      
      // Check status
      if (tokenInfo['status'] != 'ACTIVE') {
        return {'valid': false, 'reason': 'Token not active'};
      }
      
      return {
        'valid': true, 
        'tokenInfo': tokenInfo,
        'reason': 'Token is valid and available'
      };
      
    } catch (e) {
      print('Error validating registration token: $e');
      return {'valid': false, 'reason': 'Error reading card: ${e.toString()}'};
    }
  }
  
  // Consume registration token (mark as used)
  static Future<bool> consumeRegistrationToken(String cardSerialNumber) async {
    try {
      final validation = await validateRegistrationToken(cardSerialNumber);
      
      if (validation == null || validation['valid'] != true) {
        return false;
      }
      
      final tokenInfo = validation['tokenInfo'] as Map<String, dynamic>;
      
      // Mark token as consumed
      tokenInfo['usedCount'] = (tokenInfo['usedCount'] ?? 0) + 1;
      tokenInfo['status'] = 'CONSUMED';
      tokenInfo['consumedAt'] = DateTime.now().toIso8601String();
      
      // Write updated token back to card
      final updatedData = {'REGISTRATION_TOKEN': tokenInfo};
      await NFCService.writeNFC(updatedData);
      
      return true;
      
    } catch (e) {
      print('Error consuming registration token: $e');
      return false;
    }
  }
  
  // Create registration lock on card
  static Future<void> lockCardToPatient({
    required String cardSerialNumber,
    required String patientName,
    required String patientEmail,
  }) async {
    try {
      final lockData = {
        'REGISTRATION_LOCK': {
          'patientId': cardSerialNumber,
          'patientName': patientName,
          'patientEmail': patientEmail,
          'registrationDate': DateTime.now().toIso8601String(),
          'lockTimestamp': DateTime.now().millisecondsSinceEpoch,
          'hospitalId': HOSPITAL_ID,
          'lockVersion': '1.0',
          'lockType': 'PERMANENT',
          'lockChecksum': _generateLockChecksum(cardSerialNumber, patientName, patientEmail),
        }
      };
      
      await NFCService.writeNFC(lockData);
      print('Card locked successfully to patient: $patientName');
      
    } catch (e) {
      print('Error locking card: $e');
      throw Exception('Failed to lock card: ${e.toString()}');
    }
  }
  
  // Check if card is locked
  static Future<Map<String, dynamic>?> checkCardLock(String cardSerialNumber) async {
    try {
      final cardData = await NFCService.readNFC();
      
      if (cardData == null || !cardData.containsKey('REGISTRATION_LOCK')) {
        return null;
      }
      
      final lockInfo = cardData['REGISTRATION_LOCK'];
      
      // Verify lock integrity
      final expectedChecksum = _generateLockChecksum(
        lockInfo['patientId'],
        lockInfo['patientName'],
        lockInfo['patientEmail'],
      );
      
      if (lockInfo['lockChecksum'] != expectedChecksum) {
        return {
          'isLocked': false,
          'reason': 'Lock integrity compromised',
        };
      }
      
      return {
        'isLocked': true,
        'lockInfo': lockInfo,
        'reason': 'Card is permanently locked',
      };
      
    } catch (e) {
      print('Error checking card lock: $e');
      return null;
    }
  }
  
  // Write patient data to card
  static Future<void> writePatientDataToCard(Map<String, dynamic> patientData) async {
    try {
      final cardPatientData = {
        'PATIENT_DATA': {
          'patientId': patientData['patientId'],
          'name': patientData['name'],
          'email': patientData['email'],
          'phone': patientData['phone'],
          'dateOfBirth': patientData['dateOfBirth'],
          'bloodType': patientData['bloodType'],
          'registrationDate': patientData['registrationDate']?.toString() ?? DateTime.now().toIso8601String(),
          'hospitalId': HOSPITAL_ID,
          'dataVersion': '1.0',
          'dataChecksum': _generateDataChecksum(patientData),
        }
      };
      
      await NFCService.writeNFC(cardPatientData);
      print('Patient data written to card successfully');
      
    } catch (e) {
      print('Error writing patient data to card: $e');
      throw Exception('Failed to write patient data: ${e.toString()}');
    }
  }
  
  // Write security signature to card
  static Future<void> writeSecuritySignature(Map<String, dynamic> patientData) async {
    try {
      final signature = generatePatientCardSignature(
        patientId: patientData['patientId'],
        name: patientData['name'],
        email: patientData['email'],
        cardSerialNumber: patientData['cardSerialNumber'],
      );
      
      final securityData = {
        'SECURITY_SIGNATURE': signature,
        'BINDING_INFO': {
          'patientId': patientData['patientId'],
          'bindingDate': DateTime.now().toIso8601String(),
          'hospitalId': HOSPITAL_ID,
        }
      };
      
      await NFCService.writeNFC(securityData);
      print('Security signature written to card');
      
    } catch (e) {
      print('Error writing security signature: $e');
      throw Exception('Failed to write security signature: ${e.toString()}');
    }
  }
  
  // Read and validate patient data from card
  static Future<Map<String, dynamic>?> readPatientDataFromCard() async {
    try {
      final cardData = await NFCService.readNFC();
      
      if (cardData == null || !cardData.containsKey('PATIENT_DATA')) {
        return null;
      }
      
      final patientData = cardData['PATIENT_DATA'];
      
      // Validate data integrity
      final expectedChecksum = _generateDataChecksum(patientData);
      if (patientData['dataChecksum'] != expectedChecksum) {
        print('Patient data integrity check failed');
        return null;
      }
      
      return {
        'source': 'NFC_CARD',
        'patientData': patientData,
        'isValid': true,
      };
      
    } catch (e) {
      print('Error reading patient data from card: $e');
      return null;
    }
  }
  
  // Initialize blank card with registration token
  static Future<bool> initializeBlankCard(String cardSerialNumber) async {
    try {
      // Check if card is already initialized
      final cardData = await NFCService.readNFC();
      
      if (cardData != null && (
          cardData.containsKey('REGISTRATION_LOCK') ||
          cardData.containsKey('PATIENT_DATA') ||
          cardData.containsKey('REGISTRATION_TOKEN')
      )) {
        return false; // Card already initialized
      }
      
      // Generate and write registration token
      final tokenData = generateRegistrationToken(cardSerialNumber);
      await NFCService.writeNFC(tokenData);
      
      print('Blank card initialized with registration token');
      return true;
      
    } catch (e) {
      print('Error initializing blank card: $e');
      return false;
    }
  }
  
  // Helper: Generate unique token
  static String _generateUniqueToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 31) % 1000000;
    return 'TOKEN-${timestamp.toString()}-${random.toString().padLeft(6, '0')}';
  }
  
  // Helper: Generate lock checksum
  static String _generateLockChecksum(String patientId, String patientName, String patientEmail) {
    final combined = '$patientId|$patientName|$patientEmail|$HOSPITAL_SECRET';
    final bytes = utf8.encode(combined);
    return sha256.convert(bytes).toString().substring(0, 16);
  }
  
  // Helper: Generate data checksum
  static String _generateDataChecksum(Map<String, dynamic> patientData) {
    final keyData = [
      patientData['patientId'],
      patientData['name'],
      patientData['email'],
      patientData['phone'],
      patientData['dateOfBirth'],
      HOSPITAL_SECRET,
    ].join('|');
    
    final bytes = utf8.encode(keyData);
    return sha256.convert(bytes).toString().substring(0, 16);
  }
}