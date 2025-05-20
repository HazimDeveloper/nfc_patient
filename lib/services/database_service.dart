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
    // Generate a unique patient ID
    final patientId = uid ?? _firestore.collection('patients').doc().id;
    
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
    
    // Save to Firestore
    await patientsCollection.doc(patientId).set(patientData);
    
    // Create a mapping between card serial number and patient ID
    await cardMappingCollection.doc(cardSerialNumber).set({
      'patientId': patientId,
      'cardSerialNumber': cardSerialNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Return data for NFC card
    return {
      'patientId': patientId,
      'name': name,
      'dateOfBirth': dateOfBirth,
      'cardSerialNumber': cardSerialNumber,
    };
  }
  
  // Get patient by ID
  Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    final doc = await patientsCollection.doc(patientId).get();
    
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    
    return null;
  }
  
  // Get patient by card serial number
  Future<Map<String, dynamic>?> getPatientByCardSerial(String cardSerialNumber) async {
    try {
      // First, get the patient ID from the card mapping collection
      final cardDoc = await cardMappingCollection.doc(cardSerialNumber).get();
      
      if (!cardDoc.exists) {
        return null;
      }
      
      final cardData = cardDoc.data() as Map<String, dynamic>;
      final patientId = cardData['patientId'];
      
      if (patientId == null) {
        return null;
      }
      
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
  }
  
  // Get all doctors
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    final snapshot = await doctorsCollection.get();
    
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }
  
  // Get patients assigned to a doctor
  Future<List<Map<String, dynamic>>> getPatientsByDoctor(String doctorId) async {
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
  }
  
  // Create or update prescription
  Future<String> createPrescription({
    required String patientId,
    required String doctorId,
    required List<Map<String, dynamic>> medications,
    required String diagnosis,
    String? notes,
  }) async {
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
  }
  
  // Get prescriptions by patient ID
  Future<List<Map<String, dynamic>>> getPrescriptionsByPatient(String patientId) async {
    final snapshot = await prescriptionsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }
  
  // Get pending prescriptions for pharmacist
  Future<List<Map<String, dynamic>>> getPendingPrescriptions() async {
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
  }
  
  // Update prescription status
  Future<void> updatePrescriptionStatus(String prescriptionId, String status) async {
    await prescriptionsCollection.doc(prescriptionId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Get all new patients for nurse assignment
  Future<List<Map<String, dynamic>>> getNewPatients() async {
    final snapshot = await patientsCollection
        .where('currentAppointment', isNull: true)
        .orderBy('registrationDate', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }
}