// lib/services/goal_service.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/goal.dart';
//import 'package:fitjourney/database_models/exercise.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/services/notification_trigger_service.dart';

class GoalService {
  // Singleton instance
  static final GoalService instance = GoalService._internal();

  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Notification service instance for triggering notifications
  final _notificationService = NotificationTriggerService.instance;

  // Private constructor
  GoalService._internal();

  // Get the current user ID or throw an error if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  // Create a strength target goal
  Future<int> createStrengthGoal({
    required int exerciseId,
    required double currentWeight,
    required double targetWeight,
    required DateTime targetDate,
  }) async {
    final userId = _getCurrentUserId();

    final goal = Goal(
      userId: userId,
      type: 'ExerciseTarget',
      exerciseId: exerciseId,
      targetValue: targetWeight,
      startDate: DateTime.now(),
      endDate: targetDate,
      achieved: false,
      currentProgress: currentWeight,
    );

    return await _dbHelper.insertGoal(goal);
  }

  // Create a weight target goal
  Future<int> createWeightGoal({
    required double currentWeight,
    required double targetWeight,
    required DateTime targetDate,
  }) async {
    final userId = _getCurrentUserId();

    final goal = Goal(
      userId: userId,
      type: 'WeightTarget',
      targetValue: targetWeight,
      startDate: DateTime.now(),
      endDate: targetDate,
      achieved: false,
      currentProgress: currentWeight,
      startingWeight: currentWeight,
    );

    // Also log the initial weight in user_metrics table
    await _dbHelper.insertUserWeight(userId, currentWeight, DateTime.now());

    return await _dbHelper.insertGoal(goal);
  }

  // Create a workout frequency goal
  Future<int> createFrequencyGoal({
    required int targetWorkouts,
    required DateTime endDate,
  }) async {
    final userId = _getCurrentUserId();

    final goal = Goal(
      userId: userId,
      type: 'WorkoutFrequency',
      targetValue: targetWorkouts.toDouble(),
      startDate: DateTime.now(),
      endDate: endDate,
      achieved: false,
      currentProgress: 0,
    );

    return await _dbHelper.insertGoal(goal);
  }

