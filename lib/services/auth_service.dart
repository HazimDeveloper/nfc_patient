import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nfc_patient_registration/services/database_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  
  // Get auth state changes
  Stream<User?> get user => _auth.authStateChanges();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
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
  
  // Register with email and password
  Future<User?> registerWithEmailAndPassword(
    String email, 
    String password, 
    String name, 
    String role
  ) async {
    try {
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
        
        // For non-patient roles, create role-specific document
        if (role != 'patient') {
          await _firestore.collection(role + 's').doc(user.uid).set({
            'userId': user.uid,
            'email': email,
            'name': name,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        notifyListeners();
      }
      
      return user;
    } catch (e) {
      print('Error registering: ${e.toString()}');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
  
  // Get user role from Firestore
  Future<String> getUserRole() async {
    if (currentUser == null) return 'patient'; // Default role
    
    try {
      // First check if user is a patient by email
      final patientData = await _databaseService.getPatientByEmail(currentUser!.email!);
      if (patientData != null) {
        return 'patient';
      }
      
      // Check if user is a doctor by email mapping
      final doctorId = _mapEmailToDoctorId(currentUser!.email!);
      if (doctorId != null) {
        return 'doctor';
      }
      
      // Check in users collection for other roles
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      
      if (doc.exists) {
        return doc.data()?['role'] ?? 'patient';
      }
      
      return 'patient'; // Default role if no document
    } catch (e) {
      print('Error getting user role: ${e.toString()}');
      return 'patient'; // Default role on error
    }
  }
  
  // Map email to doctor ID - this should match your doctor system
  String? _mapEmailToDoctorId(String email) {
    switch (email) {
      case 'doctor1@hospital.com':
        return 'doctor1';
      case 'doctor2@hospital.com':
        return 'doctor2';
      case 'doctor3@hospital.com':
        return 'doctor3';
      default:
        return null;
    }
  }
  
  // Get current user ID - for patients, use their IC number; for doctors, use mapped ID
  Future<String?> getCurrentUserId() async {
    if (currentUser == null) return null;
    
    try {
      final role = await getUserRole();
      
      if (role == 'patient') {
        // For patients, get their IC number (patientId) from the database
        final patientData = await _databaseService.getPatientByEmail(currentUser!.email!);
        return patientData?['patientId']; // This is their IC number
      } else if (role == 'doctor') {
        // For doctors, use mapped doctor ID
        return _mapEmailToDoctorId(currentUser!.email!);
      } else {
        // For other roles, use Firebase Auth UID
        return currentUser!.uid;
      }
    } catch (e) {
      print('Error getting current user ID: ${e.toString()}');
      return currentUser!.uid; // Fallback to Auth UID
    }
  }
  
  // Get current doctor ID (specifically for doctors)
  Future<String?> getCurrentDoctorId() async {
    if (currentUser == null) return null;
    
    try {
      final role = await getUserRole();
      if (role == 'doctor') {
        return _mapEmailToDoctorId(currentUser!.email!);
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
      } else if (role == 'doctor') {
        // For doctors, update in the doctors collection using mapped ID
        final doctorId = _mapEmailToDoctorId(currentUser!.email!);
        if (doctorId != null) {
          await _firestore.collection('doctors').doc(doctorId).update({
            'name': name,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
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
        await _firestore.collection(role + 's').doc(currentUser!.uid).update({
          'name': name,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      notifyListeners();
    } catch (e) {
      print('Error updating profile: ${e.toString()}');
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
  
  // Initialize default doctors and create their auth accounts
  Future<void> initializeDefaultData() async {
    try {
      await _databaseService.initializeDefaultDoctors();
      
      // Create default doctor accounts if they don't exist
      await _createDefaultDoctorAccounts();
    } catch (e) {
      print('Error initializing default data: ${e.toString()}');
    }
  }
  
  // Create default doctor accounts for testing
  Future<void> _createDefaultDoctorAccounts() async {
    final defaultDoctors = [
      {
        'email': 'doctor1@hospital.com',
        'password': 'doctor123',
        'name': 'Dr. Ahmad Rahman',
        'role': 'doctor',
      },
      {
        'email': 'doctor2@hospital.com',
        'password': 'doctor123',
        'name': 'Dr. Siti Aminah',
        'role': 'doctor',
      },
      {
        'email': 'doctor3@hospital.com',
        'password': 'doctor123',
        'name': 'Dr. Kumar Raj',
        'role': 'doctor',
      },
    ];
    
    for (final doctorInfo in defaultDoctors) {
      try {
        // Check if doctor account already exists
        final existingUser = await _checkUserExists(doctorInfo['email']!);
        
        if (!existingUser) {
          // Create the doctor account
          await _createDoctorAccount(
            doctorInfo['email']!,
            doctorInfo['password']!,
            doctorInfo['name']!,
          );
          print('Created default doctor account: ${doctorInfo['email']}');
        }
      } catch (e) {
        print('Error creating doctor account ${doctorInfo['email']}: $e');
        // Continue with next doctor even if one fails
      }
    }
  }
  
  // Check if user exists
  Future<bool> _checkUserExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // Create a doctor account
  Future<void> _createDoctorAccount(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        // Create user document
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'name': name,
          'role': 'doctor',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Update display name
        await userCredential.user!.updateDisplayName(name);
        
        print('Successfully created doctor account: $email');
      }
    } catch (e) {
      print('Error creating doctor account: $e');
      rethrow;
    }
  }
  
  // Get doctor information for UI display
  Future<Map<String, dynamic>?> getCurrentDoctorInfo() async {
    try {
      final doctorId = await getCurrentDoctorId();
      if (doctorId != null) {
        return await _databaseService.getDoctorById(doctorId);
      }
      return null;
    } catch (e) {
      print('Error getting doctor info: ${e.toString()}');
      return null;
    }
  }
}