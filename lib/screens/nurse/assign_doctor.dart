import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/services/database_service.dart';

class AssignDoctorScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const AssignDoctorScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  _AssignDoctorScreenState createState() => _AssignDoctorScreenState();
}

class _AssignDoctorScreenState extends State<AssignDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  String? _selectedDoctorId;
  String? _selectedRoom;
  
  List<Map<String, dynamic>> _doctors = [];
  List<String> _availableRooms = [
    'A101', 'A102', 'A103', 'A104', 'A105',
    'B101', 'B102', 'B103', 'B104', 'B105',
    'C101', 'C102', 'C103', 'C104', 'C105',
  ];
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Load all doctors from database
  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final databaseService = DatabaseService();
      final doctors = await databaseService.getAllDoctors();
      
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading doctors: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Assign doctor and room to patient
  Future<void> _assignDoctorAndRoom() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a doctor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a consultation room'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final databaseService = DatabaseService();
      await databaseService.assignRoomAndDoctor(
        patientId: widget.patientId,
        roomNumber: _selectedRoom!,
        doctorId: _selectedDoctorId!,
        appointmentNotes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Doctor & Room',style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Patient info
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          Divider(),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Name:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.patientName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.numbers,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ID:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.patientId,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Doctor selection
                  Text(
                    'Select Doctor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Divider(),
                  SizedBox(height: 8),

                  // List of doctors with radio buttons
                  ...List.generate(
                    _doctors.length,
                    (index) => _buildDoctorSelectionTile(_doctors[index]),
                  ),

                  SizedBox(height: 24),

                  // Room selection
                  Text(
                    'Select Consultation Room',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Divider(),
                  SizedBox(height: 8),

                  // Dropdown for room selection
                  DropdownButtonFormField<String>(
                    value: _selectedRoom,
                    decoration: InputDecoration(
                      labelText: 'Consultation Room',
                      prefixIcon: Icon(Icons.meeting_room),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _availableRooms.map((room) {
                      return DropdownMenuItem(
                        value: room,
                        child: Text(room),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRoom = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a room';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                  ),

                  SizedBox(height: 24),

                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Submit button
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _assignDoctorAndRoom,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(Icons.check),
                    label: Text('Assign Doctor & Room'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDoctorSelectionTile(Map<String, dynamic> doctor) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: RadioListTile<String>(
        title: Text(
          doctor['name'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (doctor['specialization'] != null)
              Text('Specialty: ${doctor['specialization']}'),
            if (doctor['department'] != null)
              Text('Department: ${doctor['department']}'),
          ],
        ),
        value: doctor['userId'] ?? '',
        groupValue: _selectedDoctorId,
        onChanged: (value) {
          setState(() {
            _selectedDoctorId = value;
          });
        },
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}