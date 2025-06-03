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
  
  // Simple check if NFC card is already registered
  Future<Map<String, dynamic>?> checkCardRegistration(String cardSerialNumber) async {
    try {
      if (cardSerialNumber.isEmpty) {
        return null;
      }
      
      print('Checking card registration: $cardSerialNumber');
      
      // Check if patient exists with this card serial number
      final patientData = await getPatientByIC(cardSerialNumber);
      
      if (patientData != null) {
        return {
          'isRegistered': true,
          'patientData': patientData,
          'message': 'Card is already registered to ${patientData['name']}',
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