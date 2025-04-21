import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:fitjourney/utils/notification_helper.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/services/in_app_notification_service.dart';
import 'package:fitjourney/database_models/goal.dart';

/// Service to handle creating in-app notifications based on app events and user activity
class NotificationTriggerService {
  // Singleton instance
  static final NotificationTriggerService instance =
      NotificationTriggerService._internal();

  // Private constructor
  NotificationTriggerService._internal();

  // Services
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final InAppNotificationService _inAppNotificationService =
      InAppNotificationService.instance;

  // Goal-related notification triggers

  /// Creates an in-app notification when a goal is achieved
  Future<void> onGoalAchieved(Goal goal, {String? exerciseName}) async {
    final goalName = exerciseName ??
        (goal.type == 'WorkoutFrequency' ? 'Workout Frequency' : 'Strength');

    final body = NotificationMessages.goalAchieved(goalName);

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'GoalProgress',
      message: body,
    );

    debugPrint('Created goal achievement notification for ${goal.goalId}');
  }

  // Streak-related notification triggers

  /// Creates notification when user reaches streak milestones
  Future<void> onStreakMilestone(int streakDays) async {
    final body = NotificationMessages.streakMilestone(streakDays);

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'NewStreak',
      message: body,
    );

    debugPrint('Created streak milestone notification for $streakDays days');
  }

  /// Creates notification to maintain active streak
  Future<void> onStreakMaintenanceRequired(int currentStreak) async {
    final body = NotificationMessages.streakMaintenance(currentStreak);

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'NewStreak',
      message: body,
    );

    debugPrint(
        'Created streak maintenance notification for $currentStreak streak');
  }

  /// Creates notification when streak is at risk of being broken
  Future<void> onStreakAtRisk(int currentStreak) async {
    final body = NotificationMessages.streakAtRisk();

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'NewStreak',
      message: body,
    );

    debugPrint('Created streak at risk notification for $currentStreak streak');
  }

  // Engagement notification triggers

  /// Creates notification to remind inactive users to resume workouts
  /// Only triggers after 3+ days of inactivity to avoid being excessive
  Future<void> scheduleInactivityReminder(int daysWithoutWorkout) async {
    if (daysWithoutWorkout < 3) return; // Only remind after 3+ days

    final body = NotificationMessages.inactivityReminder(daysWithoutWorkout);

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'NewStreak', // Using NewStreak type for consistency
      message: body,
    );

    debugPrint(
        'Created inactivity reminder notification after $daysWithoutWorkout days');
  }

  /// Checks and creates streak reminders if needed
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
          // No activity today, create streak reminder
          await onStreakMaintenanceRequired(streak.currentStreak);
        }
      }
    } catch (e) {
      debugPrint('Error checking streak status: $e');
    }
  }

  /// Creates notification for a significant achievement or milestone
  Future<void> onMilestoneAchieved(String title, String description) async {
    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'Milestone',
      message: description,
    );

    debugPrint('Created milestone notification: $title');
  }

  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }
}
