import 'package:flutter/material.dart';
import 'screens/client_page.dart';
import 'services/app_state.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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