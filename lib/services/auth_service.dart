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
  
  // Get current user ID - for patients, use their IC number
  Future<String?> getCurrentUserId() async {
    if (currentUser == null) return null;
    
    try {
      final role = await getUserRole();
      
      if (role == 'patient') {
        // For patients, get their IC number (patientId) from the database
        final patientData = await _databaseService.getPatientByEmail(currentUser!.email!);
        return patientData?['patientId']; // This is their IC number
      } else {
        // For other roles, use Firebase Auth UID
        return currentUser!.uid;
      }
    } catch (e) {
      print('Error getting current user ID: ${e.toString()}');
      return currentUser!.uid; // Fallback to Auth UID
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
  
  // Initialize default doctors (call this once during app setup)
  Future<void> initializeDefaultData() async {
    try {
      await _databaseService.initializeDefaultDoctors();
    } catch (e) {
      print('Error initializing default data: ${e.toString()}');
    }
  }
}