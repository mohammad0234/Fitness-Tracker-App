// lib/services/progress_service.dart

import 'package:fitjourney/database/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
//import 'package:fitjourney/database_models/workout.dart';
//import 'package:fitjourney/database_models/workout_set.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitjourney/utils/date_utils.dart';

/// Service for tracking and analyzing user fitness progress
/// Provides methods for generating progress reports, charts and statistics
class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  static ProgressService get instance => _instance;

  ProgressService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Returns current user ID or throws exception if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  // 1. MUSCLE GROUP DISTRIBUTION PROCESSING

  /// Analyzes muscle group distribution for balanced training assessment
  /// Returns pie chart data showing relative focus on different muscle groups
  Future<List<Map<String, dynamic>>> getMuscleGroupDistribution({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final String userId = _getCurrentUserId();
    final db = await _databaseHelper.database;

    // Format date for SQLite query
    final String formattedStartDate = startDate.toIso8601String();
    final String formattedEndDate = endDate.toIso8601String();

    // Query to count exercises by muscle group
    final List<Map<String, dynamic>> muscleGroupCounts = await db.rawQuery('''
      SELECT e.muscle_group, COUNT(*) as count
      FROM exercise e
      JOIN workout_exercise we ON e.exercise_id = we.exercise_id
      JOIN workout w ON we.workout_id = w.workout_id
      WHERE w.user_id = ? AND w.date BETWEEN ? AND ?
      GROUP BY e.muscle_group
      ORDER BY count DESC
    ''', [userId, formattedStartDate, formattedEndDate]);

    // Calculate total count for percentages
    int totalCount = 0;
    for (var group in muscleGroupCounts) {
      totalCount += group['count'] as int;
    }

    // Calculate percentages and format for pie chart
    List<Map<String, dynamic>> pieData = [];

    for (var group in muscleGroupCounts) {
      final int count = group['count'] as int;
      final double percentage = totalCount > 0 ? (count / totalCount) * 100 : 0;

      pieData.add({
        'muscleGroup': group['muscle_group'],
        'count': count,
        'percentage': percentage,
        'formattedPercentage': '${percentage.toStringAsFixed(1)}%',
      });
    }

    return pieData;
  }

  // 2. EXERCISE PROGRESS PROCESSING

  /// Tracks strength progression for a specific exercise over time
  /// Returns detailed information including personal bests and improvement percentages
  Future<Map<String, dynamic>> getExerciseProgressData(int exerciseId) async {
    final String userId = _getCurrentUserId();
    final db = await _databaseHelper.database;

    // Get exercise details
    final List<Map<String, dynamic>> exerciseDetails = await db.query(
      'exercise',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );

    if (exerciseDetails.isEmpty) {
      throw Exception('Exercise not found');
    }

    final String exerciseName = exerciseDetails.first['name'] as String;

    // Get all sets for this exercise, ordered by date
    final List<Map<String, dynamic>> sets = await db.rawQuery('''
      SELECT ws.weight, ws.reps, w.date
      FROM workout_set ws
      JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
      JOIN workout w ON we.workout_id = w.workout_id
      WHERE we.exercise_id = ? AND w.user_id = ?
      ORDER BY w.date ASC
    ''', [exerciseId, userId]);

    // Find personal best (max weight)
    double? personalBest;
    DateTime? personalBestDate;

    // Find starting weight (first recorded weight)
    double? startingWeight;
    DateTime? startingDate;

    // Track progress over time
    List<Map<String, dynamic>> progressPoints = [];

    if (sets.isNotEmpty) {
      // Get starting weight
      startingWeight = sets.first['weight'] != null
          ? (sets.first['weight'] as num).toDouble()
          : null;
      startingDate = DateTime.parse(sets.first['date'] as String);

      // Group sets by workout date and find max weight for each date
      Map<String, double> maxWeightByDate = {};

      for (var set in sets) {
        final double? weight =
            set['weight'] != null ? (set['weight'] as num).toDouble() : null;
        final String dateString = set['date'] as String;

        if (weight != null) {
          if (!maxWeightByDate.containsKey(dateString) ||
              weight > maxWeightByDate[dateString]!) {
            maxWeightByDate[dateString] = weight;
          }

          // Update personal best
          if (personalBest == null || weight > personalBest) {
            personalBest = weight;
            personalBestDate = DateTime.parse(dateString);
          }
        }
      }

      // Convert to date-ordered list for chart
      maxWeightByDate.forEach((dateString, weight) {
        final DateTime date = DateTime.parse(dateString);
        progressPoints.add({
          'date': date,
          'weight': weight,
          'formattedDate': DateFormat('MMM d').format(date),
        });
      });

      // Sort by date
      progressPoints.sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    }

    // Calculate improvement percentage if we have both start and current values
    double improvementPercentage = 0;
    if (startingWeight != null && progressPoints.isNotEmpty) {
      final double currentWeight = progressPoints.last['weight'];
      improvementPercentage =
          ((currentWeight - startingWeight) / startingWeight) * 100;
    }

    return {
      'exerciseName': exerciseName,
      'personalBest': personalBest,
      'personalBestDate': personalBestDate,
      'startingWeight': startingWeight,
      'startingDate': startingDate,
      'progressPoints': progressPoints,
      'improvementPercentage': improvementPercentage,
      'formattedImprovement': '${improvementPercentage.toStringAsFixed(1)}%',
    };
  }

  // 3. COMBINED PROGRESS SUMMARY

  /// Generates comprehensive fitness progress summary with key metrics
  /// Combines workout counts, streaks, and training balance information
  Future<Map<String, dynamic>> getProgressSummary() async {
    final String userId = _getCurrentUserId();
    final db = await _databaseHelper.database;

    // Get date ranges
    final DateTime now = DateTime.now();
    final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    final DateTime monthStart = DateTime(now.year, now.month, 1);

    // 1. Total workout count
    final totalWorkoutCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM workout WHERE user_id = ?', [userId])) ??
        0;

    // 2. This week's workout count
    final weeklyWorkoutCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM workout WHERE user_id = ? AND date >= ?',
            [userId, weekStart.toIso8601String()])) ??
        0;

    // 3. This month's workout count
    final monthlyWorkoutCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM workout WHERE user_id = ? AND date >= ?',
            [userId, monthStart.toIso8601String()])) ??
        0;

    // 4. Most recent workout date
    final recentWorkoutResult = await db.rawQuery(
        'SELECT date FROM workout WHERE user_id = ? ORDER BY date DESC LIMIT 1',
        [userId]);

    DateTime? mostRecentWorkout;
    if (recentWorkoutResult.isNotEmpty) {
      mostRecentWorkout =
          DateTime.parse(recentWorkoutResult.first['date'] as String);
    }

    // 5. Current streak - use streak table directly
    int currentStreak = 0;
    int longestStreak = 0;
    final streakQuery = await db.query(
      'streak',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (streakQuery.isNotEmpty) {
      currentStreak = streakQuery.first['current_streak'] as int;
      longestStreak = streakQuery.first['longest_streak'] as int;
    }

    // 6. Most trained muscle group
    final muscleGroupResult = await db.rawQuery('''
    SELECT e.muscle_group, COUNT(*) as count
    FROM exercise e
    JOIN workout_exercise we ON e.exercise_id = we.exercise_id
    JOIN workout w ON we.workout_id = w.workout_id
    WHERE w.user_id = ?
    GROUP BY e.muscle_group
    ORDER BY count DESC
    LIMIT 1
  ''', [userId]);

    String? mostTrainedMuscleGroup;
    int? muscleGroupCount;

    if (muscleGroupResult.isNotEmpty) {
      mostTrainedMuscleGroup =
          muscleGroupResult.first['muscle_group'] as String;
      muscleGroupCount = muscleGroupResult.first['count'] as int;
    }

    return {
      'totalWorkouts': totalWorkoutCount,
      'weeklyWorkouts': weeklyWorkoutCount,
      'monthlyWorkouts': monthlyWorkoutCount,
      'weeklyTarget': 5,
      'weeklyProgress': weeklyWorkoutCount / 5, // As a fraction of target
      'mostRecentWorkout': mostRecentWorkout,
      'daysSinceLastWorkout': mostRecentWorkout != null
          ? now.difference(mostRecentWorkout).inDays
          : null,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak, // Added this field
      'mostTrainedMuscleGroup': mostTrainedMuscleGroup,
      'muscleGroupCount': muscleGroupCount,
    };
  }

  // 4. PERSONAL BESTS COLLECTION

  /// Retrieves personal bests across all exercises performed by the user
  /// Returns comprehensive list of the user's highest achievements
  Future<List<Map<String, dynamic>>> getAllPersonalBests() async {
    final String userId = _getCurrentUserId();
    final db = await _databaseHelper.database;

    // Get all exercises performed by the user
    final List<Map<String, dynamic>> exercises = await db.rawQuery('''
      SELECT DISTINCT e.exercise_id, e.name, e.muscle_group
      FROM exercise e
      JOIN workout_exercise we ON e.exercise_id = we.exercise_id
      JOIN workout w ON we.workout_id = w.workout_id
      WHERE w.user_id = ?
      ORDER BY e.name
    ''', [userId]);

    List<Map<String, dynamic>> personalBests = [];

    for (var exercise in exercises) {
      final int exerciseId = exercise['exercise_id'];

      // Find personal best for this exercise
      final List<Map<String, dynamic>> maxWeightResult = await db.rawQuery('''
        SELECT MAX(ws.weight) as max_weight, ws.reps, w.date
        FROM workout_set ws
        JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
        JOIN workout w ON we.workout_id = w.workout_id
        WHERE we.exercise_id = ? AND w.user_id = ? AND ws.weight IS NOT NULL
        GROUP BY ws.workout_set_id
        ORDER BY ws.weight DESC
        LIMIT 1
      ''', [exerciseId, userId]);

      if (maxWeightResult.isNotEmpty &&
          maxWeightResult.first['max_weight'] != null) {
        final double maxWeight =
            (maxWeightResult.first['max_weight'] as num).toDouble();
        final int? reps = maxWeightResult.first['reps'];
        final DateTime date =
            DateTime.parse(maxWeightResult.first['date'] as String);

        personalBests.add({
          'exerciseId': exerciseId,
          'exerciseName': exercise['name'],
          'muscleGroup': exercise['muscle_group'],
          'maxWeight': maxWeight,
          'reps': reps,
          'date': date,
          'formattedDate': DateFormat('MMM d, yyyy').format(date),
        });
      }
    }

    return personalBests;
  }

  // Helper methods for date ranges

  /// Gets the date range for a given time period filter
  Map<String, DateTime> getDateRangeForPeriod(String period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'Weekly':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Monthly':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3 Months':
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'All Time':
        startDate = DateTime(2000); // A date far in the past
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    return {
      'startDate': startDate,
      'endDate': now,
    };
  }

  // 6. EXERCISE VOLUME DATA PROCESSING

  /// Analyzes volume data by exercise to identify most significant contributions
  /// Returns detailed breakdown of exercise volumes, sets, reps and frequency
  Future<List<Map<String, dynamic>>> getExerciseVolumeData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final String userId = _getCurrentUserId();
      final db = await _databaseHelper.database;

      // Format date for SQLite query
      final String formattedStartDate = startDate.toIso8601String();
      final String formattedEndDate = endDate.toIso8601String();

      // 1. Get all workouts within the date range
      final List<Map<String, dynamic>> workouts = await db.rawQuery('''
        SELECT workout_id FROM workout 
        WHERE user_id = ? AND date BETWEEN ? AND ?
      ''', [userId, formattedStartDate, formattedEndDate]);

      // If no workouts found, return empty list
      if (workouts.isEmpty) {
        return [];
      }

      // 2. Create a map to track volume by exercise
      final Map<int, Map<String, dynamic>> volumeByExercise = {};

      // 3. Process each workout
      for (var workout in workouts) {
        final int workoutId = workout['workout_id'];

        // 4. Get all exercises in this workout
        final List<Map<String, dynamic>> workoutExercises =
            await db.rawQuery('''
          SELECT we.workout_exercise_id, we.exercise_id, e.name, e.muscle_group
          FROM workout_exercise we
          JOIN exercise e ON we.exercise_id = e.exercise_id
          WHERE we.workout_id = ?
        ''', [workoutId]);

        // 5. For each exercise, get all sets
        for (var workoutExercise in workoutExercises) {
          final int workoutExerciseId = workoutExercise['workout_exercise_id'];
          final int exerciseId = workoutExercise['exercise_id'];
          final String exerciseName = workoutExercise['name'];
          final String muscleGroup = workoutExercise['muscle_group'];

          // Get all sets for this exercise
          final List<Map<String, dynamic>> sets = await db.query(
            'workout_set',
            where: 'workout_exercise_id = ?',
            whereArgs: [workoutExerciseId],
          );

          // Initialize exercise in our map if needed
          if (!volumeByExercise.containsKey(exerciseId)) {
            volumeByExercise[exerciseId] = {
              'exerciseId': exerciseId,
              'name': exerciseName,
              'muscleGroup': muscleGroup,
              'totalVolume': 0.0,
              'totalSets': 0,
              'totalReps': 0,
              'totalWorkouts': 0,
            };
          }

          // Track if we found sets for this exercise in this workout
          bool foundSetsInWorkout = false;

          // 6. Calculate volume for this exercise in this workout
          for (var set in sets) {
            final double? weight = set['weight'] != null
                ? (set['weight'] as num).toDouble()
                : null;
            final int? reps = set['reps'];

            if (weight != null && reps != null && weight > 0 && reps > 0) {
              // Calculate volume (weight × reps) and add to total
              final double setVolume = weight * reps;
              volumeByExercise[exerciseId]!['totalVolume'] =
                  (volumeByExercise[exerciseId]!['totalVolume'] as double) +
                      setVolume;
              volumeByExercise[exerciseId]!['totalSets'] =
                  (volumeByExercise[exerciseId]!['totalSets'] as int) + 1;
              volumeByExercise[exerciseId]!['totalReps'] =
                  (volumeByExercise[exerciseId]!['totalReps'] as int) + reps;

              foundSetsInWorkout = true;
            }
          }

          // Increment total workouts if we found sets for this exercise
          if (foundSetsInWorkout) {
            volumeByExercise[exerciseId]!['totalWorkouts'] =
                (volumeByExercise[exerciseId]!['totalWorkouts'] as int) + 1;
          }
        }
      }

      // 7. Convert the map to a list and sort by volume (descending)
      final List<Map<String, dynamic>> result =
          volumeByExercise.values.toList();
      result.sort((a, b) =>
          (b['totalVolume'] as double).compareTo(a['totalVolume'] as double));

      // 8. Format volume numbers for display
      for (var exercise in result) {
        exercise['formattedVolume'] =
            '${(exercise['totalVolume'] as double).toStringAsFixed(0)} kg';

        // Add average weight per rep for additional insight
        final int totalReps = exercise['totalReps'] as int;
        if (totalReps > 0) {
          final double totalVolume = exercise['totalVolume'] as double;
          final double avgWeightPerRep = totalVolume / totalReps;
          exercise['avgWeightPerRep'] = avgWeightPerRep;
          exercise['formattedAvgWeight'] =
              '${avgWeightPerRep.toStringAsFixed(1)} kg';
        }
      }

      return result;
    } catch (e) {
      print('Error getting exercise volume data: $e');
      return [];
    }
  }
}
