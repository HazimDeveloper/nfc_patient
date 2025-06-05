import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:nfc_patient_registration/config/firebase_config.dart';
import 'package:nfc_patient_registration/services/auth_service.dart';
import 'package:nfc_patient_registration/screens/login_screen.dart';
import 'package:nfc_patient_registration/screens/patient/patient_home.dart';
import 'package:nfc_patient_registration/screens/doctor/doctor_home.dart';
import 'package:nfc_patient_registration/screens/nurse/nurse_home.dart';
import 'package:nfc_patient_registration/screens/pharmacist/pharmacist_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseConfig.platformOptions,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NFC Patient Registration',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.teal,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: AuthWrapper(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/patient': (context) => PatientHome(),
          '/doctor': (context) => DoctorHome(),
          '/nurse': (context) => NurseHome(),
          '/pharmacist': (context) => PharmacistHome(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;
  String? _userRole;
  bool _isLoadingRole = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Simple initialization - just mark as initialized after a small delay
      await Future.delayed(Duration(milliseconds: 500)); // Small delay for smooth transition
      
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('Error initializing app: $e');
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }

  Future<void> _loadUserRole(AuthService authService) async {
    // Prevent multiple simultaneous calls
    if (_isLoadingRole) return;
    
    setState(() {
      _isLoadingRole = true;
    });
    
    try {
      final role = await authService.getUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      print('Error getting user role: $e');
      if (mounted) {
        setState(() {
          _userRole = 'patient'; // Default fallback
          _isLoadingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen during app initialization
    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing Hospital System...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Check authentication status
        final currentUser = authService.currentUser;
        final hasPatientSession = authService.currentPatientSession != null;
        
        // If no user is logged in, show login screen
        if (currentUser == null && !hasPatientSession) {
          // Reset role state when user logs out
          if (_userRole != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _userRole = null;
                _isLoadingRole = false;
              });
            });
          }
          return LoginScreen();
        }
        
        // If patient session exists, go directly to patient home
        if (hasPatientSession) {
          return PatientHome();
        }
        
        // For Firebase authenticated users, determine role
        if (currentUser != null) {
          // If we don't have the role yet and we're not currently loading it, start loading
          if (_userRole == null && !_isLoadingRole) {
            // Use post frame callback to avoid calling setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadUserRole(authService);
            });
          }
          
          // Show loading while determining role
          if (_isLoadingRole || _userRole == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Checking your credentials...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Navigate to appropriate home screen based on role
          switch (_userRole) {
            case 'doctor':
              return DoctorHome();
            case 'nurse':
              return NurseHome();
            case 'pharmacist':
              return PharmacistHome();
            case 'patient':
            default:
              return PatientHome();
          }
        }
        
        // Fallback - should not reach here, but show login if it does
        return LoginScreen();
      },
    );
  }
}