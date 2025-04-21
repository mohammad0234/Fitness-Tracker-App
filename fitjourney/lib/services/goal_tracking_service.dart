// lib/services/goal_tracking_service.dart

import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/services/notification_trigger_service.dart';
import 'package:flutter/material.dart';

class GoalTrackingService {
  // Singleton instance
  static final GoalTrackingService instance = GoalTrackingService._internal();

  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final GoalService _goalService = GoalService.instance;
  final NotificationTriggerService _notificationTriggerService =
      NotificationTriggerService.instance;

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
  Future<void> updateGoalsAfterPersonalBest(
      int exerciseId, double weight) async {
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

    // Get previous progress for comparison

    // Count workouts in date range
    final workoutCount = await _dbHelper.countWorkoutsInDateRange(
        goal.userId, goal.startDate, goal.endDate);

    // Calculate progress percentage
    final double progress = workoutCount.toDouble();
    final double targetValue = goal.targetValue ?? 1.0;

    // Update the goal
    await _dbHelper.updateGoalProgress(goal.goalId!, progress);

    // Check if goal is achieved
    if (progress >= targetValue && !goal.achieved) {
      await _dbHelper.markGoalAchieved(goal.goalId!);

      // Send notification for goal achievement
      await _notificationTriggerService.onGoalAchieved(
        Goal(
          goalId: goal.goalId,
          userId: goal.userId,
          type: goal.type,
          targetValue: goal.targetValue,
          startDate: goal.startDate,
          endDate: goal.endDate,
          achieved: true,
          currentProgress: progress,
        ),
      );
    }
  }

  // Update a strength goal
  Future<void> _updateStrengthGoal(Goal goal, double currentWeight) async {
    if (goal.goalId == null) return;

    // Get previous progress for comparison

    // Update the goal progress
    await _dbHelper.updateGoalProgress(goal.goalId!, currentWeight);

    // Get exercise name for notification
    String? exerciseName;
    if (goal.exerciseId != null) {
      final exercise = await _dbHelper.getExerciseById(goal.exerciseId!);
      exerciseName = exercise?.name;
    }

    // Check if goal is achieved
    final double targetValue = goal.targetValue ?? 0.0;
    if (currentWeight >= targetValue && !goal.achieved) {
      await _dbHelper.markGoalAchieved(goal.goalId!);

      // Send notification for goal achievement
      await _notificationTriggerService.onGoalAchieved(
        Goal(
          goalId: goal.goalId,
          userId: goal.userId,
          type: goal.type,
          exerciseId: goal.exerciseId,
          targetValue: goal.targetValue,
          startDate: goal.startDate,
          endDate: goal.endDate,
          achieved: true,
          currentProgress: currentWeight,
        ),
        exerciseName: exerciseName,
      );
    }
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

      debugPrint('Daily goal update completed');
    } catch (e) {
      debugPrint('Error performing daily goal update: $e');
    }
  }
}
