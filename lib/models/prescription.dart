import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String name;
  final String dosage;
  final String frequency;
  final int duration; // in days
  final String? instructions;

  Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  factory Medication.fromMap(Map<String, dynamic> data) {
    return Medication(
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      frequency: data['frequency'] ?? '',
      duration: data['duration'] ?? 0,
      instructions: data['instructions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
    };
  }
}

class Prescription {
  final String prescriptionId;
  final String patientId;
  final String doctorId;
  final List<Medication> medications;
  final String diagnosis;
  final String? notes;
  final String status; // pending, dispensed, completed
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional data for UI display (not stored in Firestore)
  final String? patientName;
  final String? doctorName;

  Prescription({
    required this.prescriptionId,
    required this.patientId,
    required this.doctorId,
    required this.medications,
    required this.diagnosis,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.patientName,
    this.doctorName,
  });

  // Create Prescription object from Firestore document
  factory Prescription.fromFirestore(Map<String, dynamic> data, String docId) {
    // Convert medications list
    List<Medication> medicationsList = [];
    if (data['medications'] != null) {
      medicationsList = (data['medications'] as List)
          .map((med) => Medication.fromMap(med))
          .toList();
    }

    return Prescription(
      prescriptionId: docId,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      medications: medicationsList,
      diagnosis: data['diagnosis'] ?? '',
      notes: data['notes'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      patientName: data['patientName'],
      doctorName: data['doctorName'],
    );
  }

  // Convert Prescription object to a Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'medications': medications.map((med) => med.toMap()).toList(),
      'diagnosis': diagnosis,
      'notes': notes,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}