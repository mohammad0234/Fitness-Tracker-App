// lib/services/goal_tracking_service.dart

import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class GoalTrackingService {
  // Singleton instance
  static final GoalTrackingService instance = GoalTrackingService._internal();
  
  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final GoalService _goalService = GoalService.instance;
  
  // Private constructor
  GoalTrackingService._internal();
  
  // Get the current user ID or throw an error if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }
  
  // Update goals after a workout is logged
  Future<void> updateGoalsAfterWorkout(Workout workout) async {
    final userId = _getCurrentUserId();
    
    // Get all active goals
    final activeGoals = await _dbHelper.getActiveGoals(userId);
    
    // Check each goal type and update as needed
    for (final goal in activeGoals) {
      if (goal.goalId == null) continue;
      
      if (goal.type == 'WorkoutFrequency') {
        // For frequency goals, recalculate based on new workout
        await _updateFrequencyGoal(goal);
      }
      // For strength goals, these are updated when personal bests are updated
    }
  }
  
  // Update goals after a personal best is recorded
  Future<void> updateGoalsAfterPersonalBest(int exerciseId, double weight) async {
    final userId = _getCurrentUserId();
    
    // Find strength goals for this exercise
    final activeGoals = await _dbHelper.getActiveGoals(userId);
    
    for (final goal in activeGoals) {
      if (goal.goalId == null) continue;
      
      if (goal.type == 'ExerciseTarget' && goal.exerciseId == exerciseId) {
        // Update the goal progress
        await _updateStrengthGoal(goal, weight);
      }
    }
  }
  
  // Update a frequency goal
  Future<void> _updateFrequencyGoal(Goal goal) async {
    if (goal.goalId == null) return;
    
    // Count workouts in date range
    final workoutCount = await _dbHelper.countWorkoutsInDateRange(
      goal.userId,
      goal.startDate,
      goal.endDate
    );
    
    // Calculate progress percentage
    final double progress = workoutCount.toDouble();
    final double targetValue = goal.targetValue ?? 1.0;
    
    // Update the goal
    await _dbHelper.updateGoalProgress(goal.goalId!, progress);
    
    // Check if goal is achieved
    if (progress >= targetValue && !goal.achieved) {
      await _dbHelper.markGoalAchieved(goal.goalId!);
      // Create milestone entry is handled in markGoalAchieved
    }
  }
  
  // Update a strength goal
  Future<void> _updateStrengthGoal(Goal goal, double currentWeight) async {
    if (goal.goalId == null) return;
    
    // Update the goal progress
    await _dbHelper.updateGoalProgress(goal.goalId!, currentWeight);
    
    // Check if goal is achieved
    final double targetValue = goal.targetValue ?? 0.0;
    if (currentWeight >= targetValue && !goal.achieved) {
      await _dbHelper.markGoalAchieved(goal.goalId!);
      // Create milestone entry is handled in markGoalAchieved
    }
  }
  
  // Daily check for expired goals
  Future<void> checkExpiredGoals() async {
    final userId = _getCurrentUserId();
    await _dbHelper.updateAllGoalStatuses(userId);
  }
  
  // Check for goals that are near completion (for notifications)
  Future<List<Goal>> getNearCompletionGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getNearCompletionGoals(userId);
  }
  
  // Check for goals that are about to expire (for notifications)
  Future<List<Goal>> getExpiringGoals() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getExpiringGoals(userId);
  }

  Future<void> performDailyGoalUpdate() async {
  try {
    final userId = _getCurrentUserId();
    
    // Update all goal statuses (completed, expired)
    await _dbHelper.updateAllGoalStatuses(userId);
    
    // Update all goal progress
    final activeGoals = await _dbHelper.getActiveGoals(userId);
    
    for (final goal in activeGoals) {
      if (goal.goalId == null) continue;
      
      if (goal.type == 'ExerciseTarget') {
        await _goalService.calculateStrengthGoalProgress(goal.goalId!);
      } else if (goal.type == 'WorkoutFrequency') {
        await _goalService.calculateFrequencyGoalProgress(goal.goalId!);
      }
    }
    
    // Update streak data (if implemented)
    // await updateStreaks();
    
    print('Daily goal update completed');
  } catch (e) {
    print('Error performing daily goal update: $e');
  }
}
}