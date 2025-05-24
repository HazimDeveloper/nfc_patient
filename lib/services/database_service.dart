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
  final CollectionReference cardMappingCollection = 
      FirebaseFirestore.instance.collection('cardMapping');
  
  // Register new patient with NFC card
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
      // Validate cardSerialNumber
      if (cardSerialNumber.isEmpty) {
        throw Exception('Card serial number cannot be empty');
      }
      
      // Generate a unique patient ID
      final patientId = uid ?? _firestore.collection('patients').doc().id;
      
      print('Registering patient with ID: $patientId and card: $cardSerialNumber');
      
      // Create patient data
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
      };
      
      // Save to Firestore in a transaction to ensure both operations succeed or fail together
      await _firestore.runTransaction((transaction) async {
        // Save patient data
        transaction.set(patientsCollection.doc(patientId), patientData);
        
        // Create a mapping between card serial number and patient ID
        transaction.set(cardMappingCollection.doc(cardSerialNumber), {
          'patientId': patientId,
          'cardSerialNumber': cardSerialNumber,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      
      print('Patient registered successfully');
      
      // Return data for NFC card
      return {
        'patientId': patientId,
        'name': name,
        'dateOfBirth': dateOfBirth,
        'cardSerialNumber': cardSerialNumber,
      };
    } catch (e) {
      print('Error registering patient: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get patient by ID
  Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    try {
      final doc = await patientsCollection.doc(patientId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Error getting patient by ID: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get patient by card serial number
  Future<Map<String, dynamic>?> getPatientByCardSerial(String cardSerialNumber) async {
    try {
      if (cardSerialNumber.isEmpty) {
        print('Card serial number is empty');
        return null;
      }
      
      print('Looking up patient with card serial: $cardSerialNumber');
      
      // First, get the patient ID from the card mapping collection
      final cardDoc = await cardMappingCollection.doc(cardSerialNumber).get();
      
      if (!cardDoc.exists) {
        print('No card mapping found for serial: $cardSerialNumber');
        return null;
      }
      
      final cardData = cardDoc.data() as Map<String, dynamic>;
      final patientId = cardData['patientId'];
      
      if (patientId == null) {
        print('Patient ID is null in card mapping');
        return null;
      }
      
      print('Found patient ID: $patientId for card: $cardSerialNumber');
      
      // Then get the patient document
      return await getPatientById(patientId);
    } catch (e) {
      print('Error getting patient by card serial: ${e.toString()}');
      return null;
    }
  }
  
  // Assign room and doctor to patient
  Future<void> assignRoomAndDoctor({
    required String patientId,
    required String roomNumber,
    required String doctorId,
    String? appointmentNotes,
  }) async {
    try {
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
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      print('Room and doctor assigned to patient: $patientId');
    } catch (e) {
      print('Error assigning room and doctor: ${e.toString()}');
      rethrow;
    }
  }

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
  
  // Get all doctors
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    try {
      final snapshot = await doctorsCollection.get();
      
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting all doctors: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get patients assigned to a doctor
  Future<List<Map<String, dynamic>>> getPatientsByDoctor(String doctorId) async {
    try {
      final snapshot = await appointmentsCollection
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'scheduled')
          .get();
      
      List<Map<String, dynamic>> patients = [];
      
      for (var appointment in snapshot.docs) {
        final appointmentData = appointment.data() as Map<String, dynamic>;
        final patientId = appointmentData['patientId'];
        
        final patientDoc = await patientsCollection.doc(patientId).get();
        
        if (patientDoc.exists) {
          final patientData = patientDoc.data() as Map<String, dynamic>;
          patients.add({
            ...patientData,
            'appointmentId': appointmentData['appointmentId'],
            'roomNumber': appointmentData['roomNumber'],
          });
        }
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
      
      await prescriptionsCollection.doc(prescriptionId).set({
        'prescriptionId': prescriptionId,
        'patientId': patientId,
        'doctorId': doctorId,
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
      
      List<Map<String, dynamic>> result = [];
      
      for (var prescription in snapshot.docs) {
        final prescriptionData = prescription.data() as Map<String, dynamic>;
        final patientId = prescriptionData['patientId'];
        final doctorId = prescriptionData['doctorId'];
        
        // Get patient data
        final patientDoc = await patientsCollection.doc(patientId).get();
        final doctorDoc = await doctorsCollection.doc(doctorId).get();
        
        if (patientDoc.exists && doctorDoc.exists) {
          final patientData = patientDoc.data() as Map<String, dynamic>;
          final doctorData = doctorDoc.data() as Map<String, dynamic>;
          
          result.add({
            ...prescriptionData,
            'patientName': patientData['name'],
            'doctorName': doctorData['name'],
          });
        }
      }
      
      return result;
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
}