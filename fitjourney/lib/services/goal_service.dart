// lib/services/goal_service.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/database_models/exercise.dart';
import 'package:fitjourney/services/workout_service.dart';

class GoalService {
  // Singleton instance
  static final GoalService instance = GoalService._internal();
  
  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
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
      return 0.0;
    }
    
    // Get personal best for this exercise
    final personalBest = await _dbHelper.getPersonalBestForExercise(
      goal.userId, 
      goal.exerciseId!
    );
    
    if (personalBest == null || personalBest['max_weight'] == null) {
      return goal.currentProgress;
    }
    
    final maxWeight = personalBest['max_weight'] as double;
    
    // Calculate progress percentage (capped at 100%)
    double progressPercent = (maxWeight / goal.targetValue!) * 100;
    if (progressPercent > 100) progressPercent = 100;
    
    // Update goal's progress
    await updateGoalProgress(goalId, maxWeight);
    
    return maxWeight;
  }
  
  // Calculate current progress for frequency goal
  Future<double> calculateFrequencyGoalProgress(int goalId) async {
    final goal = await _dbHelper.getGoalById(goalId);
    if (goal == null || goal.targetValue == null) {
      return 0.0;
    }
    
    // Count workouts in date range
    final workoutCount = await _dbHelper.countWorkoutsInDateRange(
      goal.userId,
      goal.startDate,
      goal.endDate
    );
    
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
      }
    }
    
    // Also check for expired goals
    await _dbHelper.updateAllGoalStatuses(userId);
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
      final exercise = await WorkoutService.instance.getExerciseById(goal.exerciseId!);
      if (exercise != null) {
        info['exerciseName'] = exercise.name;
        info['muscleGroup'] = exercise.muscleGroup;
        info['title'] = '${exercise.name} Strength Goal';
        info['current'] = goal.currentProgress;
        info['target'] = goal.targetValue;
      }
    } else if (goal.type == 'WorkoutFrequency') {
      // For frequency goals
      final totalWeeks = goal.endDate.difference(goal.startDate).inDays / 7;
      info['title'] = 'Workout Frequency Goal';
      info['current'] = goal.currentProgress;
      info['target'] = goal.targetValue;
      info['weeklyTarget'] = (goal.targetValue ?? 0) / totalWeeks;
    }
    
    return info;
  }
  
  // Check if there are any near-completion goals
  Future<List<Goal>> getNearCompletionGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getNearCompletionGoals(userId);
  }
  
  // Get goals that will expire soon
  Future<List<Goal>> getExpiringGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getExpiringGoals(userId);
  }
}