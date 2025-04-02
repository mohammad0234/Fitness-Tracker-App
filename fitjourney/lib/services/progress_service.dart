// lib/services/progress_service.dart

import 'package:fitjourney/database/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/database_models/workout_set.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

class ProgressService {
  // Singleton instance
  static final ProgressService instance = ProgressService._internal();
  
  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Private constructor
  ProgressService._internal();
  
  // Get the current user ID or throw an error if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  // 1. WORKOUT VOLUME DATA PROCESSING

  /// Get workout volume data for charts
  /// Returns a list of date-volume pairs for a time period
  Future<List<Map<String, dynamic>>> getWorkoutVolumeData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final String userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    // Format date for SQLite query
    final String formattedStartDate = startDate.toIso8601String();
    final String formattedEndDate = endDate.toIso8601String();

    // Get all workouts in the date range
    final List<Map<String, dynamic>> workouts = await db.rawQuery('''
      SELECT workout_id, date FROM workout 
      WHERE user_id = ? AND date BETWEEN ? AND ?
      ORDER BY date ASC
    ''', [userId, formattedStartDate, formattedEndDate]);

    List<Map<String, dynamic>> volumeData = [];

    // For each workout, calculate total volume
    for (var workout in workouts) {
      final int workoutId = workout['workout_id'];
      final DateTime workoutDate = DateTime.parse(workout['date']);
      
      // Get all sets for this workout
      final double totalVolume = await _calculateWorkoutVolume(workoutId);
      
      // Add to volume data list
      volumeData.add({
        'date': workoutDate,
        'volume': totalVolume,
        'formattedDate': DateFormat('MMM d').format(workoutDate),
      });
    }

