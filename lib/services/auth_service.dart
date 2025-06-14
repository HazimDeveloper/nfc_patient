import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nfc_patient_registration/services/database_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  
  // Add this property to track patient sessions
  Map<String, dynamic>? _currentPatientSession;
  
  // FIXED: Add role caching to prevent multiple calls
  String? _cachedUserRole;
  String? _cachedUserId;
  
  // Public getter for patient session
  Map<String, dynamic>? get currentPatientSession => _currentPatientSession;
  
  // Get auth state changes
  Stream<User?> get user => _auth.authStateChanges();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is logged in (including patient sessions)
  bool get isLoggedIn {
    return currentUser != null || _currentPatientSession != null;
  }
  
  // FIXED: Simplified userStream - only emit when auth state actually changes
  Stream<Map<String, dynamic>?> get userStream {
    return _auth.authStateChanges().map((user) {
      if (_currentPatientSession != null) {
        return _currentPatientSession;
      } else if (user != null) {
        return {
          'uid': user.uid,
          'email': user.email,
          'isPatient': false,
        };
      }
      return null;
    });
  }
  
  // Clear cached data when user changes
  void _clearCache() {
    _cachedUserRole = null;
    _cachedUserId = null;
  }
  
  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      _clearCache(); // Clear cache before sign in
      final result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      notifyListeners();
      return result.user;
    } catch (e) {
      print('Error signing in: ${e.toString()}');
      rethrow;
    }
  }
  
   Future<void> signInPatientWithIC(String icNumber) async {
    try {
      _clearCache(); // Clear cache before sign in
      
      if (icNumber.trim().isEmpty) {
        throw Exception('Please enter your IC number.');
      }
      
      final cleanIcNumber = icNumber.trim();
      print('Attempting patient login with IC: $cleanIcNumber');
      
      // Enhanced search using the improved getPatientByIC method
      final patientData = await _databaseService.getPatientByIC(cleanIcNumber);
      
      if (patientData == null) {
        // Try to debug - get all patients to see what's in the database
        print('Patient not found. Checking database...');
        final allPatients = await _databaseService.getAllPatientsForDebug();
        print('Total patients in database: ${allPatients.length}');
        
        for (var patient in allPatients.take(5)) {
          print('Patient: ${patient['name']} - IC: ${patient['icNumber']} - PatientID: ${patient['patientId']} - Doc ID: ${patient['documentId']}');
        }
        
        throw Exception('Patient not found. Please check your IC number or contact the hospital registration desk.\n\nIf you just registered, please make sure your IC number is exactly: $cleanIcNumber');
      }
      
      print('Patient found: ${patientData['name']} (IC: ${patientData['icNumber']})');
      
      // Create a temporary user session for patient
      try {
        await _firestore.collection('patient_sessions').doc(cleanIcNumber).set({
          'patientId': cleanIcNumber,
          'loginTime': FieldValue.serverTimestamp(),
          'isActive': true,
          'patientName': patientData['name'],
        });
      } catch (sessionError) {
        print('Warning: Could not create session document: $sessionError');
        // Continue anyway - the local session is more important
      }
      
      // Store patient session locally
      _currentPatientSession = {
        'patientId': cleanIcNumber,
        'isPatient': true,
        'loginTime': DateTime.now(),
        'patientData': patientData, // Store patient data for easy access
      };
      
      print('Patient session created successfully for: ${patientData['name']}');
      notifyListeners();
    } catch (e) {
      print('Error signing in patient: ${e.toString()}');
      rethrow;
    }
  }
  
  // Register with email and password
  Future<User?> registerWithEmailAndPassword(
    String email, 
    String password, 
    String name, 
    String role
  ) async {
    try {
      _clearCache(); // Clear cache before registration
      
      // Create user in Firebase Auth
      final result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      final user = result.user;
      
      if (user != null) {
        // Create user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'name': name,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // If it's a doctor, create doctor profile
        if (role == 'doctor') {
          await _createDoctorProfile(user.uid, name, email);
        }
        
        // If it's a nurse, create nurse profile
        if (role == 'nurse') {
          await _createNurseProfile(user.uid, name, email);
        }
        
        // If it's a pharmacist, create pharmacist profile
        if (role == 'pharmacist') {
          await _createPharmacistProfile(user.uid, name, email);
        }
        
        notifyListeners();
      }
      
      return user;
    } catch (e) {
      print('Error registering: ${e.toString()}');
      rethrow;
    }
  }
  
  // Create doctor profile when doctor registers
  Future<void> _createDoctorProfile(String userId, String name, String email) async {
    try {
      await _firestore.collection('doctors').doc(userId).set({
        'userId': userId,
        'name': name,
        'email': email,
        'specialization': 'General Medicine', // Default, can be updated later
        'department': 'General',
        'phone': null,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Doctor profile created for: $userId');
    } catch (e) {
      print('Error creating doctor profile: ${e.toString()}');
      rethrow;
    }
  }
  
  // Create nurse profile when nurse registers
  Future<void> _createNurseProfile(String userId, String name, String email) async {
    try {
      await _firestore.collection('nurses').doc(userId).set({
        'userId': userId,
        'name': name,
        'email': email,
        'department': 'General',
        'phone': null,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Nurse profile created for: $userId');
    } catch (e) {
      print('Error creating nurse profile: ${e.toString()}');
      rethrow;
    }
  }
  
  // Create pharmacist profile when pharmacist registers
  Future<void> _createPharmacistProfile(String userId, String name, String email) async {
    try {
      await _firestore.collection('pharmacists').doc(userId).set({
        'userId': userId,
        'name': name,
        'email': email,
        'department': 'Pharmacy',
        'phone': null,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Pharmacist profile created for: $userId');
    } catch (e) {
      print('Error creating pharmacist profile: ${e.toString()}');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    // Clear patient session if exists
    if (_currentPatientSession != null) {
      try {
        await _firestore.collection('patient_sessions')
            .doc(_currentPatientSession!['patientId'])
            .update({
          'isActive': false,
          'logoutTime': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating patient session: $e');
      }
      _currentPatientSession = null;
    }
    
    // Clear cache
    _clearCache();
    
    // Sign out from Firebase
    await _auth.signOut();
    notifyListeners();
  }
  
  // FIXED: Get user role with caching to prevent multiple calls
  Future<String> getUserRole() async {
    // Return cached role if available and user hasn't changed
    if (_cachedUserRole != null) {
      return _cachedUserRole!;
    }
    
    // Check if it's a patient session first
    if (_currentPatientSession != null && _currentPatientSession!['isPatient'] == true) {
      _cachedUserRole = 'patient';
      return 'patient';
    }
    
    if (currentUser == null) {
      _cachedUserRole = 'patient';
      return 'patient';
    }
    
    try {
      // First check if user is a patient by email
      final patientData = await _databaseService.getPatientByEmail(currentUser!.email!);
      if (patientData != null) {
        _cachedUserRole = 'patient';
        return 'patient';
      }
      
      // Check in users collection for role
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      
      if (doc.exists && doc.data() != null) {
        final userData = doc.data()!;
        final role = userData['role'];
        if (role != null && role is String) {
          _cachedUserRole = role;
          return role;
        }
      }
      
      _cachedUserRole = 'patient';
      return 'patient'; // Default role if nothing found
    } catch (e) {
      print('Error getting user role: ${e.toString()}');
      _cachedUserRole = 'patient';
      return 'patient'; // Safe default
    }
  }
  
  // Get current user ID - SIMPLIFIED and SAFE with caching
  Future<String?> getCurrentUserId() async {
    // Return cached ID if available
    if (_cachedUserId != null) {
      return _cachedUserId;
    }
    
    // Check if it's a patient session first
    if (_currentPatientSession != null && _currentPatientSession!['isPatient'] == true) {
      _cachedUserId = _currentPatientSession!['patientId'];
      return _cachedUserId;
    }
    
    if (currentUser == null) return null;
    
    try {
      final role = await getUserRole();
      
      if (role == 'patient') {
        // For patients, get their IC number from database
        final patientData = await _databaseService.getPatientByEmail(currentUser!.email!);
        _cachedUserId = patientData?['patientId']; // This is their IC number
        return _cachedUserId;
      } else {
        // For doctors, nurses, pharmacists - use Firebase UID
        _cachedUserId = currentUser!.uid;
        return _cachedUserId;
      }
    } catch (e) {
      print('Error getting current user ID: ${e.toString()}');
      _cachedUserId = currentUser!.uid; // Fallback to Firebase UID
      return _cachedUserId;
    }
  }
  
  // Get current doctor ID (for doctors only)
  Future<String?> getCurrentDoctorId() async {
    if (currentUser == null) return null;
    
    try {
      final role = await getUserRole();
      if (role == 'doctor') {
        return currentUser!.uid; // Use Firebase UID as doctor ID
      }
      return null;
    } catch (e) {
      print('Error getting doctor ID: ${e.toString()}');
      return null;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile(String name, String? photoUrl) async {
    if (currentUser == null) return;
    
    try {
      // Update display name and photo in Auth
      await currentUser!.updateDisplayName(name);
      if (photoUrl != null) {
        await currentUser!.updatePhotoURL(photoUrl);
      }
      
      // Get user role to determine which collection to update
      final role = await getUserRole();
      
      if (role == 'patient') {
        // For patients, update in patients collection using IC
        final patientData = await _databaseService.getPatientByEmail(currentUser!.email!);
        if (patientData != null) {
          await _firestore.collection('patients').doc(patientData['patientId']).update({
            'name': name,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Update in users collection
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'name': name,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update in role-specific collection
        if (role == 'doctor') {
          await _firestore.collection('doctors').doc(currentUser!.uid).update({
            'name': name,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (role == 'nurse') {
          await _firestore.collection('nurses').doc(currentUser!.uid).update({
            'name': name,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (role == 'pharmacist') {
          await _firestore.collection('pharmacists').doc(currentUser!.uid).update({
            'name': name,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Error updating profile: ${e.toString()}');
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: ${e.toString()}');
      rethrow;
    }
  }
  
  // Get doctor information for UI display
  Future<Map<String, dynamic>?> getCurrentDoctorInfo() async {
    try {
      final role = await getUserRole();
      if (role == 'doctor' && currentUser != null) {
        return await _databaseService.getDoctorById(currentUser!.uid);
      }
      return null;
    } catch (e) {
      print('Error getting doctor info: ${e.toString()}');
      return null;
    }
  }
  
  // Get nurse information for UI display
  Future<Map<String, dynamic>?> getCurrentNurseInfo() async {
    try {
      final role = await getUserRole();
      if (role == 'nurse' && currentUser != null) {
        final doc = await _firestore.collection('nurses').doc(currentUser!.uid).get();
        if (doc.exists) {
          return doc.data() as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error getting nurse info: ${e.toString()}');
      return null;
    }
  }
  
  // Get pharmacist information for UI display
  Future<Map<String, dynamic>?> getCurrentPharmacistInfo() async {
    try {
      final role = await getUserRole();
      if (role == 'pharmacist' && currentUser != null) {
        final doc = await _firestore.collection('pharmacists').doc(currentUser!.uid).get();
        if (doc.exists) {
          return doc.data() as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error getting pharmacist info: ${e.toString()}');
      return null;
    }
  }
  
  // Check if user exists (for duplicate email prevention)
  Future<bool> checkUserExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print('Error checking if user exists: ${e.toString()}');
      return false;
    }
  }
  
  // Update doctor specialization (for doctors to update their profile)
  Future<void> updateDoctorSpecialization(String specialization, String department) async {
    if (currentUser == null) return;
    
    try {
      final role = await getUserRole();
      if (role == 'doctor') {
        await _firestore.collection('doctors').doc(currentUser!.uid).update({
          'specialization': specialization,
          'department': department,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        notifyListeners();
      }
    } catch (e) {
      print('Error updating doctor specialization: ${e.toString()}');
      rethrow;
    }
  }
}