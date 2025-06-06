import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Fixed room data (you can make this dynamic later if needed)
  static const List<String> availableRooms = [
    'Room 1', 'Room 2', 'Room 3', 'Room 4', 'Room 5'
  ];

  // Get available rooms
  List<String> getAvailableRooms() {
    return availableRooms;
  }

  // Get available doctors from Firestore (DYNAMIC)
  Future<List<Map<String, String>>> getAvailableDoctors() async {
    try {
      final snapshot = await doctorsCollection.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id, // Use Firebase document ID
          'name': data['name']?.toString() ?? 'Unknown Doctor',
          'specialization': data['specialization']?.toString() ?? 'General Medicine',
        };
      }).toList();
    } catch (e) {
      print('Error getting doctors: ${e.toString()}');
      return []; // Return empty list if error
    }
  }
  
  // Simple check if NFC card is already registered
  Future<Map<String, dynamic>?> checkCardRegistration(String cardSerialNumber) async {
  try {
    if (cardSerialNumber.isEmpty) {
      return null;
    }
    
    print('Checking card registration: $cardSerialNumber');
    
    // Check if any patient exists with this card serial number
    final existingPatient = await _getPatientByCardSerial(cardSerialNumber);
    
    if (existingPatient != null) {
      return {
        'isRegistered': true,
        'patientData': existingPatient,
        'message': 'Card is already registered to ${existingPatient['name']}',
      };
    }
    
    return {
      'isRegistered': false,
      'message': 'Card is available for registration',
    };
    
  } catch (e) {
    print('Error checking card registration: ${e.toString()}');
    rethrow;
  }
}
  
  // Simple patient registration
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
        throw Exception('Card serial number cannot be empty');
      }
      
      print('Starting patient registration with card: $cardSerialNumber');
      
      // Check if card is already registered
      final cardCheck = await checkCardRegistration(cardSerialNumber);
      
      if (cardCheck != null && cardCheck['isRegistered'] == true) {
        final existingPatient = cardCheck['patientData'] as Map<String, dynamic>;
        throw Exception(
          'This card is already registered to patient: ${existingPatient['name']} '
          '(ID: ${existingPatient['patientId']}). Each card can only be registered to one patient.'
        );
      }
      
      // Use card serial number as patient ID
      final patientId = cardSerialNumber;
      print('Creating patient record with ID: $patientId');
      
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
        'status': 'registered', // registered, active, completed
      };
      
      // Save to database
      await patientsCollection.doc(patientId).set(patientData);
      
      print('Patient registration completed: $patientId');
      
      return {
        'patientId': patientId,
        'name': name,
        'dateOfBirth': dateOfBirth,
        'cardSerialNumber': cardSerialNumber,
        'registrationTimestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('Patient registration failed: ${e.toString()}');
      rethrow;
    }
  }

   Future<Map<String, dynamic>> registerPatientWithIC({
    required String icNumber,
    required String name,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String gender,
    required String address,
    String? bloodType,
    String? emergencyContact,
    required String cardSerialNumber,
  }) async {
    try {
      print('Starting patient registration with IC: $icNumber');
      
      final cleanIcNumber = icNumber.trim();
      
      if (cleanIcNumber.isEmpty) {
        throw Exception('IC number cannot be empty');
      }
      
      // Check if IC number already exists (enhanced check)
      final existingPatientByIC = await getPatientByIC(cleanIcNumber);
      if (existingPatientByIC != null) {
        throw Exception('IC number $cleanIcNumber is already registered to ${existingPatientByIC['name']}');
      }
      
      // Check if card is already used by another patient
      final existingPatientByCard = await _getPatientByCardSerial(cardSerialNumber);
      if (existingPatientByCard != null) {
        throw Exception('This NFC card is already registered to ${existingPatientByCard['name']}');
      }
      
      // Use IC number as patient ID (simple and consistent)
      final patientId = cleanIcNumber;
      
      final patientData = {
        'patientId': patientId,
        'icNumber': cleanIcNumber, // Store IC number separately for clarity
        'name': name,
        'email': email,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'address': address,
        'bloodType': bloodType,
        'emergencyContact': emergencyContact,
        'allergies': [], // Empty by default
        'medications': [], // Empty by default
        'conditions': [], // Empty by default
        'cardSerialNumber': cardSerialNumber,
        'registrationDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'currentAppointment': null,
        'assignedDoctor': null,
        'assignedRoom': null,
        'status': 'registered',
      };
      
      // Save to database using IC as document ID
      await patientsCollection.doc(patientId).set(patientData);
      
      print('Patient registration completed: $patientId');
      
      return {
        'patientId': patientId,
        'icNumber': cleanIcNumber,
        'name': name,
        'dateOfBirth': dateOfBirth,
        'cardSerialNumber': cardSerialNumber,
        'registrationTimestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('Patient registration failed: ${e.toString()}');
      rethrow;
    }
  }

    Future<void> addMedicationToPatient(String patientId, String medicationName) async {
    try {
      final patientDoc = await patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      List<String> currentMedications = List<String>.from(patientData['medications'] ?? []);
      
      if (!currentMedications.contains(medicationName)) {
        currentMedications.add(medicationName);
        
        await patientsCollection.doc(patientId).update({
          'medications': currentMedications,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        print('Medication added to patient: $medicationName');
      }
    } catch (e) {
      print('Error adding medication to patient: ${e.toString()}');
      rethrow;
    }
  }

    Future<void> addConditionToPatient(String patientId, String condition) async {
    try {
      final patientDoc = await patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      List<String> currentConditions = List<String>.from(patientData['conditions'] ?? []);
      
      if (!currentConditions.contains(condition)) {
        currentConditions.add(condition);
        
        await patientsCollection.doc(patientId).update({
          'conditions': currentConditions,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        print('Condition added to patient: $condition');
      }
    } catch (e) {
      print('Error adding condition to patient: ${e.toString()}');
      rethrow;
    }
  }

  // NEW: Remove medication from patient
  Future<void> removeMedicationFromPatient(String patientId, String medicationName) async {
    try {
      final patientDoc = await patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      List<String> currentMedications = List<String>.from(patientData['medications'] ?? []);
      
      if (currentMedications.contains(medicationName)) {
        currentMedications.remove(medicationName);
        
        await patientsCollection.doc(patientId).update({
          'medications': currentMedications,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        print('Medication removed from patient: $medicationName');
      }
    } catch (e) {
      print('Error removing medication from patient: ${e.toString()}');
      rethrow;
    }
  }

// FIXED: Helper method to get patient by card serial number
Future<Map<String, dynamic>?> _getPatientByCardSerial(String cardSerialNumber) async {
  try {
    final snapshot = await patientsCollection
        .where('cardSerialNumber', isEqualTo: cardSerialNumber)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data() as Map<String, dynamic>;
    }
    
    return null;
  } catch (e) {
    print('Error getting patient by card serial: ${e.toString()}');
    return null;
  }
}
  
  Future<Map<String, dynamic>?> getPatientByIC(String icNumber) async {
    try {
      print('Searching for patient with IC: $icNumber');
      
      if (icNumber.trim().isEmpty) {
        print('IC number is empty');
        return null;
      }
      
      final cleanIcNumber = icNumber.trim();
      
      // Method 1: Try to find by document ID (which should be the IC number)
      var doc = await patientsCollection.doc(cleanIcNumber).get();
      
      if (doc.exists && doc.data() != null) {
        print('Patient found by document ID: ${doc.id}');
        final data = doc.data() as Map<String, dynamic>;
        return data;
      }
      
      // Method 2: Search by icNumber field
      final snapshot = await patientsCollection
          .where('icNumber', isEqualTo: cleanIcNumber)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        print('Patient found by icNumber field: ${snapshot.docs.first.id}');
        return snapshot.docs.first.data() as Map<String, dynamic>;
      }
      
      // Method 3: Search by patientId field (fallback)
      final snapshot2 = await patientsCollection
          .where('patientId', isEqualTo: cleanIcNumber)
          .limit(1)
          .get();
      
      if (snapshot2.docs.isNotEmpty) {
        print('Patient found by patientId field: ${snapshot2.docs.first.id}');
        return snapshot2.docs.first.data() as Map<String, dynamic>;
      }
      
      // Method 4: Search by cardSerialNumber (in case IC was used as card ID)
      final snapshot3 = await patientsCollection
          .where('cardSerialNumber', isEqualTo: cleanIcNumber)
          .limit(1)
          .get();
      
      if (snapshot3.docs.isNotEmpty) {
        print('Patient found by cardSerialNumber field: ${snapshot3.docs.first.id}');
        return snapshot3.docs.first.data() as Map<String, dynamic>;
      }
      
      print('No patient found with IC: $cleanIcNumber');
      return null;
      
    } catch (e) {
      print('Error getting patient by IC: ${e.toString()}');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPatientsFixed() async {
  try {
    // First ensure user has proper role
    await checkAndFixUserRole();
    
    print('Attempting to get patients...');
    
    // Simple query without ordering (ordering might cause permission issues)
    final snapshot = await patientsCollection.get();
    
    List<Map<String, dynamic>> patients = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['documentId'] = doc.id;
      patients.add(data);
    }
    
    print('Successfully retrieved ${patients.length} patients');
    return patients;
  } catch (e) {
    print('Error getting patients: $e');
    return [];
  }
}

// Add this method to your database_service.dart to debug the issue

Future<void> fullDebugCheck() async {
  print('=== FULL DEBUG CHECK START ===');
  
  try {
    // 1. Check Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    print('1. AUTH CHECK:');
    if (currentUser == null) {
      print('   ❌ No user logged in');
      return;
    } else {
      print('   ✅ User logged in');
      print('   - UID: ${currentUser.uid}');
      print('   - Email: ${currentUser.email}');
      print('   - Email Verified: ${currentUser.emailVerified}');
    }
    
    // 2. Check user document
    print('\n2. USER DOCUMENT CHECK:');
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print('   ✅ User document exists');
        print('   - Role: ${userData['role']}');
        print('   - Name: ${userData['name']}');
        print('   - Active: ${userData['isActive']}');
      } else {
        print('   ❌ User document missing');
        print('   Creating user document...');
        
        await _firestore.collection('users').doc(currentUser.uid).set({
          'email': currentUser.email,
          'name': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'User',
          'role': 'nurse',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('   ✅ User document created with nurse role');
      }
    } catch (e) {
      print('   ❌ Error accessing user document: $e');
    }
    
    // 3. Test simple Firestore access
    print('\n3. FIRESTORE ACCESS TEST:');
    try {
      // Test writing first
      await _firestore.collection('test').doc('debug').set({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser.uid,
      });
      print('   ✅ Can write to Firestore');
      
      // Test reading
      final testDoc = await _firestore.collection('test').doc('debug').get();
      print('   ✅ Can read from Firestore');
      
      // Clean up test document
      await _firestore.collection('test').doc('debug').delete();
      print('   ✅ Can delete from Firestore');
      
    } catch (e) {
      print('   ❌ Firestore access error: $e');
    }
    
    // 4. Test patients collection specifically
    print('\n4. PATIENTS COLLECTION TEST:');
    try {
      // Try simple read without ordering
      final patientsSnapshot = await _firestore.collection('patients').limit(1).get();
      print('   ✅ Can access patients collection');
      print('   - Found ${patientsSnapshot.docs.length} documents');
      
      if (patientsSnapshot.docs.isNotEmpty) {
        final firstPatient = patientsSnapshot.docs.first.data();
        print('   - Sample patient: ${firstPatient['name'] ?? 'No name'}');
      }
    } catch (e) {
      print('   ❌ Cannot access patients collection: $e');
    }
    
    // 5. Test with ordering (this is what's failing)
    print('\n5. ORDERED QUERY TEST:');
    try {
      final orderedSnapshot = await _firestore
          .collection('patients')
          .orderBy('name')
          .limit(1)
          .get();
      print('   ✅ Ordered query works');
    } catch (e) {
      print('   ❌ Ordered query fails: $e');
      print('   This suggests either:');
      print('   - Missing composite index');
      print('   - Firestore rules blocking ordered queries');
    }
    
  } catch (e) {
    print('❌ Debug check failed: $e');
  }
  
  print('=== FULL DEBUG CHECK END ===');
}

// Simplified method to get patients without ordering
Future<List<Map<String, dynamic>>> getPatientsWithoutOrdering() async {
  try {
    print('Getting patients without ordering...');
    
    // Simple query without any ordering
    final snapshot = await _firestore.collection('patients').get();
    
    List<Map<String, dynamic>> patients = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      data['documentId'] = doc.id;
      patients.add(data);
    }
    
    // Sort in memory instead of in query
    patients.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
    
    print('Retrieved ${patients.length} patients successfully');
    return patients;
  } catch (e) {
    print('Error getting patients without ordering: $e');
    return [];
  }
}

 Future<List<Map<String, dynamic>>> getAllPatientsForDebug() async {
  try {
    print('Attempting to get all patients for debug...');
    
    // Try with a smaller limit first to test permissions
    final snapshot = await patientsCollection.limit(10).get();
    
    List<Map<String, dynamic>> patients = [];
    for (var doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        data['documentId'] = doc.id; // Add document ID for debugging
        patients.add(data);
      } catch (e) {
        print('Error processing patient document ${doc.id}: $e');
      }
    }
    
    print('Successfully retrieved ${patients.length} patients');
    return patients;
  } catch (e) {
    print('Error getting all patients for debug: ${e.toString()}');
    
    // If we get a permission error, try to get patients in a different way
    if (e.toString().contains('permission-denied')) {
      print('Permission denied - trying alternative approach...');
      return await _getPatientsByAlternativeMethod();
    }
    
    return [];
  }
}

// Alternative method to get patients when direct access is denied
Future<List<Map<String, dynamic>>> _getPatientsByAlternativeMethod() async {
  try {
    // Try getting patients by status first (this might have different permissions)
    final registeredPatients = await getPatientsByStatus('registered');
    final activePatients = await getPatientsByStatus('active');
    final completedPatients = await getPatientsByStatus('completed');
    
    // Combine all patients
    final allPatients = <String, Map<String, dynamic>>{};
    
    for (var patient in [...registeredPatients, ...activePatients, ...completedPatients]) {
      allPatients[patient['patientId']] = patient;
    }
    
    print('Retrieved ${allPatients.length} patients via alternative method');
    return allPatients.values.toList();
  } catch (e) {
    print('Alternative method also failed: $e');
    return [];
  }
}

// ALSO ADD: Method to check current user permissions
Future<void> debugUserPermissions() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('DEBUG: No user logged in');
      return;
    }
    
    print('DEBUG: Current user UID: ${currentUser.uid}');
    print('DEBUG: Current user email: ${currentUser.email}');
    
    // Try to get user role
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print('DEBUG: User role: ${userData['role']}');
        print('DEBUG: User name: ${userData['name']}');
      } else {
        print('DEBUG: User document does not exist in users collection');
      }
    } catch (e) {
      print('DEBUG: Error getting user document: $e');
    }
    
  } catch (e) {
    print('DEBUG: Error checking user permissions: $e');
  }
}

