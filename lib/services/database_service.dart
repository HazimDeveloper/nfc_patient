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
      
      return prescriptionId;
    } catch (e) {
      print('Error creating prescription: ${e.toString()}');
      rethrow;
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
      await prescriptionsCollection.doc(prescriptionId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // If prescription is completed, check if patient should be moved to completed
      if (status == 'completed') {
        await _checkAndMovePatientToCompleted(prescriptionId);
      }
      
      print('Prescription status updated: $prescriptionId -> $status');
    } catch (e) {
      print('Error updating prescription status: ${e.toString()}');
      rethrow;
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