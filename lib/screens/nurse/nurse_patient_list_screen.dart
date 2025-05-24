import 'package:flutter/material.dart';
import 'package:nfc_patient_registration/screens/nurse/patient_detail_screen.dart' show PatientDetailsScreen;
import 'package:nfc_patient_registration/services/database_service.dart';
import 'package:nfc_patient_registration/screens/nurse/assign_doctor.dart';

class NursePatientListScreen extends StatefulWidget {
  @override
  _NursePatientListScreenState createState() => _NursePatientListScreenState();
}

class _NursePatientListScreenState extends State<NursePatientListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, assigned, unassigned
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllPatients();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterPatients();
    });
  }

  void _filterPatients() {
    List<Map<String, dynamic>> tempList = List.from(_allPatients);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      tempList = tempList.where((patient) {
        final name = patient['name']?.toString().toLowerCase() ?? '';
        final id = patient['patientId']?.toString().toLowerCase() ?? '';
        final email = patient['email']?.toString().toLowerCase() ?? '';
        final phone = patient['phone']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        
        return name.contains(query) || 
               id.contains(query) || 
               email.contains(query) || 
               phone.contains(query);
      }).toList();
    }
    
    // Apply status filter
    switch (_selectedFilter) {
      case 'assigned':
        tempList = tempList.where((patient) => 
          patient['currentAppointment'] != null).toList();
        break;
      case 'unassigned':
        tempList = tempList.where((patient) => 
          patient['currentAppointment'] == null).toList();
        break;
      case 'all':
      default:
        // No additional filtering
        break;
    }
    
    setState(() {
      _filteredPatients = tempList;
    });
  }

  // Load all registered patients
  Future<void> _loadAllPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all patients (both assigned and unassigned)
      final newPatients = await _databaseService.getNewPatients();
      final assignedPatients = await _databaseService.getAllAssignedPatients();
      
      // Combine both lists and remove duplicates
      final allPatients = <String, Map<String, dynamic>>{};
      
      for (var patient in newPatients) {
        allPatients[patient['patientId']] = patient;
      }
      
      for (var patient in assignedPatients) {
        allPatients[patient['patientId']] = patient;
      }
      
      // Sort by registration date (newest first)
      final patientsList = allPatients.values.toList();
      patientsList.sort((a, b) {
        final aDate = a['registrationDate']?.toDate() ?? DateTime.now();
        final bDate = b['registrationDate']?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      
      setState(() {
        _allPatients = patientsList;
        _filterPatients();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading patients: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Patients', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllPatients,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey.withOpacity(0.1),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, email, or phone',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                SizedBox(height: 12),
                
                // Filter chips
                Row(
                  children: [
                    Text(
                      'Filter: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all'),
                            SizedBox(width: 8),
                            _buildFilterChip('Assigned to Doctor', 'assigned'),
                            SizedBox(width: 8),
                            _buildFilterChip('Unassigned', 'unassigned'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Patient count info
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Patients: ${_allPatients.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'Showing: ${_filteredPatients.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Patients list
          Expanded(
            child: _buildPatientsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _filterPatients();
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildPatientsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading patients...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllPatients,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_filteredPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? Icons.search_off
                  : Icons.people_outline,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'No patients match your search criteria'
                  : 'No patients registered yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _selectedFilter != 'all') ...[
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedFilter = 'all';
                    _filterPatients();
                  });
                },
                icon: Icon(Icons.clear_all),
                label: Text('Clear Filters'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        final patient = _filteredPatients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final registrationDate = patient['registrationDate']?.toDate();
    final formattedDate = registrationDate != null
        ? '${registrationDate.day}/${registrationDate.month}/${registrationDate.year}'
        : 'Unknown';
    
    final isAssigned = patient['currentAppointment'] != null;
    final hasCardSerial = patient['cardSerialNumber'] != null && 
                         patient['cardSerialNumber'].toString().isNotEmpty;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDetailsScreen(
                patient: patient,
              ),
            ),
          ).then((_) => _loadAllPatients());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient name and status
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      patient['name']?.substring(0, 1).toUpperCase() ?? 'P',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ID: ${patient['patientId'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isAssigned 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAssigned ? 'Assigned' : 'Unassigned',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAssigned ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (hasCardSerial) ...[
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.contactless,
                              size: 16,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'NFC',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Divider(height: 24),
              
              // Patient details
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: 'DOB',
                value: patient['dateOfBirth'] ?? 'Not recorded',
              ),
              _buildInfoRow(
                icon: Icons.wc,
                label: 'Gender',
                value: patient['gender'] ?? 'Not recorded',
              ),
              _buildInfoRow(
                icon: Icons.phone,
                label: 'Phone',
                value: patient['phone'] ?? 'Not recorded',
              ),
              _buildInfoRow(
                icon: Icons.email,
                label: 'Email',
                value: patient['email'] ?? 'Not recorded',
              ),
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Registered',
                value: formattedDate,
              ),
              
              SizedBox(height: 16),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientDetailsScreen(
                            patient: patient,
                          ),
                        ),
                      ).then((_) => _loadAllPatients());
                    },
                    icon: Icon(Icons.visibility),
                    label: Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  if (!isAssigned) ...[
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AssignDoctorScreen(
                              patientId: patient['patientId'],
                              patientName: patient['name'],
                            ),
                          ),
                        ).then((_) => _loadAllPatients());
                      },
                      icon: Icon(Icons.assignment_ind),
                      label: Text('Assign'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}