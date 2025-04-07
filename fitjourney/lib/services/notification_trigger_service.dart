import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:fitjourney/services/notification_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/utils/notification_helper.dart';
import 'package:fitjourney/database/database_helper.dart';

/// Service to handle scheduling notifications based on app events
class NotificationTriggerService {
  // Singleton instance
  static final NotificationTriggerService instance = NotificationTriggerService._internal();
  
  // Private constructor
  NotificationTriggerService._internal();
  
  // Services
  final NotificationService _notificationService = NotificationService.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Goal-related notification triggers
  
  /// Schedule a notification for goal achievement
  Future<void> onGoalAchieved(Goal goal, {String? exerciseName}) async {
    final goalName = exerciseName ?? 
      (goal.type == 'WorkoutFrequency' ? 'Workout Frequency' : 'Strength');
    
    final title = 'Goal Achieved!';
    final body = NotificationMessages.goalAchieved(goalName);
    
    // Schedule for immediate delivery
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.goalCategory,
      payload: 'goal_${goal.goalId}',
    );
    
    debugPrint('Scheduled goal achievement notification for ${goal.goalId}');
  }
  
  /// Schedule a notification for goal progress (at key milestones: 50%, 75%, 90%)
  Future<void> onGoalProgressUpdated(Goal goal, double previousProgress, {String? exerciseName}) async {
    if (goal.achieved) return; // Don't show progress for achieved goals
    
    final double progress = goal.currentProgress / (goal.targetValue ?? 1);
    final double prevProgressPercent = previousProgress / (goal.targetValue ?? 1);
    
    // Calculate milestone thresholds
    final bool reached50Percent = progress >= 0.5 && prevProgressPercent < 0.5;
    final bool reached75Percent = progress >= 0.75 && prevProgressPercent < 0.75;
    final bool reached90Percent = progress >= 0.9 && prevProgressPercent < 0.9;
    
    if (!reached50Percent && !reached75Percent && !reached90Percent) {
      return; // No milestone reached
    }
    
    // Get goal name
    final goalName = exerciseName ?? 
      (goal.type == 'WorkoutFrequency' ? 'Workout Frequency' : 'Strength');
    
    String title = 'Goal Progress';
    String body;
    
    if (reached90Percent) {
      body = NotificationMessages.goalProgress(goalName, 0.9);
    } else if (reached75Percent) {
      body = NotificationMessages.goalProgress(goalName, 0.75);
    } else {
      body = NotificationMessages.goalProgress(goalName, 0.5);
    }
    
    // Schedule for immediate delivery
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.goalCategory,
      payload: 'goal_${goal.goalId}',
    );
    
    debugPrint('Scheduled goal progress notification for ${goal.goalId}');
  }
  
  /// Schedule a notification for goal expiration warning
  Future<void> onGoalNearingExpiration(Goal goal, {String? exerciseName}) async {
    if (goal.achieved) return; // Don't notify for achieved goals
    
    final daysLeft = goal.endDate.difference(DateTime.now()).inDays;
    if (daysLeft > 3) return; // Only notify if 3 or fewer days left
    
    final goalName = exerciseName ?? 
      (goal.type == 'WorkoutFrequency' ? 'Workout Frequency' : 'Strength');
    
    final title = 'Goal Expiring Soon';
    final body = NotificationMessages.goalExpiring(goalName, daysLeft);
    
    // Schedule for notification at a reasonable time (9 AM)
    final scheduledDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      9, 0, 0,
    );
    
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.goalCategory,
      payload: 'goal_${goal.goalId}',
    );
    
    debugPrint('Scheduled goal expiration notification for ${goal.goalId}');
  }
  
  // Streak-related notification triggers
  
  /// Schedule a notification for streak milestone
  Future<void> onStreakMilestone(int streakDays) async {
    final title = 'New Streak Milestone!';
    final body = NotificationMessages.streakMilestone(streakDays);
    
    // Schedule for immediate delivery
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.streakCategory,
      payload: 'streak_milestone_$streakDays',
    );
    
    debugPrint('Scheduled streak milestone notification for $streakDays days');
  }
  
  /// Schedule a notification reminding to maintain streak
  Future<void> onStreakMaintenanceRequired(int currentStreak) async {
    final title = 'Maintain Your Streak!';
    final body = NotificationMessages.streakMaintenance(currentStreak);
    
    // Schedule for 6 PM if no activity logged today
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, 18, 0, 0);
    
    // Only schedule if future time
    if (scheduledDate.isAfter(now)) {
      await _notificationService.scheduleNotification(
        id: _notificationService.generateUniqueId(),
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        category: NotificationService.streakCategory,
        payload: 'streak_maintenance',
      );
      
      debugPrint('Scheduled streak maintenance notification for $currentStreak streak');
    }
  }
  
  /// Schedule a notification warning about streak at risk
  Future<void> onStreakAtRisk(int currentStreak) async {
    final title = 'Streak at Risk!';
    final body = NotificationMessages.streakAtRisk();
    
    // Schedule for 8 PM if no activity logged today
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, 20, 0, 0);
    
    // Only schedule if future time
    if (scheduledDate.isAfter(now)) {
      await _notificationService.scheduleNotification(
        id: _notificationService.generateUniqueId(),
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        category: NotificationService.streakCategory,
        payload: 'streak_at_risk',
      );
      
      debugPrint('Scheduled streak at risk notification for $currentStreak streak');
    }
  }
  
  // Performance notification triggers
  
  /// Schedule a notification for personal best achievement
  Future<void> onPersonalBest(int exerciseId, double weight) async {
    // Get exercise name
    final exercise = await _dbHelper.getExerciseById(exerciseId);
    if (exercise == null) return;
    
    final title = 'New Personal Best!';
    final body = NotificationMessages.personalBest(exercise.name, weight);
    
    // Schedule for immediate delivery
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.performanceCategory,
      payload: 'personal_best_${exercise.exerciseId}',
    );
    
    debugPrint('Scheduled personal best notification for ${exercise.name}');
  }
  
  /// Schedule a notification for workout volume improvement
  Future<void> onWorkoutVolumeImprovement(String muscleGroup, int percentageImprovement) async {
    if (percentageImprovement < 10) return; // Only notify for significant improvements
    
    final title = 'Progress Update';
    final body = NotificationMessages.progressInsight(muscleGroup, percentageImprovement);
    
    // Schedule for the next morning at 9 AM
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final scheduledDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0, 0);
    
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.performanceCategory,
      payload: 'volume_improvement_$muscleGroup',
    );
    
    debugPrint('Scheduled volume improvement notification for $muscleGroup');
  }
  
  // Engagement notification triggers
  
  /// Schedule a notification for inactivity reminder
  Future<void> scheduleInactivityReminder(int daysWithoutWorkout) async {
    if (daysWithoutWorkout < 3) return; // Only remind after 3+ days
    
    final title = 'Missing Your Workouts';
    final body = NotificationMessages.inactivityReminder(daysWithoutWorkout);
    
    // Schedule for 10 AM
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, 10, 0, 0);
    
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.engagementCategory,
      payload: 'inactivity_reminder',
    );
    
    debugPrint('Scheduled inactivity reminder notification after $daysWithoutWorkout days');
  }
  
  /// Schedule a notification suggesting a workout
  Future<void> scheduleWorkoutSuggestion(String muscleGroup) async {
    final title = 'Workout Suggestion';
    final body = NotificationMessages.workoutSuggestion(muscleGroup);
    
    // Schedule for 8 AM tomorrow
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final scheduledDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0, 0);
    
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.engagementCategory,
      payload: 'workout_suggestion_$muscleGroup',
    );
    
    debugPrint('Scheduled workout suggestion notification for $muscleGroup');
  }
  
  /// Schedule daily streak check notification
  Future<void> scheduleDailyStreakCheck() async {
    // Determine if user has a streak
    try {
      // Get the current streak from database
      final streak = await _dbHelper.getStreakForUser(_getCurrentUserId());
      
      if (streak != null && streak.currentStreak > 0) {
        // Check if activity logged today
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        if (streak.lastActivityDate == null ||
            streak.lastActivityDate!.isBefore(today)) {
          // No activity today, schedule streak reminder
          await onStreakMaintenanceRequired(streak.currentStreak);
        }
      }
    } catch (e) {
      debugPrint('Error scheduling daily streak check: $e');
    }
  }
  
  // Helper method to get current user ID
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }
}