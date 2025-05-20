import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String patientId;
  final String name;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String? bloodType;
  final String? emergencyContact;
  final List<String> allergies;
  final List<String> medications;
  final List<String> conditions;
  final DateTime registrationDate;
  final DateTime lastUpdated;
  final String? currentAppointment;
  
  Patient({
    required this.patientId,
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    this.bloodType,
    this.emergencyContact,
    required this.allergies,
    required this.medications,
    required this.conditions,
    required this.registrationDate,
    required this.lastUpdated,
    this.currentAppointment,
  });
  
  // Create Patient object from Firestore document
  factory Patient.fromFirestore(Map<String, dynamic> data) {
    return Patient(
      patientId: data['patientId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      dateOfBirth: data['dateOfBirth'] ?? '',
      gender: data['gender'] ?? '',
      address: data['address'] ?? '',
      bloodType: data['bloodType'],
      emergencyContact: data['emergencyContact'],
      allergies: List<String>.from(data['allergies'] ?? []),
      medications: List<String>.from(data['medications'] ?? []),
      conditions: List<String>.from(data['conditions'] ?? []),
      registrationDate: (data['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentAppointment: data['currentAppointment'],
    );
  }
  
  // Convert Patient object to a Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'name': name,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'address': address,
      'bloodType': bloodType,
      'emergencyContact': emergencyContact,
      'allergies': allergies,
      'medications': medications,
      'conditions': conditions,
      'registrationDate': registrationDate,
      'lastUpdated': lastUpdated,
      'currentAppointment': currentAppointment,
    };
  }
  
  // Convert to Map for NFC card (minimal data)
  Map<String, dynamic> toNfcData() {
    return {
      'patientId': patientId,
      'name': name,
      'dateOfBirth': dateOfBirth,
    };
  }
}