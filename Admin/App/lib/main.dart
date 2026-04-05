import 'package:flutter/material.dart';

import 'screens/case_list_screen.dart';

void main() {
  runApp(const SentinelAdminApp());
}

class SentinelAdminApp extends StatelessWidget {
  const SentinelAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F8A70),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        useMaterial3: true,
      ),
      home: const CaseListScreen(),
    );
  }
}