  // Get all goals for the current user
  Future<List<Goal>> getAllGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getGoalsForUser(userId);
  }

  // Get active (not achieved) goals for the current user
  Future<List<Goal>> getActiveGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getActiveGoals(userId);
  }

  // Get completed goals for the current user
  Future<List<Goal>> getCompletedGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getCompletedGoals(userId);
  }

  // Delete a goal
  Future<void> deleteGoal(int goalId) async {
    await _dbHelper.deleteGoal(goalId);
  }

  // Update goal progress
  Future<void> updateGoalProgress(int goalId, double progress) async {
    await _dbHelper.updateGoalProgress(goalId, progress);

    // Check if goal is achieved
    final goal = await _dbHelper.getGoalById(goalId);
    if (goal != null && progress >= (goal.targetValue ?? 0) && !goal.achieved) {
      await _dbHelper.markGoalAchieved(goalId);
    }
  }

  // Calculate current progress for strength goal
  Future<double> calculateStrengthGoalProgress(int goalId) async {
    final goal = await _dbHelper.getGoalById(goalId);
    if (goal == null || goal.exerciseId == null || goal.targetValue == null) {
      print("Goal not found or missing exercise/target: $goalId");
      return 0.0;
    }

    print("Calculating progress for goal $goalId, exercise ${goal.exerciseId}");

    // Get max weight directly from workout sets (same approach as ProgressService)
    final db = await _dbHelper.database;
    final maxWeightResult = await db.rawQuery('''
    SELECT MAX(ws.weight) as max_weight
    FROM workout_set ws
    JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
    JOIN workout w ON we.workout_id = w.workout_id
    WHERE we.exercise_id = ? AND w.user_id = ? AND ws.weight IS NOT NULL
    ORDER BY ws.weight DESC
    LIMIT 1
  ''', [goal.exerciseId, goal.userId]);

    if (maxWeightResult.isEmpty ||
        maxWeightResult.first['max_weight'] == null) {
      print("No personal best found for exercise ${goal.exerciseId}");
      return goal.currentProgress;
    }

    final maxWeight = (maxWeightResult.first['max_weight'] as num).toDouble();
    print("Max weight for exercise ${goal.exerciseId}: $maxWeight");

    // Update goal's progress
    await _dbHelper.updateGoalProgress(goalId, maxWeight);
    print("Updated goal $goalId progress to $maxWeight");

    return maxWeight;
  }

  // Calculate current progress for weight goal
  Future<double> calculateWeightGoalProgress(int goalId) async {
    final goal = await _dbHelper.getGoalById(goalId);
    if (goal == null || goal.targetValue == null) {
      return 0.0;
    }

    // Get latest weight entry for the user
    final db = await _dbHelper.database;
    final latestWeightResult = await db.rawQuery('''
      SELECT weight_kg FROM user_metrics
      WHERE user_id = ?
      ORDER BY measured_at DESC
      LIMIT 1
    ''', [goal.userId]);

    if (latestWeightResult.isEmpty ||
        latestWeightResult.first['weight_kg'] == null) {
      // No weight entries found - return current progress (initial weight)
      return goal.currentProgress;
    }

    final latestWeight =
        (latestWeightResult.first['weight_kg'] as num).toDouble();

    // Update goal's progress with latest weight
    await updateGoalProgress(goalId, latestWeight);

    return latestWeight;
  }

  // Calculate current progress for frequency goal
  Future<double> calculateFrequencyGoalProgress(int goalId) async {
    final goal = await _dbHelper.getGoalById(goalId);
    if (goal == null || goal.targetValue == null) {
      return 0.0;
    }

    // Count workouts in date range
    final workoutCount = await _dbHelper.countWorkoutsInDateRange(
        goal.userId, goal.startDate, goal.endDate);

    // Update goal's progress
    await updateGoalProgress(goalId, workoutCount.toDouble());

    return workoutCount.toDouble();
  }

  // Update progress for all goals
  Future<void> updateAllGoalsProgress() async {
    final userId = _getCurrentUserId();
    final activeGoals = await _dbHelper.getActiveGoals(userId);

    for (final goal in activeGoals) {
      if (goal.goalId == null) continue;

      if (goal.type == 'ExerciseTarget') {
        await calculateStrengthGoalProgress(goal.goalId!);
      } else if (goal.type == 'WorkoutFrequency') {
        await calculateFrequencyGoalProgress(goal.goalId!);
      } else if (goal.type == 'WeightTarget') {
        await calculateWeightGoalProgress(goal.goalId!);
      }
    }

    // Also check for expired goals
    await _dbHelper.updateAllGoalStatuses(userId);
  }

  // Helper method to determine if this is a weight loss goal
  bool isWeightLossGoal(Goal goal) {
    if (goal.type != 'WeightTarget' || goal.targetValue == null) return false;

    // If we have a stored starting weight, use it
    if (goal.startingWeight != null) {
      return goal.targetValue! < goal.startingWeight!;
    }

    // Otherwise use current progress as starting weight
    return goal.targetValue! < goal.currentProgress;
  }

  // Helper method to determine if this is a weight gain goal
  bool isWeightGainGoal(Goal goal) {
    if (goal.type != 'WeightTarget' || goal.targetValue == null) return false;

    // If we have a stored starting weight, use it
    if (goal.startingWeight != null) {
      return goal.targetValue! > goal.startingWeight!;
    }

    // Otherwise use current progress as starting weight
    return goal.targetValue! > goal.currentProgress;
  }

  // Calculate weight goal percentage completion
  double calculateWeightGoalPercentage(
      double startWeight, double currentWeight, double targetWeight) {
    // For weight loss
    if (targetWeight < startWeight) {
      // If current is below target (exceeded goal)
      if (currentWeight <= targetWeight) return 1.0;

      // Calculate percentage of weight lost towards target
      double weightToLose = startWeight - targetWeight;
      double weightLost = startWeight - currentWeight;
      return (weightLost / weightToLose).clamp(0.0, 1.0);
    }

    // For weight gain
    else if (targetWeight > startWeight) {
      // If current is above target (exceeded goal)
      if (currentWeight >= targetWeight) return 1.0;

      // Calculate percentage of weight gained towards target
      double weightToGain = targetWeight - startWeight;
      double weightGained = currentWeight - startWeight;
      return (weightGained / weightToGain).clamp(0.0, 1.0);
    }

    // For maintenance (target = starting)
    else {
      // If exactly at target
      if (currentWeight == targetWeight) return 1.0;

      // Calculate how close to target (within 5% is considered close)
      double deviation = (currentWeight - targetWeight).abs() / targetWeight;
      return (1.0 - deviation * 20).clamp(0.0, 1.0);
    }
  }

  // Get formatted goal information for display
  Future<Map<String, dynamic>> getGoalDisplayInfo(Goal goal) async {
    final Map<String, dynamic> info = {
      'goalId': goal.goalId,
      'type': goal.type,
      'progress': goal.currentProgress / (goal.targetValue ?? 1),
      'daysLeft': goal.endDate.difference(DateTime.now()).inDays,
      'isExpired': DateTime.now().isAfter(goal.endDate),
    };

    if (goal.type == 'ExerciseTarget' && goal.exerciseId != null) {
      // For strength goals, get exercise info
      final exercise =
          await WorkoutService.instance.getExerciseById(goal.exerciseId!);
      if (exercise != null) {
        info['exerciseName'] = exercise.name;
        info['muscleGroup'] = exercise.muscleGroup;
        info['title'] = '${exercise.name} Strength Goal';
        info['current'] = goal.currentProgress;
        info['target'] = goal.targetValue;

        // Get the first logged weight for this exercise (starting point)
        final db = await _dbHelper.database;
        final firstWeightResult = await db.rawQuery('''
          SELECT ws.weight
          FROM workout_set ws
          JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
          JOIN workout w ON we.workout_id = w.workout_id
          WHERE we.exercise_id = ? AND w.user_id = ? AND ws.weight IS NOT NULL
          ORDER BY w.date ASC
          LIMIT 1
        ''', [goal.exerciseId, goal.userId]);

        double? startingWeight;
        if (firstWeightResult.isNotEmpty &&
            firstWeightResult.first['weight'] != null) {
          startingWeight =
              (firstWeightResult.first['weight'] as num).toDouble();
        }

        // If we have both starting and current weights, calculate improvement
        if (startingWeight != null &&
            startingWeight > 0 &&
            goal.currentProgress > 0) {
          final currentWeight = goal.currentProgress;
          final improvementPercentage =
              ((currentWeight - startingWeight) / startingWeight) * 100;
          info['startingWeight'] = startingWeight;
          info['improvementPercentage'] = improvementPercentage;
          info['formattedImprovement'] =
              '+${improvementPercentage.toStringAsFixed(0)}% since starting';
        }
      }
    } else if (goal.type == 'WorkoutFrequency') {
      // For frequency goals
      final totalWeeks = goal.endDate.difference(goal.startDate).inDays / 7;
      info['title'] = 'Workout Frequency Goal';
      info['current'] = goal.currentProgress;
      info['target'] = goal.targetValue;
      info['weeklyTarget'] = (goal.targetValue ?? 0) / totalWeeks;
    } else if (goal.type == 'WeightTarget') {
      // For weight goals
      info['title'] = 'Weight Goal';
      info['target'] = goal.targetValue;

      // Use the stored starting weight if available, otherwise use first weight entry
      double startingWeight;

      if (goal.startingWeight != null) {
        startingWeight = goal.startingWeight!;
      } else {
        // Fallback to querying the first weight entry
        final db = await _dbHelper.database;
        final firstWeightResult = await db.rawQuery('''
          SELECT weight_kg FROM user_metrics
          WHERE user_id = ? AND measured_at >= ?
          ORDER BY measured_at ASC
          LIMIT 1
        ''', [goal.userId, goal.startDate.toIso8601String()]);

        if (firstWeightResult.isNotEmpty &&
            firstWeightResult.first['weight_kg'] != null) {
          startingWeight =
              (firstWeightResult.first['weight_kg'] as num).toDouble();
        } else {
          // Last fallback - use current progress
          startingWeight = goal.currentProgress;
        }
      }

      info['startingWeight'] = startingWeight;
      info['current'] = goal.currentProgress;

      // Determine if this is a weight loss or gain goal
      final isLoss = isWeightLossGoal(goal);
      final isGain = isWeightGainGoal(goal);

      info['isWeightLoss'] = isLoss;
      info['isWeightGain'] = isGain;

      // Calculate better progress percentage
      if (goal.targetValue != null) {
        info['progress'] = calculateWeightGoalPercentage(
            startingWeight, goal.currentProgress, goal.targetValue!);
      }

      // Get latest weight and change
      final db = await _dbHelper.database;
      final latestWeightResult = await db.rawQuery('''
        SELECT weight_kg, measured_at FROM user_metrics
        WHERE user_id = ?
        ORDER BY measured_at DESC
        LIMIT 1
      ''', [goal.userId]);

      if (latestWeightResult.isNotEmpty) {
        final latestWeight =
            (latestWeightResult.first['weight_kg'] as num).toDouble();
        final weightChange = latestWeight - startingWeight;

        info['latestWeight'] = latestWeight;
        info['weightChange'] = weightChange;

        // Format change for display
        if (isLoss) {
          info['formattedChange'] =
              '${weightChange <= 0 ? "" : "+"}${weightChange.toStringAsFixed(1)} kg since starting';
        } else {
          info['formattedChange'] =
              '${weightChange >= 0 ? "+" : ""}${weightChange.toStringAsFixed(1)} kg since starting';
        }
      }
    }

    return info;
  }

  // Get weight history for weight goal
  Future<List<Map<String, dynamic>>> getWeightProgressHistory(String userId,
      [DateTime? startDate, DateTime? endDate]) async {
    final db = await _dbHelper.database;

    String query = '''
      SELECT weight_kg, measured_at
      FROM user_metrics
      WHERE user_id = ?
    ''';

    List<dynamic> params = [userId];

    if (startDate != null) {
      query += ' AND measured_at >= ?';
      params.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      query += ' AND measured_at <= ?';
      params.add(endDate.toIso8601String());
    }

    query += ' ORDER BY measured_at ASC';

    final results = await db.rawQuery(query, params);

    // Convert to usable data points
    return results.map((record) {
      final weight = (record['weight_kg'] as num).toDouble();
      final date = DateTime.parse(record['measured_at'] as String);

      return {
        'date': date,
        'weight': weight,
        'formattedDate': '${date.day}/${date.month}',
      };
    }).toList();
  }

  // Log a new weight entry for the user
  Future<void> logUserWeight(double weight, [DateTime? date]) async {
    final userId = _getCurrentUserId();
    final measureDate = date ?? DateTime.now();

    // Insert the weight entry
    await _dbHelper.insertUserWeight(userId, weight, measureDate);

    // Update all weight goals
    final activeGoals = await _dbHelper.getActiveGoals(userId);

    for (final goal in activeGoals) {
      if (goal.goalId != null && goal.type == 'WeightTarget') {
        // Get previous progress and goal details to determine if we need to trigger notifications
        final previousProgress = goal.currentProgress;
        final previousGoal = Goal(
          goalId: goal.goalId,
          userId: goal.userId,
          type: goal.type,
          targetValue: goal.targetValue,
          startDate: goal.startDate,
          endDate: goal.endDate,
          achieved: goal.achieved,
          currentProgress: previousProgress,
        );

        // Update the goal's progress
        final newProgress = await calculateWeightGoalProgress(goal.goalId!);

        // Check for significant weight changes
        if (previousProgress > 0) {
          final weightChange = newProgress - previousProgress;
          final isWeightLoss = isWeightLossGoal(goal);

          // If the change is significant (more than 0.5kg)
          if (weightChange.abs() > 0.5) {
            // Trigger milestone notification if the direction is positive
            final isPositiveChange = (isWeightLoss && weightChange < 0) ||
                (!isWeightLoss && weightChange > 0);

            if (isPositiveChange) {
              // If cumulative change is significant, send a milestone notification
              final totalChange = newProgress - goal.currentProgress;

              if (totalChange.abs() >= 2.5) {
                await _notificationService.onWeightMilestone(
                    goal, totalChange, isWeightLoss);
              }
            }

            // Check if user is on track to meet their goal
            final daysElapsed =
                DateTime.now().difference(goal.startDate).inDays;
            final totalDays = goal.endDate.difference(goal.startDate).inDays;
            final progressPercentage = calculateWeightGoalPercentage(
                goal.currentProgress, // Starting weight
                newProgress, // Current weight
                goal.targetValue! // Target weight
                );

            // Time percentage elapsed
            final timePercentage = daysElapsed / totalDays;

            // On track if progress percentage >= time percentage
            final onTrack = progressPercentage >= timePercentage;

            // Notify about pace occasionally (not every log)
            if (timePercentage > 0.2 && weight % 3 < 0.1) {
              // roughly every 3rd entry
              await _notificationService.onWeightGoalPaceUpdate(
                  goal, onTrack, isWeightLoss);
            }
          }
        }
      }
    }
  }

  // Get check if there are any near-completion goals
  Future<List<Goal>> getNearCompletionGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getNearCompletionGoals(userId);
  }

  // Get goals that will expire soon
  Future<List<Goal>> getExpiringGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getExpiringGoals(userId);
  }

