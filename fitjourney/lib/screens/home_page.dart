// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/screens/calendar_streak_screen.dart';
import 'package:fitjourney/screens/workout_detail_screen.dart';
import 'log_workout_flow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// New goal-related imports
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/screens/goal_detail_screen.dart';

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

  // Variables for the recent workout
  bool _isLoadingRecentWorkout = true;
  Map<String, dynamic>? _recentWorkoutData;

  // Variables for the active goal section
  bool _isLoadingGoal = true;
  Map<String, dynamic>? _activeGoalData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchStreakData();
    _fetchRecentWorkout();
    _fetchMostImportantGoal(); // Fetch the active goal
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
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

  Future<void> _fetchRecentWorkout() async {
    setState(() {
      _isLoadingRecentWorkout = true;
    });

    try {
      // Get all workouts for the user
      final workouts = await WorkoutService.instance.getUserWorkouts();

      if (workouts.isNotEmpty) {
        // The most recent workout will be first since they're ordered by date DESC
        final mostRecentWorkout = workouts.first;

        // Get detailed information about this workout
        final details = await WorkoutService.instance
            .getWorkoutDetails(mostRecentWorkout.workoutId!);

        // Extract exercise count and muscle groups
        final exerciseCount = (details['exercises'] as List).length;
        final muscleGroups = (details['exercises'] as List)
            .map((e) => e['muscle_group'] as String)
            .toSet()
            .toList();

        // Calculate how long ago this workout was
        final now = DateTime.now();
        final difference = now.difference(mostRecentWorkout.date);
        String timeAgo;

        if (difference.inDays > 0) {
          timeAgo = '${difference.inDays}d ago';
        } else if (difference.inHours > 0) {
          timeAgo = '${difference.inHours}h ago';
        } else {
          timeAgo = '${difference.inMinutes}m ago';
        }

        // Create a formatted object with the workout data
        setState(() {
          _recentWorkoutData = {
            'workout': mostRecentWorkout,
            'exerciseCount': exerciseCount,
            'muscleGroups': muscleGroups,
            'timeAgo': timeAgo,
            'workoutId': mostRecentWorkout.workoutId,
          };
          _isLoadingRecentWorkout = false;
        });
      } else {
        // No workouts found
        setState(() {
          _recentWorkoutData = null;
          _isLoadingRecentWorkout = false;
        });
      }
    } catch (e) {
      print('Error fetching recent workout: $e');
      setState(() {
        _recentWorkoutData = null;
        _isLoadingRecentWorkout = false;
      });
    }
  }

  // New method to fetch the most important active goal
  Future<void> _fetchMostImportantGoal() async {
    setState(() {
      _isLoadingGoal = true;
    });

    try {
      // Get active goals
      final activeGoals = await GoalService.instance.getActiveGoals();

      if (activeGoals.isNotEmpty) {
        // Sort goals by closest deadline
        activeGoals.sort((a, b) => a.endDate.compareTo(b.endDate));

        // Get the most important goal (closest to deadline)
        final goal = activeGoals.first;

        // Get formatted goal info for display
        final goalInfo = await GoalService.instance.getGoalDisplayInfo(goal);

        setState(() {
          _activeGoalData = goalInfo;
          _isLoadingGoal = false;
        });
      } else {
        setState(() {
          _activeGoalData = null;
          _isLoadingGoal = false;
        });
      }
    } catch (e) {
      print('Error fetching active goal: $e');
      setState(() {
        _activeGoalData = null;
        _isLoadingGoal = false;
      });
    }
  }

  Future<void> _logRestDay() async {
    try {
      final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Log Rest Day'),
              content: const Text(
                  'Logging a rest day will maintain your current streak. Are you sure you want to log today as a rest day?'),
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
          ) ??
          false;

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
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
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
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600),
                                ),
                                if (_isLoadingStreak)
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                else
                                  Text(
                                    '$_currentStreak Days',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
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
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CalendarStreakScreen()),
                          ).then((_) => _fetchStreakData());
                        },
                        tooltip: 'View Calendar',
                        color: Colors.blue,
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
                _isLoadingRecentWorkout
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _recentWorkoutData == null
                        ? _buildNoWorkoutsCard()
                        : _buildRecentWorkoutCard(),
                const SizedBox(height: 24),
                // Active Goal section
                const Text(
                  'Active Goal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _isLoadingGoal
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _activeGoalData == null
                        ? _buildNoGoalsCard()
                        : _buildActiveGoalCard(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LogWorkoutFlow()),
                      ).then((_) {
                        _fetchStreakData();
                        _fetchRecentWorkout();
                        _fetchMostImportantGoal(); // Refresh goal data as well
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

  Widget _buildNoWorkoutsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            'No workouts logged yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your fitness journey by logging your first workout',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWorkoutCard() {
    final workout = _recentWorkoutData!['workout'] as Workout;
    final exerciseCount = _recentWorkoutData!['exerciseCount'] as int;
    final muscleGroups = _recentWorkoutData!['muscleGroups'] as List<String>;
    final timeAgo = _recentWorkoutData!['timeAgo'] as String;
    final workoutId = _recentWorkoutData!['workoutId'] as int;

    // Determine the primary muscle group for display
    String primaryType = 'Workout';
    if (muscleGroups.isNotEmpty) {
      // Check for common groupings
      if (muscleGroups.any((group) => [
            'Chest',
            'Back',
            'Shoulders',
            'Biceps',
            'Triceps'
          ].contains(group))) {
        primaryType = 'Upper Body';
      } else if (muscleGroups
          .any((group) => ['Legs', 'Calves', 'Glutes'].contains(group))) {
        primaryType = 'Lower Body';
      } else {
        primaryType = muscleGroups.first;
      }
    }

    return GestureDetector(
      onTap: () {
        // Navigate to the workout details screen when tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutDetailScreen(workoutId: workoutId),
          ),
        ).then((_) {
          // Refresh the data when returning from details
          _fetchRecentWorkout();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  workout.notes ?? primaryType,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(timeAgo,
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
            Text('$exerciseCount exercises',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            if (muscleGroups.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 28, // Fixed height for the chip list
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: muscleGroups.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Chip(
                        label: Text(
                          muscleGroups[index],
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.grey.shade100,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoGoalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 24,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active goals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Set a goal to track your progress',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGoalCard() {
    final goalTitle = _activeGoalData!['title'] as String;
    final goalId = _activeGoalData!['goalId'] as int?;
    final daysLeft = _activeGoalData!['daysLeft'] as int;
    final progress = _activeGoalData!['progress'] as double;

    // For strength goals
    final current = _activeGoalData!['current'] as double?;
    final target = _activeGoalData!['target'] as double?;
    final exerciseName = _activeGoalData!['exerciseName'] as String?;

    return GestureDetector(
      onTap: goalId != null
          ? () {
              // Navigate to the goal detail screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GoalDetailScreen(goalId: goalId),
                ),
              ).then((_) {
                // Refresh goals when returning
                _fetchMostImportantGoal();
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goalTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$daysLeft days left',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
              ),
            ),
            if (exerciseName != null && current != null && target != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current: ${current.toStringAsFixed(1)}kg',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Target: ${target.toStringAsFixed(1)}kg',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