// ALSO ADD this debug method to see what patients exist:
Future<void> debugPrintAllPatients() async {
  try {
    final snapshot = await patientsCollection.limit(5).get();
    print('=== DEBUG: Existing Patients ===');
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      print('Doc ID: ${doc.id}');
      print('Patient ID: ${data['patientId']}');
      print('IC Number: ${data['icNumber']}');
      print('Name: ${data['name']}');
      print('---');
    }
    print('=== End Debug ===');
  } catch (e) {
    print('Debug error: $e');
  }
}

// ADD these methods to your database_service.dart file:

// Get appointments by patient ID
Future<List<Map<String, dynamic>>> getAppointmentsByPatient(String patientId) async {
  try {
    final snapshot = await appointmentsCollection
        .where('patientId', isEqualTo: patientId)
        .get();
    
    List<Map<String, dynamic>> appointments = [];
    
    for (var doc in snapshot.docs) {
      final appointmentData = doc.data() as Map<String, dynamic>;
      
      // Add doctor name if available
      if (appointmentData['doctorId'] != null) {
        try {
          final doctorData = await getDoctorById(appointmentData['doctorId']);
          if (doctorData != null) {
            appointmentData['doctorName'] = doctorData['name'];
          }
        } catch (e) {
          print('Error loading doctor for appointment: $e');
        }
      }
      
      appointments.add(appointmentData);
    }
    
    // Sort by creation date (newest first)
    appointments.sort((a, b) {
      final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bDate.compareTo(aDate);
    });
    
    return appointments;
  } catch (e) {
    print('Error getting appointments by patient: ${e.toString()}');
    return [];
  }
}


