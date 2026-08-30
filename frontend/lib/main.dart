import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/root_nav.dart';

void main() {
  runApp(const SkyHighApp());
}

class SkyHighApp extends StatelessWidget {
  const SkyHighApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marketing Intelligence Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RootNav(),
    );
  }
}
