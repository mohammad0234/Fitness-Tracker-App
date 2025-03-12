import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'screens/onboarding_screen.dart';
import 'screens/signup_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/verification_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Check if onboarding has been seen
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  
  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  
  const MyApp({super.key, required this.seenOnboarding});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitJourney',
      debugShowCheckedModeBanner: false,
      initialRoute: seenOnboarding ? '/login' : '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/signup': (context) => const SignUpPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/verification-pending': (context) => const VerificationPendingPage(),
      },
    );
  }
}