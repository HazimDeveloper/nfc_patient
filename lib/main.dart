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

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder(
      stream: authService.user,
      builder: (_, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          }
          
          // Check user role and redirect accordingly
          return FutureBuilder(
            future: authService.getUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.done) {
                final String role = roleSnapshot.data ?? 'patient';
                
                switch (role) {
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
              
              // While determining role, show loading
              return Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          );
        }
        
        // Connection to auth state not yet established
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}