// Enhanced patient search for better NFC support
Future<Map<String, dynamic>?> findPatientByCardSerial(String cardSerialNumber) async {
  try {
    print('Searching for patient with card serial: $cardSerialNumber');
    
    // Search by card serial number
    final snapshot = await patientsCollection
        .where('cardSerialNumber', isEqualTo: cardSerialNumber)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      final patientData = snapshot.docs.first.data() as Map<String, dynamic>;
      print('Found patient: ${patientData['name']}');
      return patientData;
    }
    
    print('No patient found with card serial: $cardSerialNumber');
    return null;
    
  } catch (e) {
    print('Error finding patient by card serial: $e');
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
      // Validate room
      if (!availableRooms.contains(roomNumber)) {
        throw Exception('Invalid room number. Available rooms: ${availableRooms.join(", ")}');
      }
      
      // Validate doctor exists
      final doctorData = await getDoctorById(doctorId);
      if (doctorData == null) {
        throw Exception('Invalid doctor ID: Doctor not found');
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
        'status': 'active', // Change status to active when assigned
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      print('Room and doctor assigned to patient: $patientId');
    } catch (e) {
      print('Error assigning room and doctor: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get patients assigned to a specific doctor (only active ones)
  Future<List<Map<String, dynamic>>> getPatientsByDoctor(String doctorId) async {
    try {
      // Simple query first
      final snapshot = await patientsCollection
          .where('assignedDoctor', isEqualTo: doctorId)
          .get();
      
      List<Map<String, dynamic>> patients = [];
      
      for (var patientDoc in snapshot.docs) {
        final patientData = patientDoc.data() as Map<String, dynamic>;
        
        // Filter completed patients in memory
        if (patientData['status'] != 'completed') {
          // Get appointment details if available
          if (patientData['currentAppointment'] != null) {
            try {
              final appointmentDoc = await appointmentsCollection
                  .doc(patientData['currentAppointment'])
                  .get();
              
              if (appointmentDoc.exists) {
                final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
                patientData['roomNumber'] = appointmentData['roomNumber'];
              }
            } catch (e) {
              print('Error loading appointment for patient: $e');
            }
          }
          
          patients.add(patientData);
        }
      }
      
      // Sort in memory
      patients.sort((a, b) {
        final aUpdated = (a['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bUpdated = (b['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bUpdated.compareTo(aUpdated);
      });
      
      return patients;
    } catch (e) {
      print('Error getting patients by doctor: ${e.toString()}');
      return [];
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
      
      // Get patient and doctor names
      final patientData = await getPatientById(patientId);
      final doctorData = await getDoctorById(doctorId);
      
      await prescriptionsCollection.doc(prescriptionId).set({
        'prescriptionId': prescriptionId,
        'patientId': patientId,
        'doctorId': doctorId,
        'patientName': patientData?['name'],
        'doctorName': doctorData?['name'] ?? 'Unknown Doctor',
        'medications': medications,
        'diagnosis': diagnosis,
        'notes': notes,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ADD: Update patient's current medications and conditions
      await _updatePatientMedicalInfo(patientId, medications, diagnosis);
      
      return prescriptionId;
    } catch (e) {
      print('Error creating prescription: ${e.toString()}');
      rethrow;
    }
  }

    Future<void> _updatePatientMedicalInfo(
    String patientId, 
    List<Map<String, dynamic>> medications, 
    String diagnosis
  ) async {
    try {
      // Get current patient data
      final patientDoc = await patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) return;
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      
      // Get current medications and conditions
      List<String> currentMedications = List<String>.from(patientData['medications'] ?? []);
      List<String> currentConditions = List<String>.from(patientData['conditions'] ?? []);
      
      // Add new medications (avoid duplicates)
      for (var medication in medications) {
        final medicationName = medication['name'] as String;
        if (!currentMedications.contains(medicationName)) {
          currentMedications.add(medicationName);
        }
      }
      
      // Add diagnosis as a condition (avoid duplicates)
      if (!currentConditions.contains(diagnosis)) {
        currentConditions.add(diagnosis);
      }
      
      // Update patient record
      await patientsCollection.doc(patientId).update({
        'medications': currentMedications,
        'conditions': currentConditions,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      print('Patient medical info updated: $patientId');
    } catch (e) {
      print('Error updating patient medical info: ${e.toString()}');
      // Don't throw error - this is supplementary update
    }
  }
  
  // Get prescriptions by patient ID
  Future<List<Map<String, dynamic>>> getPrescriptionsByPatient(String patientId) async {
    try {
      // Simple query without complex ordering to avoid index issues
      final snapshot = await prescriptionsCollection
          .where('patientId', isEqualTo: patientId)
          .get(); // Remove orderBy temporarily
      
      final prescriptions = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      // Sort in memory instead of using Firestore orderBy
      prescriptions.sort((a, b) {
        final aCreated = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bCreated = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bCreated.compareTo(aCreated); // Newest first
      });
      
      return prescriptions;
    } catch (e) {
      print('Error getting prescriptions by patient: ${e.toString()}');
      return []; // Return empty list instead of throwing error
    }
  }
  
  // Get pending prescriptions for pharmacist
  Future<List<Map<String, dynamic>>> getPendingPrescriptions() async {
    try {
      final snapshot = await prescriptionsCollection
          .where('status', isEqualTo: 'pending')
          .get();
      
      final prescriptions = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      // Sort in memory - oldest first for pending
      prescriptions.sort((a, b) {
        final aCreated = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bCreated = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aCreated.compareTo(bCreated); // Oldest first
      });
      
      return prescriptions;
    } catch (e) {
      print('Error getting pending prescriptions: ${e.toString()}');
      return [];
    }
  }
  
  // Update prescription status and handle completion flow
   Future<void> updatePrescriptionStatus(String prescriptionId, String status) async {
    try {
      // Get prescription data first
      final prescriptionDoc = await prescriptionsCollection.doc(prescriptionId).get();
      if (!prescriptionDoc.exists) {
        throw Exception('Prescription not found');
      }
      
      final prescriptionData = prescriptionDoc.data() as Map<String, dynamic>;
      
      await prescriptionsCollection.doc(prescriptionId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If prescription is completed, handle medication updates
      if (status == 'completed') {
        await _handlePrescriptionCompletion(prescriptionData);
        await _checkAndMovePatientToCompleted(prescriptionId);
      }
      
      print('Prescription status updated: $prescriptionId -> $status');
    } catch (e) {
      print('Error updating prescription status: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> checkAndFixUserRole() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('ERROR: No user logged in');
      return;
    }
    
    print('=== USER DEBUG INFO ===');
    print('User UID: ${currentUser.uid}');
    print('User Email: ${currentUser.email}');
    
    // Check if user document exists
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    
    if (!userDoc.exists) {
      print('ERROR: User document does not exist');
      print('Creating user document with nurse role...');
      
      // Create user document with nurse role
      await _firestore.collection('users').doc(currentUser.uid).set({
        'email': currentUser.email,
        'name': currentUser.displayName ?? 'User',
        'role': 'nurse', // Set as nurse to allow patient access
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      
      print('User document created with nurse role');
    } else {
      final userData = userDoc.data() as Map<String, dynamic>;
      print('User Role: ${userData['role']}');
      print('User Name: ${userData['name']}');
      
      // If user has no role or wrong role, update it
      if (userData['role'] == null || userData['role'] == '') {
        print('Updating user role to nurse...');
        await _firestore.collection('users').doc(currentUser.uid).update({
          'role': 'nurse',
        });
        print('User role updated to nurse');
      }
    }
    
    print('=== END USER DEBUG ===');
  } catch (e) {
    print('Error in checkAndFixUserRole: $e');
  }
}
  
  Future<void> _handlePrescriptionCompletion(Map<String, dynamic> prescriptionData) async {
    try {
      final patientId = prescriptionData['patientId'];
      final medications = prescriptionData['medications'] as List<dynamic>;
      
      // Get current patient data
      final patientDoc = await patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) return;
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      List<String> currentMedications = List<String>.from(patientData['medications'] ?? []);
      
      // Check if medications should be removed (completed course)
      // For now, we'll keep them as "completed medications" for history
      // You can modify this logic based on your requirements
      
      // Add completion timestamp to patient record
      await patientsCollection.doc(patientId).update({
        'lastPrescriptionCompleted': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('Error handling prescription completion: ${e.toString()}');
    }
  }

  // Check if patient should be moved to completed status
  Future<void> _checkAndMovePatientToCompleted(String prescriptionId) async {
    try {
      // Get the prescription to find patient ID
      final prescriptionDoc = await prescriptionsCollection.doc(prescriptionId).get();
      if (!prescriptionDoc.exists) return;
      
      final prescriptionData = prescriptionDoc.data() as Map<String, dynamic>;
      final patientId = prescriptionData['patientId'];
      
      // Check if patient has any pending or dispensed prescriptions
      final activePrescriptionsSnapshot = await prescriptionsCollection
          .where('patientId', isEqualTo: patientId)
          .get();
      
      // Filter active prescriptions in memory
      final activePrescriptions = activePrescriptionsSnapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];
            return status == 'pending' || status == 'dispensed';
          })
          .toList();
      
      // If no active prescriptions, mark patient as completed
      if (activePrescriptions.isEmpty) {
        await _markPatientAsCompleted(patientId);
      }
      
    } catch (e) {
      print('Error checking patient completion status: ${e.toString()}');
    }
  }
  
  // Mark patient as completed (remove from active assignments)
  Future<void> _markPatientAsCompleted(String patientId) async {
    try {
      // Update patient record
      await patientsCollection.doc(patientId).update({
        'status': 'completed', // Change status to completed
        'completedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        // Keep assignment info for records but mark as completed
      });
      
      // Update appointment status if exists
      final patientDoc = await patientsCollection.doc(patientId).get();
      if (patientDoc.exists) {
        final patientData = patientDoc.data() as Map<String, dynamic>;
        final appointmentId = patientData['currentAppointment'];
        
        if (appointmentId != null) {
          await appointmentsCollection.doc(appointmentId).update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      print('Patient marked as completed: $patientId');
    } catch (e) {
      print('Error marking patient as completed: ${e.toString()}');
    }
  }
  
  // Get patients by status for different views
  Future<List<Map<String, dynamic>>> getPatientsByStatus(String status) async {
    try {
      QuerySnapshot snapshot;
      
      if (status == 'active') {
        // Active patients: assigned but not completed
        snapshot = await patientsCollection
            .where('status', isEqualTo: 'active')
            .get();
      } else if (status == 'completed') {
        // Completed patients
        snapshot = await patientsCollection
            .where('status', isEqualTo: 'completed')
            .get();
      } else if (status == 'registered') {
        // Newly registered, not assigned yet
        snapshot = await patientsCollection
            .where('status', isEqualTo: 'registered')
            .get();
      } else {
        // Default: all patients
        snapshot = await patientsCollection.get();
      }
      
      List<Map<String, dynamic>> patients = [];
      
      for (var doc in snapshot.docs) {
        final patientData = doc.data() as Map<String, dynamic>;
        
        // Add appointment details if available
        if (patientData['currentAppointment'] != null) {
          try {
            final appointmentDoc = await appointmentsCollection
                .doc(patientData['currentAppointment'])
                .get();
            
            if (appointmentDoc.exists) {
              final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
              patientData['roomNumber'] = appointmentData['roomNumber'];
              patientData['appointmentStatus'] = appointmentData['status'];
            }
          } catch (e) {
            print('Error loading appointment for patient: $e');
          }
        }
        
        patients.add(patientData);
      }
      
      // Sort in memory
      patients.sort((a, b) {
        Timestamp? aTime;
        Timestamp? bTime;
        
        if (status == 'completed') {
          aTime = a['completedAt'] as Timestamp?;
          bTime = b['completedAt'] as Timestamp?;
        } else {
          aTime = a['lastUpdated'] as Timestamp? ?? a['registrationDate'] as Timestamp?;
          bTime = b['lastUpdated'] as Timestamp? ?? b['registrationDate'] as Timestamp?;
        }
        
        final aDate = aTime?.toDate() ?? DateTime.now();
        final bDate = bTime?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate); // Newest first
      });
      
      return patients;
    } catch (e) {
      print('Error getting patients by status: ${e.toString()}');
      return [];
    }
  }
  
  // Get all new patients for nurse assignment (registered but not assigned)
  Future<List<Map<String, dynamic>>> getNewPatients() async {
    try {
      final snapshot = await patientsCollection
          .where('status', isEqualTo: 'registered')
          .get();
      
      final patients = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      // Sort in memory
      patients.sort((a, b) {
        final aDate = (a['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate = (b['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate); // Newest first
      });
      
      return patients;
    } catch (e) {
      print('Error getting new patients: ${e.toString()}');
      return [];
    }
  }
  
  // Get all assigned patients (active)
  Future<List<Map<String, dynamic>>> getAllAssignedPatients() async {
    try {
      return await getPatientsByStatus('active');
    } catch (e) {
      print('Error getting assigned patients: ${e.toString()}');
      return [];
    }
  }
  
  // Get completed prescriptions for tracking
  Future<List<Map<String, dynamic>>> getCompletedPrescriptions({int? limit}) async {
    try {
      final snapshot = await prescriptionsCollection
          .where('status', isEqualTo: 'completed')
          .get();
      
      final prescriptions = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      // Sort in memory - newest first
      prescriptions.sort((a, b) {
        final aUpdated = (a['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bUpdated = (b['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bUpdated.compareTo(aUpdated);
      });
      
      // Apply limit if specified
      if (limit != null && prescriptions.length > limit) {
        return prescriptions.take(limit).toList();
      }
      
      return prescriptions;
    } catch (e) {
      print('Error getting completed prescriptions: ${e.toString()}');
      return [];
    }
  }
  
  // Get prescriptions by status for pharmacist
  Future<List<Map<String, dynamic>>> getPrescriptionsByStatus(String status) async {
    try {
      final snapshot = await prescriptionsCollection
          .where('status', isEqualTo: status)
          .get();
      
      final prescriptions = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      // Sort in memory
      prescriptions.sort((a, b) {
        if (status == 'pending') {
          // Oldest first for pending
          final aCreated = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bCreated = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return aCreated.compareTo(bCreated);
        } else {
          // Newest first for completed/dispensed
          final aUpdated = (a['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bUpdated = (b['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bUpdated.compareTo(aUpdated);
        }
      });
      
      return prescriptions;
    } catch (e) {
      print('Error getting prescriptions by status: ${e.toString()}');
      return [];
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

  // Get doctor by ID from Firestore
  Future<Map<String, dynamic>?> getDoctorById(String doctorId) async {
    try {
      final doc = await doctorsCollection.doc(doctorId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Error getting doctor by ID: ${e.toString()}');
      return null;
    }
  }
  
  // Get patient statistics for dashboard
  Future<Map<String, int>> getPatientStatistics() async {
    try {
      // Get all patients
      final allPatientsSnapshot = await patientsCollection.get();
      final totalPatients = allPatientsSnapshot.docs.length;
      
      // Count by status in memory to avoid complex queries
      int activePatients = 0;
      int completedPatients = 0;
      int unassignedPatients = 0;
      
      for (var doc in allPatientsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'];
        
        switch (status) {
          case 'active':
            activePatients++;
            break;
          case 'completed':
            completedPatients++;
            break;
          case 'registered':
            unassignedPatients++;
            break;
        }
      }
      
      return {
        'total': totalPatients,
        'active': activePatients,
        'completed': completedPatients,
        'unassigned': unassignedPatients,
      };
    } catch (e) {
      print('Error getting patient statistics: ${e.toString()}');
      return {
        'total': 0,
        'active': 0,
        'completed': 0,
        'unassigned': 0,
      };
    }
  }
  
  // Get prescription statistics for pharmacist dashboard
  Future<Map<String, int>> getPrescriptionStatistics() async {
    try {
      // Get all prescriptions
      final allPrescriptionsSnapshot = await prescriptionsCollection.get();
      
      // Count by status in memory
      int pendingCount = 0;
      int dispensedCount = 0;
      int completedTodayCount = 0;
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      for (var doc in allPrescriptionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'];
        
        switch (status) {
          case 'pending':
            pendingCount++;
            break;
          case 'dispensed':
            dispensedCount++;
            break;
          case 'completed':
            // Check if completed today
            final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
            if (updatedAt != null && updatedAt.isAfter(startOfDay)) {
              completedTodayCount++;
            }
            break;
        }
      }
      
      return {
        'pending': pendingCount,
        'dispensed': dispensedCount,
        'completedToday': completedTodayCount,
      };
    } catch (e) {
      print('Error getting prescription statistics: ${e.toString()}');
      return {
        'pending': 0,
        'dispensed': 0,
        'completedToday': 0,
      };
    }
  }

   Future<void> markPatientAsCompleted(String patientId) async {
    await _markPatientAsCompleted(patientId);
  }
}