// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:fitjourney/screens/calendar_streak_screen.dart';
import 'package:fitjourney/services/notification_service.dart'; // ✅ Added
import 'log_workout_flow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isLoadingStreak = true;
  int _currentStreak = 0;
  bool _isLoggingRestDay = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchStreakData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;

      final dbUser = await DatabaseHelper.instance.getUserById(uid);

      if (dbUser == null) {
        try {
          final docSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('profile')
              .doc(uid)
              .get();

          if (docSnapshot.exists) {
            final userData = docSnapshot.data();
            if (userData != null) {
              final appUser = AppUser(
                userId: uid,
                firstName: userData['first_name'] ?? userData['firstName'],
                lastName: userData['last_name'] ?? userData['lastName'],
                heightCm: userData['height_cm'] ?? userData['heightCm'],
                registrationDate: userData['registration_date'] != null
                    ? DateTime.parse(userData['registration_date'])
                    : (userData['registrationDate'] != null
                        ? DateTime.parse(userData['registrationDate'])
                        : null),
                lastLogin: userData['last_login'] != null
                    ? DateTime.parse(userData['last_login'])
                    : (userData['lastLogin'] != null
                        ? DateTime.parse(userData['lastLogin'])
                        : null),
              );

              await DatabaseHelper.instance.insertUser(appUser);

              setState(() {
                _currentUser = appUser;
                _isLoading = false;
              });
              return;
            }
          }
        } catch (e) {
          print('Error fetching from Firestore: $e');
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentUser = dbUser;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStreakData() async {
    setState(() {
      _isLoadingStreak = true;
    });

    try {
      final streak = await StreakService.instance.getUserStreak();
      setState(() {
        _currentStreak = streak.currentStreak;
        _isLoadingStreak = false;
      });
    } catch (e) {
      print('Error fetching streak: $e');
      setState(() {
        _isLoadingStreak = false;
      });
    }
  }

  Future<void> _testNotification() async {
  try {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await NotificationService.instance.scheduleNotification(
      id: id,
      title: 'Test Notification',
      body: 'This is a test notification from FitJourney app',
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.streakCategory,
      payload: 'test_notification',
    );

    // ✅ Save to in-app notification table
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await DatabaseHelper.instance.insertNotification({
        'user_id': userId,
        'type': 'NewStreak', // Choose an appropriate type
        'message': 'This is a test notification from FitJourney app',
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification scheduled! Check your notification area in 5 seconds.'),
        duration: Duration(seconds: 3),
      ),
    );

    print('Test notification scheduled with ID: $id');
  } catch (e) {
    print('Error scheduling test notification: $e');

    if (e.toString().contains('exact_alarms_not_permitted')) {
      await NotificationService.instance.openExactAlarmSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please allow "Schedule exact alarms" in settings.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scheduling notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}



  Future<void> _logRestDay() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Log Rest Day'),
          content: const Text(
            'Logging a rest day will maintain your current streak. Are you sure you want to log today as a rest day?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('LOG REST DAY'),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) return;

      setState(() {
        _isLoggingRestDay = true;
      });

      await StreakService.instance.logRestDay(DateTime.now());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rest day logged successfully')),
      );

      _fetchStreakData();
    } catch (e) {
      print('Error logging rest day: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging rest day: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingRestDay = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUser == null) {
      return const Center(child: Text("No user data found."));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                Text(
                  '${_currentUser!.firstName} ${_currentUser!.lastName}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.local_fire_department,
                                color: Colors.green.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Streak',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                ),
                                if (_isLoadingStreak)
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Text(
                                    '$_currentStreak Days',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CalendarStreakScreen()),
                          ).then((_) => _fetchStreakData());
                        },
                        tooltip: 'View Calendar',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debug Tools',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use this button to test if notifications are working properly',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _testNotification,
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Test Notification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Workout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upper Body',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text('7h ago', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('45 minutes', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                          const SizedBox(width: 16),
                          const Icon(Icons.fitness_center, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('8 exercises', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LogWorkoutFlow()),
                      ).then((_) => _fetchStreakData());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Log Workout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingRestDay ? null : _logRestDay,
                    icon: _isLoggingRestDay
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bedtime_outlined),
                    label: const Text('Log Rest Day'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
