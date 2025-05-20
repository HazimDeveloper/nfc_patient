import 'package:cloud_firestore/cloud_firestore.dart';

class Pharmacist {
  final String pharmacistId;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? department;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Pharmacist({
    required this.pharmacistId,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.department,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  // Create Pharmacist object from Firestore document
  factory Pharmacist.fromFirestore(Map<String, dynamic> data, String docId) {
    return Pharmacist(
      pharmacistId: docId,
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

  // Convert Pharmacist object to a Firestore document
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