import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/services/goal_tracking_service.dart';
import 'package:fitjourney/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io'; // Add this for Platform checks
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'screens/signup_page.dart';
import 'screens/login_page.dart';
import 'screens/main_scaffold.dart';
import 'screens/verification_page.dart';
import 'package:fitjourney/services/notification_trigger_service.dart';
import 'package:fitjourney/services/progress_service.dart';
import 'package:fitjourney/screens/notification_screen.dart';
import 'package:fitjourney/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firestore settings
  FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

  // Initialize notification service
  await NotificationService.instance.init();

  // Request notification permissions
  await requestNotificationPermissions();

  // Initialize exercise database
  await WorkoutService.instance.initializeExercises();
  await GoalTrackingService.instance.performDailyGoalUpdate();

  // Initialize sync service
  try {
    print('Starting sync service initialization');
    await SyncService.instance.initialize();
    print('Sync service initialization completed');

    // Force include streak in sync queue on startup
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await SyncService.instance.forceAddStreakToSyncQueue();
      print('Added streak to sync queue on startup');
    }
  } catch (e) {
    print('Error initializing sync service: $e');
    // Continue with app startup even if sync service fails
  }

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await StreakService.instance.performDailyStreakCheck();

      // Schedule daily streak maintenance notifications
      await NotificationTriggerService.instance.scheduleDailyStreakCheck();

      // Check for inactivity
      final progressSummary =
          await ProgressService.instance.getProgressSummary();
      final daysSinceLastWorkout =
          progressSummary['daysSinceLastWorkout'] as int?;

      if (daysSinceLastWorkout != null && daysSinceLastWorkout >= 3) {
        await NotificationTriggerService.instance
            .scheduleInactivityReminder(daysSinceLastWorkout);
      }
    }
  } catch (e) {
    print('Error performing notification checks: $e');
    // Continue with app startup even if this fails
  }

  runApp(const MyApp());
}

// Add this function to request notification permissions
Future<void> requestNotificationPermissions() async {
  // Only needed for Android 13+ (SDK 33+)
  if (Platform.isAndroid) {
    try {
      final androidImplementation = NotificationService
          .instance.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted =
            await androidImplementation.requestNotificationsPermission();
        debugPrint('Notification permission granted: $granted');
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      initialRoute: '/signup',
      routes: {
        '/signup': (context) => const SignUpPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainScaffold(),
        '/verification-pending': (context) => const VerificationPendingPage(),
        '/notifications': (context) => const NotificationScreen(),
      },
    );
  }
}