// Update an existing goal
  Future<void> updateGoal(Goal goal) async {
    if (goal.goalId == null) {
      throw Exception('Cannot update a goal without an ID');
    }

    // Get the original goal to compare and handle progress changes
    final originalGoal = await getGoalById(goal.goalId!);
    if (originalGoal == null) {
      throw Exception('Goal not found');
    }

    // Update the goal in the database through DatabaseHelper
    await _dbHelper.updateGoal(goal);

    // If target value changed, recalculate progress percentage
    if (originalGoal.targetValue != goal.targetValue) {
      if (goal.type == 'ExerciseTarget') {
        await calculateStrengthGoalProgress(goal.goalId!);
      } else if (goal.type == 'WorkoutFrequency') {
        await calculateFrequencyGoalProgress(goal.goalId!);
      } else if (goal.type == 'WeightTarget') {
        await calculateWeightGoalProgress(goal.goalId!);
      }
    }

    // Check if the goal is now achieved based on new target
    if (goal.currentProgress >= (goal.targetValue ?? 0) && !goal.achieved) {
      await _dbHelper.markGoalAchieved(goal.goalId!);
    }
  }

  Future<Goal?> getGoalById(int goalId) async {
    return await _dbHelper.getGoalById(goalId);
  }

  // Get historical progress data for an exercise
  Future<List<Map<String, dynamic>>> getExerciseProgressHistory(
      int exerciseId, String userId) async {
    final db = await _dbHelper.database;

    // Get the maximum weight for each date for this exercise
    final List<Map<String, dynamic>> maxWeightsByDate = await db.rawQuery('''
      SELECT MAX(ws.weight) as max_weight, w.date
      FROM workout_set ws
      JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
      JOIN workout w ON we.workout_id = w.workout_id
      WHERE we.exercise_id = ? AND w.user_id = ? AND ws.weight IS NOT NULL
      GROUP BY w.date
      ORDER BY w.date ASC
    ''', [exerciseId, userId]);

    // Convert to usable data points
    List<Map<String, dynamic>> progressPoints = [];

    for (var record in maxWeightsByDate) {
      final double maxWeight = (record['max_weight'] as num).toDouble();
      final DateTime date = DateTime.parse(record['date'] as String);

      progressPoints.add({
        'date': date,
        'weight': maxWeight,
        'formattedDate': '${date.day}/${date.month}',
      });
    }

    // Make sure points are sorted by date
    progressPoints.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return progressPoints;
  }
}
