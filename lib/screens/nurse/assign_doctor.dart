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
  
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
      await _databaseService.assignRoomAndDoctor(
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
    final availableRooms = _databaseService.getAvailableRooms();
    final availableDoctors = _databaseService.getAvailableDoctors();

    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Doctor & Room', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Form(
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
                          'IC Number:',
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
            ...availableDoctors.map((doctor) => _buildDoctorSelectionTile(doctor)),

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

            // Room selection buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableRooms.map((room) {
                final isSelected = _selectedRoom == room;
                return FilterChip(
                  label: Text(room),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedRoom = selected ? room : null;
                    });
                  },
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                );
              }).toList(),
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
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red[800],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildDoctorSelectionTile(Map<String, String> doctor) {
    final isSelected = _selectedDoctorId == doctor['id'];
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDoctorId = doctor['id'];
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey[300],
                child: Icon(
                  Icons.local_hospital,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor['name']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Specialty: ${doctor['specialization']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}