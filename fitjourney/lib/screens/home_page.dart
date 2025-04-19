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
import 'package:intl/intl.dart';

// New goal-related imports
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/screens/goal_detail_screen.dart';
import 'package:fitjourney/screens/weight_goal_detail_screen.dart';

// HomePage is the main dashboard screen of the fitness app
// Displays user information, workout streaks, recent workouts, and active fitness goals
// Provides quick access to logging workouts and rest days
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// HomePageState manages the state and UI for the main dashboard
/// Handles data loading, user interactions, and display of fitness tracking information
class _HomePageState extends State<HomePage> {
  // Core user data and loading states
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isLoadingStreak = true;
  int _currentStreak = 0;
  bool _isLoggingRestDay = false;

  // State management for recent workout display
  bool _isLoadingRecentWorkout = true;
  Map<String, dynamic>? _recentWorkoutData;

  // State management for active goal display
  bool _isLoadingGoal = true;
  Map<String, dynamic>? _activeGoalData;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initializes the app by fetching user data, checking workout status for today,
  /// and loading all necessary data for the home screen
  Future<void> _initializeApp() async {
    // Initialize required data
    await _getUserData();
    await _fetchStreakData();

    // Load exercises
    await _addNewExercises();
    await _addAdditionalExercises(); // Add the missing bicep exercises and additional exercises

    // Load recent workout and active goals for display
    await _fetchRecentWorkoutData();
    await _fetchActiveGoals();

    // Mark setup complete
    setState(() {
      _isLoading = false;
    });
  }

