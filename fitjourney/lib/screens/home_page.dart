import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart';
import 'package:fitjourney/services/streak_service.dart';
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

  /// Fetches the current user's data from SQLite first, then tries Firestore if needed
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      
      // Try SQLite first
      final dbUser = await DatabaseHelper.instance.getUserById(uid);
      
      if (dbUser == null) {
        // If not in SQLite, try Firestore
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
              
              // Save to SQLite for future use
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

  /// Fetches the user's current streak
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
  
  /// Log a rest day for the current user
  Future<void> _logRestDay() async {
    try {
      // Show a confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Log Rest Day'),
          content: const Text(
            'Logging a rest day will maintain your current streak. '
            'Are you sure you want to log today as a rest day?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), 
              child: const Text('CANCEL')
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), 
              child: const Text('LOG REST DAY')
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirm) return;
      
      // Show loading indicator
      setState(() {
        _isLoggingRestDay = true;
      });
      
      // Log the rest day using StreakService
      await StreakService.instance.logRestDay(DateTime.now());
      
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rest day logged successfully')),
      );
      
      // Refresh data to update streak display
      _fetchStreakData();
    } catch (e) {
      // Handle errors
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
                // Welcome section
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${_currentUser!.firstName} ${_currentUser!.lastName}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Current Streak Card
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Streak',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
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
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Recent Workout Section
                const Text(
                  'Recent Workout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '7h ago',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '45 minutes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.fitness_center, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '8 exercises',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Goals Progress Section
                const Text(
                  'Goals Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weekly Workouts Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Weekly Workouts'),
                          Text('4/5', style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Weight Goal Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Weight Goal'),
                          Text('15/20 kg', style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.75,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Log Workout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LogWorkoutFlow()),
                      ).then((_) {
                        // Refresh streak data when returning from workout logging
                        _fetchUserData();
                        _fetchStreakData();
                      });
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
                
                // Log Rest Day Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingRestDay ? null : _logRestDay,
                    icon: _isLoggingRestDay 
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2)
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