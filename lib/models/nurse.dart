import 'package:cloud_firestore/cloud_firestore.dart';

class Nurse {
  final String nurseId;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? department;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Nurse({
    required this.nurseId,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.department,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  // Create Nurse object from Firestore document
  factory Nurse.fromFirestore(Map<String, dynamic> data, String docId) {
    return Nurse(
      nurseId: docId,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      department: data['department'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert Nurse object to a Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}