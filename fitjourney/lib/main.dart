import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitjourney/services/workout_service.dart'; 
import 'package:fitjourney/services/goal_tracking_service.dart'; 
import 'package:fitjourney/services/notification_service.dart'; 
import 'firebase_options.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/onboarding_screen.dart';
import 'screens/signup_page.dart';
import 'screens/login_page.dart';
import 'screens/main_scaffold.dart';
import 'screens/verification_page.dart';
import 'package:fitjourney/services/notification_trigger_service.dart';
import 'package:fitjourney/services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firestore settings
  FirebaseFirestore.instance.settings = 
      const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
      
  // Initialize notification service
  await NotificationService.instance.init();
      
  // Initialize exercise database
  await WorkoutService.instance.initializeExercises();
  await GoalTrackingService.instance.performDailyGoalUpdate();

  // Check if onboarding has been seen
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

   try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await StreakService.instance.performDailyStreakCheck();
      
      // Schedule daily streak maintenance notifications
      await NotificationTriggerService.instance.scheduleDailyStreakCheck();
      
      // Check for inactivity
      final progressSummary = await ProgressService.instance.getProgressSummary();
      final daysSinceLastWorkout = progressSummary['daysSinceLastWorkout'] as int?;
      
      if (daysSinceLastWorkout != null && daysSinceLastWorkout >= 3) {
        await NotificationTriggerService.instance.scheduleInactivityReminder(daysSinceLastWorkout);
      }
    }
  } catch (e) {
    print('Error performing notification checks: $e');
    // Continue with app startup even if this fails
  }
  
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
      theme: ThemeData(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: seenOnboarding ? '/login' : '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/signup': (context) => const SignUpPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainScaffold(), // Changed from HomePage to MainScaffold
        '/verification-pending': (context) => const VerificationPendingPage(),
      },
    );
  }
}