    return volumeData;
  }

  /// Calculate total volume for a single workout (sum of weight × reps for all sets)
  Future<double> _calculateWorkoutVolume(int workoutId) async {
    final db = await _dbHelper.database;
    
    // Get all sets for this workout with their weights and reps
    final List<Map<String, dynamic>> sets = await db.rawQuery('''
      SELECT ws.weight, ws.reps 
      FROM workout_set ws
      JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
      WHERE we.workout_id = ?
    ''', [workoutId]);
    
    double totalVolume = 0;
    
    for (var set in sets) {
      final double? weight = set['weight'] != null ? (set['weight'] as num).toDouble() : null;
      final int? reps = set['reps'];
      
      if (weight != null && reps != null) {
        totalVolume += weight * reps;
      }
    }
    
    return totalVolume;
  }

  // 2. MUSCLE GROUP DISTRIBUTION PROCESSING

  /// Get muscle group distribution data for pie charts
  Future<List<Map<String, dynamic>>> getMuscleGroupDistribution({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final String userId = _getCurrentUserId();
    final db = await _dbHelper.database;
    
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

  // 3. EXERCISE PROGRESS PROCESSING

  /// Get strength progression data for a specific exercise
  Future<Map<String, dynamic>> getExerciseProgressData(int exerciseId) async {
    final String userId = _getCurrentUserId();
    final db = await _dbHelper.database;
    
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
      startingWeight = sets.first['weight'] != null ? (sets.first['weight'] as num).toDouble() : null;
      startingDate = DateTime.parse(sets.first['date'] as String);
      
      // Group sets by workout date and find max weight for each date
      Map<String, double> maxWeightByDate = {};
      
      for (var set in sets) {
        final double? weight = set['weight'] != null ? (set['weight'] as num).toDouble() : null;
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
      progressPoints.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    }
    
    // Calculate improvement percentage if we have both start and current values
    double improvementPercentage = 0;
    if (startingWeight != null && progressPoints.isNotEmpty) {
      final double currentWeight = progressPoints.last['weight'];
      improvementPercentage = ((currentWeight - startingWeight) / startingWeight) * 100;
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

  // 4. WORKOUT FREQUENCY PROCESSING (continued)

  /// Get workout frequency data for consistency tracking
Future<Map<String, dynamic>> getWorkoutFrequencyData({
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final String userId = _getCurrentUserId();
  final db = await _dbHelper.database;
  
  // Format date for SQLite query
  final String formattedStartDate = startDate.toIso8601String();
  final String formattedEndDate = endDate.toIso8601String();
  
  // Get all workout dates in the range
  final List<Map<String, dynamic>> workoutDates = await db.rawQuery('''
    SELECT date FROM workout 
    WHERE user_id = ? AND date BETWEEN ? AND ?
    ORDER BY date ASC
  ''', [userId, formattedStartDate, formattedEndDate]);
  
  // Get all rest days in the range
  final List<Map<String, dynamic>> restDayResults = await db.rawQuery('''
    SELECT date FROM daily_log 
    WHERE user_id = ? AND date BETWEEN ? AND ? AND activity_type = 'rest'
    ORDER BY date ASC
  ''', [userId, formattedStartDate, formattedEndDate]);
  
  // Convert to DateTime objects
  List<DateTime> workoutDaysList = workoutDates
      .map((row) => DateTime.parse(row['date'] as String))
      .toList();
  
  List<DateTime> restDaysList = restDayResults
      .map((row) => DateTime.parse(row['date'] as String))
      .toList();
  
  // Create sets of activity days (using date only, no time)
  Set<String> workoutDays = workoutDaysList
      .map((date) => DateFormat('yyyy-MM-dd').format(date))
      .toSet();
  
  Set<String> restDays = restDaysList
      .map((date) => DateFormat('yyyy-MM-dd').format(date))
      .toSet();
  
  // Create a map of all days in the range with activity status
  List<Map<String, dynamic>> calendarData = [];
  Map<String, int> workoutsByWeekday = {
    'Monday': 0,
    'Tuesday': 0,
    'Wednesday': 0,
    'Thursday': 0,
    'Friday': 0,
    'Saturday': 0,
    'Sunday': 0,
  };
  
  // Fill in all dates in the range
  for (DateTime date = startDate;
       date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
       date = date.add(const Duration(days: 1))) {
    
    final String dateStr = DateFormat('yyyy-MM-dd').format(date);
    final bool hasWorkout = workoutDays.contains(dateStr);
    final bool hasRestDay = restDays.contains(dateStr);
    
    calendarData.add({
      'date': date,
      'hasWorkout': hasWorkout,
      'hasRestDay': hasRestDay,
      'hasActivity': hasWorkout || hasRestDay,
      'formattedDate': DateFormat('MMM d').format(date),
    });
    
    // Count workouts by weekday
    if (hasWorkout) {
      final String weekday = DateFormat('EEEE').format(date);
      workoutsByWeekday[weekday] = (workoutsByWeekday[weekday] ?? 0) + 1;
    }
  }
  
  // Calculate overall stats
  int totalWorkouts = workoutDays.length;
  int totalDays = calendarData.length;
  double workoutFrequency = totalDays > 0 ? totalWorkouts / totalDays * 100 : 0;
  
  // Get streak information directly from streak table instead of calculating
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
  
  return {
    'calendarData': calendarData,
    'workoutsByWeekday': workoutsByWeekday,
    'totalWorkouts': totalWorkouts,
    'workoutFrequency': workoutFrequency,
    'formattedFrequency': '${workoutFrequency.toStringAsFixed(1)}%',
    'longestStreak': longestStreak,
    'currentStreak': currentStreak,
  };
}

  // 5. COMBINED PROGRESS SUMMARY

 /// Get a summary of all key progress metrics
Future<Map<String, dynamic>> getProgressSummary() async {
  final String userId = _getCurrentUserId();
  final db = await _dbHelper.database;
  
  // Get date ranges
  final DateTime now = DateTime.now();
  final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
  final DateTime monthStart = DateTime(now.year, now.month, 1);
  
  // 1. Total workout count
  final totalWorkoutCount = Sqflite.firstIntValue(await db.rawQuery(
    'SELECT COUNT(*) FROM workout WHERE user_id = ?',
    [userId]
  )) ?? 0;
  
  // 2. This week's workout count
  final weeklyWorkoutCount = Sqflite.firstIntValue(await db.rawQuery(
    'SELECT COUNT(*) FROM workout WHERE user_id = ? AND date >= ?',
    [userId, weekStart.toIso8601String()]
  )) ?? 0;
  
  // 3. This month's workout count
  final monthlyWorkoutCount = Sqflite.firstIntValue(await db.rawQuery(
    'SELECT COUNT(*) FROM workout WHERE user_id = ? AND date >= ?',
    [userId, monthStart.toIso8601String()]
  )) ?? 0;
  
  // 4. Most recent workout date
  final recentWorkoutResult = await db.rawQuery(
    'SELECT date FROM workout WHERE user_id = ? ORDER BY date DESC LIMIT 1',
    [userId]
  );
  
  DateTime? mostRecentWorkout;
  if (recentWorkoutResult.isNotEmpty) {
    mostRecentWorkout = DateTime.parse(recentWorkoutResult.first['date'] as String);
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
    mostTrainedMuscleGroup = muscleGroupResult.first['muscle_group'] as String;
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

  // 6. PERSONAL BESTS COLLECTION

  /// Get all personal bests for exercises the user has performed
  Future<List<Map<String, dynamic>>> getAllPersonalBests() async {
    final String userId = _getCurrentUserId();
    final db = await _dbHelper.database;
    
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
      
      if (maxWeightResult.isNotEmpty && maxWeightResult.first['max_weight'] != null) {
        final double maxWeight = (maxWeightResult.first['max_weight'] as num).toDouble();
        final int? reps = maxWeightResult.first['reps'];
        final DateTime date = DateTime.parse(maxWeightResult.first['date'] as String);
        
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

  /// Get start and end dates for a specific time period
  Map<String, DateTime> getDateRangeForPeriod(String period) {
    final DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    switch (period) {
      case 'Week':
        // Start from beginning of current week (Monday)
        final int weekdayOffset = now.weekday - 1; // 0 = Monday in DateTime.weekday
        startDate = DateTime(now.year, now.month, now.day - weekdayOffset);
        break;
      case 'Month':
        // Start from beginning of current month
        startDate = DateTime(now.year, now.month, 1);
        break;
      case '3 Months':
        // Start from 3 months ago
        startDate = DateTime(now.year, now.month - 3, 1);
        break;
      case '6 Months':
        // Start from 6 months ago
        startDate = DateTime(now.year, now.month - 6, 1);
        break;
      case 'Year':
        // Start from beginning of current year
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'All Time':
      default:
        // Use a far past date for all time
        startDate = DateTime(2020, 1, 1);
        break;
    }
    
    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }
  
  /// Get appropriate date formatting based on time range
  /// For shorter time periods, show more detail; for longer periods, aggregate
  String getDateFormatForRange(DateTime startDate, DateTime endDate) {
    final Duration difference = endDate.difference(startDate);
    
    if (difference.inDays <= 14) {
      // For short periods (up to 2 weeks), show day of week
      return 'EEE, MMM d'; // e.g., "Mon, Jan 15"
    } else if (difference.inDays <= 90) {
      // For medium periods (up to 3 months), show date
      return 'MMM d'; // e.g., "Jan 15"
    } else {
      // For long periods, show month only
      return 'MMM yyyy'; // e.g., "Jan 2025"
    }
  }
}