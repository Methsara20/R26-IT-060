import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/client_page.dart';
import 'services/app_state.dart';

import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyD83DKTM1b1rHWFMdGo--vM1oZ_PG_0GNg",
        appId: "1:171031337876:web:2abf01e25ddebdc9e4cd81",
        messagingSenderId: "171031337876",
        projectId: "finalyear-6bafb",
        authDomain: "finalyear-6bafb.firebaseapp.com",
        storageBucket: "finalyear-6bafb.firebasestorage.app",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState(),
      builder: (context, child) {
        return MaterialApp(
          title: 'Retail App',
          debugShowCheckedModeBanner: false,
          home: const ClientPage(),
        );
      },
    );
  }
}