import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'screens/signup_page.dart'; // Import your SignUpPage

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitJourney',
      debugShowCheckedModeBanner: false,
      initialRoute: '/', // Start at the onboarding screen
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/signup': (context) => const SignUpPage(),
      },
    );
  }
}
