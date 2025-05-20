import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String doctorId;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? specialization;
  final String? department;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Doctor({
    required this.doctorId,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.specialization,
    this.department,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  // Create Doctor object from Firestore document
  factory Doctor.fromFirestore(Map<String, dynamic> data, String docId) {
    return Doctor(
      doctorId: docId,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      specialization: data['specialization'],
      department: data['department'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert Doctor object to a Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'specialization': specialization,
      'department': department,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}