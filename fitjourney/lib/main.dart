import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Generated by flutterfire configure

import 'screens/onboarding_screen.dart';
import 'screens/signup_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart'; // Placeholder HomePage

Future<void> main() async {
  // Ensure Flutter binding is initialized before using any plugins.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with the generated options for the current platform.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Now run the app.
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
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(), // Placeholder home screen
      },
    );
  }
}