  /// Fetches and sets up user data from both Firebase and local database
  /// Handles synchronization between remote and local user data
  Future<void> _getUserData() async {
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

  /// Retrieves the user's current workout streak from the streak service
  /// Updates the UI to show the number of consecutive days with activity
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

  /// Loads and formats the most recent workout data for display
  /// Includes exercise details, timing information, and workout statistics
  Future<void> _fetchRecentWorkoutData() async {
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

        // Extract exercise names
        final exerciseNames = (details['exercises'] as List)
            .map((e) => e['name'] as String)
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
            'exerciseNames': exerciseNames,
            'exercises': details['exercises'],
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

  /// Retrieves the most important active goal based on deadline proximity
  /// Formats goal data for display including progress and target information
  Future<void> _fetchActiveGoals() async {
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

  /// Handles the process of logging a rest day
  /// Shows confirmation dialog and updates streak information
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

  /// Populates the exercise database with predefined exercises
  /// Checks for existing entries to avoid duplicates
  Future<void> _addNewExercises() async {
    final db = await DatabaseHelper.instance.database;

    // List of new exercises to add
    final newExercises = [
      {
        'name': 'Cable Fly',
        'muscle_group': 'Chest',
        'description':
            'Stand between cable pulleys and bring handles together in front of your chest in an arc motion.'
      },
      {
        'name': 'Barbell Row',
        'muscle_group': 'Back',
        'description':
            'Bend forward with a slight knee bend and pull a barbell towards your lower chest/upper abdomen.'
      },
      {
        'name': 'T-Bar Row',
        'muscle_group': 'Back',
        'description':
            'Using a T-bar row machine or landmine setup, pull the weight toward your torso while maintaining a hinged position.'
      },
      {
        'name': 'Military Press',
        'muscle_group': 'Shoulders',
        'description':
            'Standing barbell press where you push the weight from shoulder level to overhead with strict form.'
      },
      {
        'name': 'Rear Delt Fly',
        'muscle_group': 'Shoulders',
        'description':
            'Bend forward and raise weights out to sides, targeting the rear shoulder muscles.'
      },
      {
        'name': 'Bulgarian Split Squat',
        'muscle_group': 'Legs',
        'description':
            'Perform a single-leg squat with your rear foot elevated on a bench or platform.'
      },
      {
        'name': 'Calf Raise',
        'muscle_group': 'Legs',
        'description':
            'Rise onto your toes, lifting your heels off the ground against resistance.'
      },
      {
        'name': 'Overhead Tricep Extension',
        'muscle_group': 'Triceps',
        'description':
            'Hold weight overhead and lower it behind your head, then extend arms to work the triceps.'
      },
      {
        'name': 'Skull Crusher',
        'muscle_group': 'Triceps',
        'description':
            'Lie on a bench, hold weight above your face, bend elbows to lower weight toward your forehead, then extend.'
      },
    ];

    // Insert each exercise if it doesn't already exist
    for (final exercise in newExercises) {
      // Check if exercise already exists
      final exists = await db.rawQuery(
          "SELECT 1 FROM exercise WHERE name = ? AND muscle_group = ?",
          [exercise['name'], exercise['muscle_group']]);

      // Only insert if it doesn't exist
      if (exists.isEmpty) {
        await db.insert('exercise', exercise);
        print('Added new exercise: ${exercise['name']}');
      }
    }
  }

  /// Adds additional exercises including bicep muscle group (which was missing),
  /// and more exercises for legs, shoulders, and triceps.
  Future<void> _addAdditionalExercises() async {
    final db = await DatabaseHelper.instance.database;

    // New exercises to add
    final additionalExercises = [
      // Biceps exercises
      {
        'name': 'Barbell Curl',
        'muscle_group': 'Biceps',
        'description':
            'Standing with a barbell in hands, curl the weight up towards shoulders while keeping elbows stationary.'
      },
      {
        'name': 'Dumbbell Curl',
        'muscle_group': 'Biceps',
        'description':
            'Standing with dumbbells in hands, alternately curl each weight up towards the shoulder.'
      },
      {
        'name': 'Hammer Curl',
        'muscle_group': 'Biceps',
        'description':
            'Perform a dumbbell curl with palms facing each other throughout the movement.'
      },
      {
        'name': 'Preacher Curl',
        'muscle_group': 'Biceps',
        'description':
            'Perform curls with upper arms resting on a sloped bench to isolate the biceps.'
      },
      {
        'name': 'Concentration Curl',
        'muscle_group': 'Biceps',
        'description':
            'Seated with elbow against inner thigh, curl the weight up while keeping the upper arm stationary.'
      },

      // Additional leg exercises
      {
        'name': 'Squat',
        'muscle_group': 'Legs',
        'description':
            'Stand with feet shoulder-width apart, bend knees and hips to lower your body, then return to standing position.'
      },
      {
        'name': 'Leg Press',
        'muscle_group': 'Legs',
        'description':
            'Push weight away using your legs while seated on a machine.'
      },
      {
        'name': 'Hack Squat',
        'muscle_group': 'Legs',
        'description':
            'Perform squats on a machine that keeps your back supported at an angle.'
      },
      {
        'name': 'Leg Extension',
        'muscle_group': 'Legs',
        'description':
            'Extend legs against resistance on a machine to target quadriceps.'
      },
      {
        'name': 'Hamstring Curl',
        'muscle_group': 'Legs',
        'description':
            'Curl legs towards buttocks against resistance to target hamstrings.'
      },
      {
        'name': 'Romanian Deadlift',
        'muscle_group': 'Legs',
        'description':
            'Bend forward at the hips while keeping legs mostly straight to target hamstrings.'
      },

      // Additional shoulder exercises
      {
        'name': 'Lateral Raise',
        'muscle_group': 'Shoulders',
        'description':
            'Raise weights out to sides to shoulder height to target lateral deltoids.'
      },
      {
        'name': 'Front Raise',
        'muscle_group': 'Shoulders',
        'description':
            'Raise weights in front of you to shoulder height to target front deltoids.'
      },
      {
        'name': 'Arnold Press',
        'muscle_group': 'Shoulders',
        'description':
            'A dumbbell press that starts with palms facing you, then rotates as you press upward.'
      },
      {
        'name': 'Upright Row',
        'muscle_group': 'Shoulders',
        'description':
            'Pull weight up along the front of your body with elbows leading to shoulder height.'
      },
      {
        'name': 'Face Pull',
        'muscle_group': 'Shoulders',
        'description':
            'Pull cable attachment toward your face, targeting rear deltoids and upper back.'
      },

      // Additional tricep exercises
      {
        'name': 'Tricep Pushdown',
        'muscle_group': 'Triceps',
        'description':
            'Push cable attachment downward against resistance to extend the arms fully.'
      },
      {
        'name': 'Close-Grip Bench Press',
        'muscle_group': 'Triceps',
        'description':
            'Perform bench press with hands placed closer together to emphasize triceps.'
      },
      {
        'name': 'Dip',
        'muscle_group': 'Triceps',
        'description':
            'Lower and raise body between parallel bars to work triceps and chest.'
      },
      {
        'name': 'Diamond Push-Up',
        'muscle_group': 'Triceps',
        'description':
            'Perform push-ups with hands close together forming a diamond shape.'
      },
      {
        'name': 'Kickback',
        'muscle_group': 'Triceps',
        'description':
            'Bend over with upper arm parallel to floor, then extend forearm backward.'
      },
    ];

    // Insert each exercise if it doesn't already exist
    for (final exercise in additionalExercises) {
      // Check if exercise already exists
      final exists = await db.rawQuery(
          "SELECT 1 FROM exercise WHERE name = ? AND muscle_group = ?",
          [exercise['name'], exercise['muscle_group']]);

      // Only insert if it doesn't exist
      if (exists.isEmpty) {
        await db.insert('exercise', exercise);
        print('Added new exercise: ${exercise['name']}');
      }
    }
  }

  /// Builds the main layout of the home page
  /// Includes user info, streak data, recent workout, and active goal sections
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
                        _fetchRecentWorkoutData();
                        _fetchActiveGoals(); // Refresh goal data as well
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

  /// Creates a placeholder card when no workouts are available
  /// Provides user guidance for starting their fitness journey
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

  /// Constructs a detailed card showing recent workout information
  /// Displays exercise details, timing, and muscle groups worked
  Widget _buildRecentWorkoutCard() {
    final workout = _recentWorkoutData!['workout'] as Workout;
    final exerciseCount = _recentWorkoutData!['exerciseCount'] as int;
    final muscleGroups = _recentWorkoutData!['muscleGroups'] as List<String>;
    final timeAgo = _recentWorkoutData!['timeAgo'] as String;
    final workoutId = _recentWorkoutData!['workoutId'] as int;
    final exercises = _recentWorkoutData!['exercises'] as List;

    // Determine a color based on muscle groups
    Color cardColor = _getWorkoutColor(muscleGroups);

    // Determine darker shade for text
    Color darkCardColor = cardColor;
    if (cardColor == Colors.blue) {
      darkCardColor = Colors.blue.shade600;
    } else if (cardColor == Colors.green) {
      darkCardColor = Colors.green.shade600;
    } else if (cardColor == Colors.orange) {
      darkCardColor = Colors.orange.shade600;
    } else if (cardColor == Colors.purple) {
      darkCardColor = Colors.purple.shade600;
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
          _fetchRecentWorkoutData();
        });
      },
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                cardColor.withOpacity(0.08),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getWorkoutIcon(muscleGroups),
                            color: darkCardColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Workout ${DateFormat('MM/dd').format(workout.date)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 46.0),
                  child: Text(
                    exerciseCount == 1
                        ? '$exerciseCount exercise'
                        : '$exerciseCount exercises',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Exercise list with chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...exercises.map((exercise) {
                      final exerciseName = exercise['name'] as String;
                      final muscleGroup = exercise['muscle_group'] as String;
                      final exerciseSets = exercise['sets'] as List;

                      // Get the max weight if available
                      double? maxWeight;
                      if (exerciseSets.isNotEmpty) {
                        maxWeight = exerciseSets
                            .map((set) => set.weight ?? 0.0)
                            .reduce(
                                (max, weight) => weight > max ? weight : max);
                      }

                      final color = _getMuscleGroupColor(muscleGroup);

                      // Determine darker shade for text in the chip
                      Color darkColor = color;
                      if (color == Colors.blue) {
                        darkColor = Colors.blue.shade700;
                      } else if (color == Colors.green) {
                        darkColor = Colors.green.shade700;
                      } else if (color == Colors.cyan) {
                        darkColor = Colors.cyan.shade700;
                      } else if (color == Colors.teal) {
                        darkColor = Colors.teal.shade700;
                      } else if (color == Colors.indigo) {
                        darkColor = Colors.indigo.shade700;
                      } else if (color == Colors.orange) {
                        darkColor = Colors.orange.shade700;
                      } else if (color == Colors.amber) {
                        darkColor = Colors.amber.shade800;
                      } else if (color == Colors.deepOrange) {
                        darkColor = Colors.deepOrange.shade700;
                      } else if (color == Colors.purple) {
                        darkColor = Colors.purple.shade700;
                      } else {
                        darkColor = Colors.blueGrey.shade700;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Chip(
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(
                              _getMuscleGroupIcon(muscleGroup),
                              size: 12,
                              color: darkColor,
                            ),
                          ),
                          label: Text(
                            maxWeight != null && maxWeight > 0
                                ? '$exerciseName (${maxWeight.toStringAsFixed(1)}kg)'
                                : exerciseName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          backgroundColor: color.withOpacity(0.08),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Creates a placeholder card when no active goals are set
  /// Encourages users to set new fitness goals
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

  /// Builds a card displaying the most important active goal
  /// Shows progress, deadline, and goal-specific metrics
  Widget _buildActiveGoalCard() {
    final goalTitle = _activeGoalData!['title'] as String;
    final goalId = _activeGoalData!['goalId'] as int?;
    final daysLeft = _activeGoalData!['daysLeft'] as int;
    final progress = _activeGoalData!['progress'] as double;
    final goalType = _activeGoalData!['type'] as String? ?? 'ExerciseTarget';

    // For strength goals

    // Get the color and icon based on goal type
    final Color goalColor = _getGoalColor(goalType);
    final Widget goalIcon = _getGoalIcon(goalType);

    return GestureDetector(
      onTap: goalId != null
          ? () {
              // Navigate to the appropriate goal detail screen based on type
              if (goalType == 'WeightTarget') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WeightGoalDetailScreen(goalId: goalId),
                  ),
                ).then((_) {
                  // Refresh goals when returning
                  _fetchActiveGoals();
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoalDetailScreen(goalId: goalId),
                  ),
                ).then((_) {
                  // Refresh goals when returning
                  _fetchActiveGoals();
                });
              }
            }
          : null,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: goalColor.withOpacity(0.1),
                    child: goalIcon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$daysLeft days left',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              _buildGoalDetails(_activeGoalData!),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates a detailed view of goal progress based on goal type
  /// Handles different formats for exercise, frequency, and weight goals
  Widget _buildGoalDetails(Map<String, dynamic> goalInfo) {
    if (goalInfo['type'] == 'ExerciseTarget') {
      // For strength goals
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${goalInfo['current']?.toStringAsFixed(1) ?? '0'} / ${goalInfo['target']?.toStringAsFixed(1) ?? '0'} kg',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (goalInfo.containsKey('startingWeight'))
            Row(
              children: [
                Text(
                  'From ${goalInfo['startingWeight']?.toStringAsFixed(1) ?? '0'} kg · ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (goalInfo.containsKey('formattedImprovement'))
                  Text(
                    goalInfo['formattedImprovement']
                        .replaceAll('since starting', ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
              ],
            )
          else if (goalInfo.containsKey('formattedImprovement'))
            Text(
              goalInfo['formattedImprovement'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
              ),
            ),
        ],
      );
    } else if (goalInfo['type'] == 'WorkoutFrequency') {
      // For frequency goals
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${goalInfo['current']?.toInt() ?? 0} / ${goalInfo['target']?.toInt() ?? 0} workouts',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Target: ${(goalInfo['weeklyTarget'] ?? 0).round()} workouts per week',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    } else if (goalInfo['type'] == 'WeightTarget') {
      // For weight goals
      final isWeightLoss = goalInfo['isWeightLoss'] ?? false;
      final currentWeight = goalInfo['current']?.toStringAsFixed(1) ?? '0';
      final targetWeight = goalInfo['target']?.toStringAsFixed(1) ?? '0';
      final startingWeight =
          goalInfo['startingWeight']?.toStringAsFixed(1) ?? '0';
      final progressChange = goalInfo['formattedChange'] ?? '';
      final textColor =
          isWeightLoss ? Colors.green.shade700 : Colors.blue.shade700;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$currentWeight / $targetWeight kg',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Text(
                'From $startingWeight kg · ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                progressChange.replaceAll('since starting', ''),
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return const Text('Unknown goal type');
    }
  }

  /// Returns appropriate color coding for different goal types
  /// Helps visually distinguish between different types of goals
  Color _getGoalColor(String type) {
    switch (type) {
      case 'ExerciseTarget':
        return Colors.orange;
      case 'WorkoutFrequency':
        return Colors.blue;
      case 'WeightTarget':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Provides appropriate icons for different goal types
  /// Enhances visual recognition of goal categories
  Widget _getGoalIcon(String type) {
    switch (type) {
      case 'ExerciseTarget':
        return Icon(
          Icons.fitness_center,
          color: Colors.orange,
          size: 24,
        );
      case 'WorkoutFrequency':
        return Icon(
          Icons.calendar_today,
          color: Colors.blue,
          size: 24,
        );
      case 'WeightTarget':
        return Icon(
          Icons.monitor_weight_outlined,
          color: Colors.green,
          size: 24,
        );
      default:
        return Icon(
          Icons.help_outline,
          color: Colors.grey,
          size: 24,
        );
    }
  }

  /// Determines appropriate color scheme for workout cards based on muscle groups
  /// Groups similar muscle categories under consistent color themes
  Color _getWorkoutColor(List<String> muscleGroups) {
    if (muscleGroups.isEmpty) return Colors.blue;

    // Check for muscle group categories
    if (muscleGroups
        .any((group) => ['Chest', 'Shoulders', 'Triceps'].contains(group))) {
      return Colors.blue;
    } else if (muscleGroups
        .any((group) => ['Back', 'Biceps'].contains(group))) {
      return Colors.green;
    } else if (muscleGroups.any((group) => ['Legs'].contains(group))) {
      return Colors.orange;
    }
    // Default color
    return Colors.blue;
  }

  /// Selects appropriate icons for different workout types
  /// Based on the primary muscle groups targeted in the workout
  IconData _getWorkoutIcon(List<String> muscleGroups) {
    if (muscleGroups.isEmpty) return Icons.fitness_center;

    if (muscleGroups
        .any((group) => ['Chest', 'Shoulders', 'Triceps'].contains(group))) {
      return Icons.fitness_center; // Dumbbell for upper body push
    } else if (muscleGroups
        .any((group) => ['Back', 'Biceps'].contains(group))) {
      return Icons.fitness_center; // Dumbbell for upper body pull
    } else if (muscleGroups.any((group) => ['Legs'].contains(group))) {
      return Icons.directions_run; // Running for lower body
    }

    return Icons.fitness_center; // Default to dumbbell
  }

  /// Assigns specific colors to different muscle groups
  /// Creates consistent visual coding throughout the app
  Color _getMuscleGroupColor(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return Colors.blue;
      case 'Back':
        return Colors.green;
      case 'Shoulders':
        return Colors.cyan;
      case 'Biceps':
        return Colors.teal;
      case 'Triceps':
        return Colors.indigo;
      case 'Legs':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  /// Provides specific icons for different muscle groups
  /// Helps in quick visual identification of exercise types
  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return Icons.fitness_center; // Dumbbell for chest
      case 'Back':
        return Icons.fitness_center; // Dumbbell for back
      case 'Shoulders':
        return Icons.fitness_center; // Dumbbell for shoulders
      case 'Biceps':
        return Icons.fitness_center; // Dumbbell for biceps
      case 'Triceps':
        return Icons.fitness_center; // Dumbbell for triceps
      case 'Legs':
        return Icons.directions_run; // Running for legs
      default:
        return Icons.fitness_center; // Default to dumbbell
    }
  }
}
