import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nfc_patient_registration/services/nfc_service.dart';
import 'package:nfc_patient_registration/services/card_security_sevice.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? uid;
  
  DatabaseService({this.uid});
  
  // Collection references
  final CollectionReference patientsCollection = 
      FirebaseFirestore.instance.collection('patients');
  final CollectionReference doctorsCollection = 
      FirebaseFirestore.instance.collection('doctors');
  final CollectionReference nursesCollection = 
      FirebaseFirestore.instance.collection('nurses');
  final CollectionReference pharmacistsCollection = 
      FirebaseFirestore.instance.collection('pharmacists');
  final CollectionReference prescriptionsCollection = 
      FirebaseFirestore.instance.collection('prescriptions');
  final CollectionReference appointmentsCollection = 
      FirebaseFirestore.instance.collection('appointments');
  final CollectionReference cardMappingCollection = 
      FirebaseFirestore.instance.collection('cardMapping');

  // Fixed room and doctor data
  static const List<String> availableRooms = ['Room 1', 'Room 2', 'Room 3'];
  
  static const List<Map<String, String>> availableDoctors = [
    {'id': 'doctor1', 'name': 'Dr. Ahmad Rahman', 'specialization': 'General Medicine'},
    {'id': 'doctor2', 'name': 'Dr. Siti Aminah', 'specialization': 'Pediatrics'},
    {'id': 'doctor3', 'name': 'Dr. Kumar Raj', 'specialization': 'Cardiology'},
  ];

  // Get available rooms
  List<String> getAvailableRooms() {
    return availableRooms;
  }

  // Get available doctors
  List<Map<String, String>> getAvailableDoctors() {
    return availableDoctors;
  }

  // Initialize default doctors in Firestore (call this once during setup)
  Future<void> initializeDefaultDoctors() async {
    try {
      for (var doctor in availableDoctors) {
        await doctorsCollection.doc(doctor['id']).set({
          'userId': doctor['id'],
          'name': doctor['name'],
          'email': '${doctor['id']}@hospital.com',
          'specialization': doctor['specialization'],
          'department': 'General',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error initializing doctors: $e');
    }
  }
  
  // 🔐 ENHANCED: Check if NFC card is already registered with full security validation
  Future<Map<String, dynamic>?> checkCardRegistration(String cardSerialNumber) async {
    try {
      if (cardSerialNumber.isEmpty) {
        return null;
      }
      
      print('🔍 Checking card registration with enhanced security: $cardSerialNumber');
      
      // 1. First check if card is locked (highest priority)
      final lockCheck = await CardSecurityService.checkCardLock(cardSerialNumber);
      if (lockCheck != null && lockCheck['isLocked'] == true) {
        final lockInfo = lockCheck['lockInfo'];
        
        print('🔒 Card is locked to patient: ${lockInfo['patientName']}');
        
        // Get full patient data from database
        final patientData = await getPatientByIC(lockInfo['patientId']);
        
        return {
          'isRegistered': true,
          'registrationStatus': 'LOCKED',
          'patientData': patientData ?? lockInfo,
          'lockInfo': lockInfo,
          'source': 'CARD_LOCK',
          'message': 'Card is permanently locked to registered patient',
        };
      }
      
      // 2. Check patient data on card
      final cardPatientData = await CardSecurityService.readPatientDataFromCard();
      if (cardPatientData != null && cardPatientData['isValid'] == true) {
        final patientInfo = cardPatientData['patientData'];
        
        print('📋 Patient data found on card: ${patientInfo['name']}');
        
        // Verify with database
        final dbPatientData = await getPatientByIC(patientInfo['patientId']);
        
        if (dbPatientData != null) {
          // Verify cryptographic binding
          try {
            final cardData = await NFCService.readNFC();
            final isValidBinding = CardSecurityService.verifyCardBinding(cardData!, dbPatientData);
            
            return {
              'isRegistered': true,
              'registrationStatus': 'CARD_DATA_FOUND',
              'patientData': dbPatientData,
              'cardData': patientInfo,
              'source': 'NFC_CARD',
              'bindingValid': isValidBinding,
              'message': 'Patient data found on card and verified',
            };
          } catch (e) {
            print('⚠️ Error verifying card binding: $e');
          }
        }
      }
      
      // 3. Check database directly
      final patientSnapshot = await patientsCollection
          .where('cardSerialNumber', isEqualTo: cardSerialNumber)
          .limit(1)
          .get();
      
      if (patientSnapshot.docs.isNotEmpty) {
        final patientData = patientSnapshot.docs.first.data() as Map<String, dynamic>;
        
        print('💾 Patient found in database: ${patientData['name']}');
        
        return {
          'isRegistered': true,
          'registrationStatus': 'DATABASE_FOUND',
          'patientData': patientData,
          'source': 'DATABASE',
          'message': 'Patient found in database but card may not be properly secured',
        };
      }
      
      // 4. Check if card has valid registration token
      final tokenValidation = await CardSecurityService.validateRegistrationToken(cardSerialNumber);
      if (tokenValidation != null && tokenValidation['valid'] == true) {
        print('🎫 Valid registration token found on card');
        
        return {
          'isRegistered': false,
          'registrationStatus': 'TOKEN_AVAILABLE',
          'tokenInfo': tokenValidation['tokenInfo'],
          'source': 'REGISTRATION_TOKEN',
          'message': 'Card is available for registration',
        };
      }
      
      // 5. Card appears to be blank or uninitialized
      print('📋 Card appears to be blank or uninitialized');
      
      return {
        'isRegistered': false,
        'registrationStatus': 'BLANK_CARD',
        'source': 'UNKNOWN',
        'message': 'Card appears to be blank or uninitialized',
      };
      
    } catch (e) {
      print('❌ Error checking card registration: ${e.toString()}');
      rethrow;
    }
  }
  
  // Enhanced registerPatient method in database_service.dart
// This version handles EVERYTHING automatically

Future<Map<String, dynamic>> registerPatient({
  required String name,
  required String email,
  required String phone,
  required String dateOfBirth,
  required String gender,
  required String address,
  String? bloodType,
  String? emergencyContact,
  List<String>? allergies,
  List<String>? medications,
  List<String>? conditions,
  required String cardSerialNumber,
}) async {
  try {
    if (cardSerialNumber.isEmpty) {
      throw Exception('Patient IC (Card serial number) cannot be empty');
    }
    
    print('🚀 Starting ONE-STEP secure registration with IC: $cardSerialNumber');
    
    // STEP 1: Check current card status
    final cardCheck = await checkCardRegistration(cardSerialNumber);
    
    if (cardCheck != null) {
      final status = cardCheck['registrationStatus'];
      
      switch (status) {
        case 'LOCKED':
          final lockInfo = cardCheck['lockInfo'];
          throw Exception(
            '🔒 This card is permanently locked to patient: ${lockInfo['patientName']} '
            '(ID: ${lockInfo['patientId']}). Registered on: ${lockInfo['registrationDate']}. '
            'This card cannot be used for new registrations.'
          );
          
        case 'CARD_DATA_FOUND':
        case 'DATABASE_FOUND':
          final existingPatient = cardCheck['patientData'] as Map<String, dynamic>;
          throw Exception(
            '👥 This IC is already registered to patient: ${existingPatient['name']} '
            '(ID: ${existingPatient['patientId']}). Each IC can only be registered to one patient.'
          );
          
        case 'TOKEN_AVAILABLE':
          // Good - proceed with existing token
          print('✅ Valid token found, proceeding with registration');
          break;
          
        case 'BLANK_CARD':
        default:
          // AUTO-INITIALIZE: Create token on-the-fly
          print('🆕 Blank card detected, auto-initializing...');
          
          try {
            final tokenData = CardSecurityService.generateRegistrationToken(cardSerialNumber);
            await NFCService.writeNFC(tokenData);
            print('✅ Card auto-initialized with registration token');
          } catch (initError) {
            throw Exception(
              '🔧 Failed to initialize card: ${initError.toString()}. '
              'Please ensure the card is compatible and try again.'
            );
          }
          break;
      }
    } else {
      // No status detected - initialize automatically
      print('🆕 Unknown card status, auto-initializing...');
      try {
        final tokenData = CardSecurityService.generateRegistrationToken(cardSerialNumber);
        await NFCService.writeNFC(tokenData);
        print('✅ Card auto-initialized with registration token');
      } catch (initError) {
        throw Exception(
          '🔧 Failed to initialize card: ${initError.toString()}. '
          'Please ensure the card is compatible and try again.'
        );
      }
    }
    
    // STEP 2: Consume registration token
    print('🎫 Consuming registration token...');
    final tokenConsumed = await CardSecurityService.consumeRegistrationToken(cardSerialNumber);
    if (!tokenConsumed) {
      throw Exception(
        '🎫 Failed to consume registration token. This might indicate a card compatibility issue. '
        'Please try with a different card or contact technical support.'
      );
    }
    
    // STEP 3: Create patient record
    final patientId = cardSerialNumber;
    print('📝 Creating patient record with IC: $patientId');
    
    final patientData = {
      'patientId': patientId,
      'name': name,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'address': address,
      'bloodType': bloodType,
      'emergencyContact': emergencyContact,
      'allergies': allergies ?? [],
      'medications': medications ?? [],
      'conditions': conditions ?? [],
      'cardSerialNumber': cardSerialNumber,
      'registrationDate': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'currentAppointment': null,
      'assignedDoctor': null,
      'assignedRoom': null,
      'securityVersion': '2.0',
      'registrationMethod': 'ONE_STEP_SECURE',
    };
    
    // STEP 4: Save to database
    print('💾 Saving to database...');
    await patientsCollection.doc(patientId).set(patientData);
    
    // STEP 5: Secure the card with all security layers
    print('🔒 Applying security layers...');
    
    try {
      // Layer 1: Lock card permanently
      await CardSecurityService.lockCardToPatient(
        cardSerialNumber: cardSerialNumber,
        patientName: name,
        patientEmail: email,
      );
      
      // Layer 2: Write patient data to card
      await CardSecurityService.writePatientDataToCard(patientData);
      
      // Layer 3: Generate cryptographic signature
      await CardSecurityService.writeSecuritySignature(patientData);
      
      print('✅ All security layers applied successfully');
      
    } catch (securityError) {
      // If security steps fail, still complete registration but warn
      print('⚠️ Warning: Some security layers failed: $securityError');
      
      // Update patient record to indicate partial security
      await patientsCollection.doc(patientId).update({
        'securityStatus': 'PARTIAL',
        'securityWarning': securityError.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
    
    print('🎉 ONE-STEP registration completed successfully: $patientId');
    
    return {
      'patientId': patientId,
      'name': name,
      'dateOfBirth': dateOfBirth,
      'cardSerialNumber': cardSerialNumber,
      'securityLevel': 'ULTIMATE',
      'registrationMethod': 'ONE_STEP_SECURE',
      'registrationTimestamp': DateTime.now().toIso8601String(),
    };
    
  } catch (e) {
    print('❌ ONE-STEP registration failed: ${e.toString()}');
    rethrow;
  }
}
  
  // Helper: Restore registration token if registration fails
  Future<void> _restoreRegistrationToken(String cardSerialNumber) async {
    try {
      final tokenData = CardSecurityService.generateRegistrationToken(cardSerialNumber);
      await NFCService.writeNFC(tokenData);
      print('🔄 Registration token restored');
    } catch (e) {
      print('❌ Failed to restore registration token: $e');
    }
  }
  
  // 🔐 ENHANCED: Initialize blank card with registration token
  Future<bool> initializeBlankCard(String cardSerialNumber) async {
    try {
      print('🆕 Initializing blank card: $cardSerialNumber');
      
      // Check if card is already initialized
      final existingCheck = await checkCardRegistration(cardSerialNumber);
      if (existingCheck != null && (
          existingCheck['registrationStatus'] == 'LOCKED' ||
          existingCheck['registrationStatus'] == 'CARD_DATA_FOUND' ||
          existingCheck['registrationStatus'] == 'DATABASE_FOUND'
      )) {
        print('⚠️ Card is already initialized or registered');
        return false;
      }
      
      // Initialize with registration token
      final success = await CardSecurityService.initializeBlankCard(cardSerialNumber);
      
      if (success) {
        print('✅ Blank card initialized successfully');
      } else {
        print('❌ Failed to initialize blank card');
      }
      
      return success;
      
    } catch (e) {
      print('❌ Error initializing blank card: $e');
      return false;
    }
  }
  
  // Get patient by IC (cardSerialNumber)
  Future<Map<String, dynamic>?> getPatientByIC(String ic) async {
    try {
      if (ic.isEmpty) {
        print('IC number is empty');
        return null;
      }
      
      print('Looking up patient with IC: $ic');
      
      // Get patient directly using IC as document ID
      final doc = await patientsCollection.doc(ic).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Error getting patient by IC: ${e.toString()}');
      return null;
    }
  }

  // Get patient by email (for login)
  Future<Map<String, dynamic>?> getPatientByEmail(String email) async {
    try {
      final snapshot = await patientsCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Error getting patient by email: ${e.toString()}');
      return null;
    }
  }
  
  // Get patient by ID (same as IC)
  Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    return await getPatientByIC(patientId);
  }
  
  // Get patient by card serial number (same as IC)
  Future<Map<String, dynamic>?> getPatientByCardSerial(String cardSerialNumber) async {
    return await getPatientByIC(cardSerialNumber);
  }
  
  // Assign room and doctor to patient
  Future<void> assignRoomAndDoctor({
    required String patientId,
    required String roomNumber,
    required String doctorId,
    String? appointmentNotes,
  }) async {
    try {
      // Validate room and doctor
      if (!availableRooms.contains(roomNumber)) {
        throw Exception('Invalid room number. Available rooms: ${availableRooms.join(", ")}');
      }
      
      final doctorExists = availableDoctors.any((doc) => doc['id'] == doctorId);
      if (!doctorExists) {
        throw Exception('Invalid doctor ID');
      }
      
      // Create appointment
      final appointmentId = appointmentsCollection.doc().id;
      
      await appointmentsCollection.doc(appointmentId).set({
        'appointmentId': appointmentId,
        'patientId': patientId,
        'doctorId': doctorId,
        'roomNumber': roomNumber,
        'status': 'scheduled',
        'notes': appointmentNotes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update patient record
      await patientsCollection.doc(patientId).update({
        'currentAppointment': appointmentId,
        'assignedDoctor': doctorId,
        'assignedRoom': roomNumber,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      print('Room and doctor assigned to patient: $patientId');
    } catch (e) {
      print('Error assigning room and doctor: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get all doctors (return the fixed list)
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    return availableDoctors.map((doc) => {
      'userId': doc['id'],
      'name': doc['name'],
      'specialization': doc['specialization'],
      'department': 'General',
    }).toList();
  }
  
  // Get patients assigned to a specific doctor
  Future<List<Map<String, dynamic>>> getPatientsByDoctor(String doctorId) async {
    try {
      final snapshot = await patientsCollection
          .where('assignedDoctor', isEqualTo: doctorId)
          .get();
      
      List<Map<String, dynamic>> patients = [];
      
      for (var patientDoc in snapshot.docs) {
        final patientData = patientDoc.data() as Map<String, dynamic>;
        
        // Get appointment details if available
        if (patientData['currentAppointment'] != null) {
          final appointmentDoc = await appointmentsCollection
              .doc(patientData['currentAppointment'])
              .get();
          
          if (appointmentDoc.exists) {
            final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
            patientData['roomNumber'] = appointmentData['roomNumber'];
          }
        }
        
        patients.add(patientData);
      }
      
      return patients;
    } catch (e) {
      print('Error getting patients by doctor: ${e.toString()}');
      rethrow;
    }
  }
  
  // Create or update prescription
  Future<String> createPrescription({
    required String patientId,
    required String doctorId,
    required List<Map<String, dynamic>> medications,
    required String diagnosis,
    String? notes,
  }) async {
    try {
      // Generate prescription ID
      final prescriptionId = prescriptionsCollection.doc().id;
      
      // Get patient and doctor names for reference
      final patientData = await getPatientById(patientId);
      final doctorData = availableDoctors.firstWhere(
        (doc) => doc['id'] == doctorId,
        orElse: () => {'name': 'Unknown Doctor'},
      );
      
      await prescriptionsCollection.doc(prescriptionId).set({
        'prescriptionId': prescriptionId,
        'patientId': patientId,
        'doctorId': doctorId,
        'patientName': patientData?['name'],
        'doctorName': doctorData['name'],
        'medications': medications,
        'diagnosis': diagnosis,
        'notes': notes,
        'status': 'pending', // pending, dispensed, completed
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return prescriptionId;
    } catch (e) {
      print('Error creating prescription: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get prescriptions by patient ID
  Future<List<Map<String, dynamic>>> getPrescriptionsByPatient(String patientId) async {
    try {
      final snapshot = await prescriptionsCollection
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting prescriptions by patient: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get pending prescriptions for pharmacist
  Future<List<Map<String, dynamic>>> getPendingPrescriptions() async {
    try {
      final snapshot = await prescriptionsCollection
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt')
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting pending prescriptions: ${e.toString()}');
      rethrow;
    }
  }
  
  // Update prescription status
  Future<void> updatePrescriptionStatus(String prescriptionId, String status) async {
    try {
      await prescriptionsCollection.doc(prescriptionId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating prescription status: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get all new patients for nurse assignment
  Future<List<Map<String, dynamic>>> getNewPatients() async {
    try {
      final snapshot = await patientsCollection
          .where('currentAppointment', isNull: true)
          .orderBy('registrationDate', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting new patients: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get all assigned patients
  Future<List<Map<String, dynamic>>> getAllAssignedPatients() async {
    try {
      final snapshot = await patientsCollection
          .where('currentAppointment', isNotEqualTo: null)
          .orderBy('lastUpdated', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting assigned patients: ${e.toString()}');
      rethrow;
    }
  }

  // Get appointment by ID
  Future<Map<String, dynamic>?> getAppointmentById(String appointmentId) async {
    try {
      final doc = await appointmentsCollection.doc(appointmentId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Error getting appointment by ID: ${e.toString()}');
      return null;
    }
  }

  // Get doctor by ID
  Future<Map<String, dynamic>?> getDoctorById(String doctorId) async {
    try {
      final doctor = availableDoctors.firstWhere(
        (doc) => doc['id'] == doctorId,
        orElse: () => {},
      );
      
      if (doctor.isNotEmpty) {
        return {
          'userId': doctor['id'],
          'name': doctor['name'],
          'specialization': doctor['specialization'],
          'department': 'General',
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting doctor by ID: ${e.toString()}');
      return null;
    }
  }
}