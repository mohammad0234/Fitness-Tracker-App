import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitJourney',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
      routes: {
        // Example route after finishing onboarding
        '/signup': (context) => const Placeholder(
              child: Center(child: Text('Sign Up Screen Placeholder')),
            ),
      },
    );
  }
}
