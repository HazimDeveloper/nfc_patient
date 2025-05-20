import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseConfig {
  static FirebaseOptions get platformOptions {
    if (kIsWeb) {
      // Web
      return const FirebaseOptions(
        apiKey: 'AIzaSyC7QA2eVV55VjU-lOQuKMoJZ0yQv_urjf4',
        appId: '1:637167634390:android:0a90d7e7207718db384677',
        messagingSenderId: '637167634390',
        projectId: 'nfcpatient-9e364',
        authDomain: 'nfcpatient-9e364.firebaseapp.com',
        storageBucket: 'nfcpatient-9e364.firebasestorage.app',
      );
    } else {
      // Android, iOS
      return const FirebaseOptions(
        apiKey: 'AIzaSyC7QA2eVV55VjU-lOQuKMoJZ0yQv_urjf4',
        appId: '1:637167634390:android:0a90d7e7207718db384677',
        messagingSenderId: '637167634390',
        projectId: 'nfcpatient-9e364',
        storageBucket: 'nfcpatient-9e364.firebasestorage.app',
      );
    }
  }
}