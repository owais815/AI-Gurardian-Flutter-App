import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ai_guardian_parent/pages/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.blueGrey[100]),
      home: const OnboardingScreen(),
    );
  }
}
