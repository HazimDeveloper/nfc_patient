import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
        
        // Create role-specific document
        await _firestore.collection(role + 's').doc(user.uid).set({
          'userId': user.uid,
          'email': email,
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
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
  
  // Update user profile
  Future<void> updateUserProfile(String name, String? photoUrl) async {
    if (currentUser == null) return;
    
    try {
      // Update display name and photo in Auth
      await currentUser!.updateDisplayName(name);
      if (photoUrl != null) {
        await currentUser!.updatePhotoURL(photoUrl);
      }
      
      // Update in Firestore
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Get user role
      final role = await getUserRole();
      
      // Update in role-specific collection
      await _firestore.collection(role + 's').doc(currentUser!.uid).update({
        'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
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
}