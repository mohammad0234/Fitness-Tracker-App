import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:fitjourney/services/notification_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/utils/notification_helper.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/services/in_app_notification_service.dart';

/// Service to handle scheduling notifications based on app events and user activity
/// Acts as a bridge between app events and the notification delivery system
class NotificationTriggerService {
  // Singleton instance
  static final NotificationTriggerService instance =
      NotificationTriggerService._internal();

  // Private constructor
  NotificationTriggerService._internal();

  // Services
  final NotificationService _notificationService = NotificationService.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final InAppNotificationService _inAppNotificationService =
      InAppNotificationService.instance;

  // Goal-related notification triggers

  /// Schedules a notification when a goal is achieved
  /// Creates both system and in-app notifications to congratulate the user
  Future<void> onGoalAchieved(Goal goal, {String? exerciseName}) async {
    final goalName = exerciseName ??
        (goal.type == 'WorkoutFrequency' ? 'Workout Frequency' : 'Strength');

    final title = 'Goal Achieved!';
    final body = NotificationMessages.goalAchieved(goalName);

    // Schedule for immediate delivery (system notification)
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.goalCategory,
      payload: 'goal_${goal.goalId}',
    );

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'GoalProgress',
      message: body,
    );

    debugPrint('Scheduled goal achievement notification for ${goal.goalId}');
  }

  // Streak-related notification triggers

  /// Celebrates when user reaches streak milestones
  /// Helps reinforce positive user habits through recognition
  Future<void> onStreakMilestone(int streakDays) async {
    final title = 'New Streak Milestone!';
    final body = NotificationMessages.streakMilestone(streakDays);

    // Schedule for immediate delivery (system notification)
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.streakCategory,
      payload: 'streak_milestone_$streakDays',
    );

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'NewStreak',
      message: body,
    );

    debugPrint('Scheduled streak milestone notification for $streakDays days');
  }

  /// Reminds user to maintain their active streak
  /// Scheduled for evening (6 PM) if no activity was logged that day
  Future<void> onStreakMaintenanceRequired(int currentStreak) async {
    final title = 'Maintain Your Streak!';
    final body = NotificationMessages.streakMaintenance(currentStreak);

    // Schedule for 6 PM if no activity logged today
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, 18, 0, 0);

    // Only schedule if future time
    if (scheduledDate.isAfter(now)) {
      // System notification
      await _notificationService.scheduleNotification(
        id: _notificationService.generateUniqueId(),
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        category: NotificationService.streakCategory,
        payload: 'streak_maintenance',
      );

      // Create in-app notification
      await _inAppNotificationService.createNotification(
        type: 'NewStreak',
        message: body,
      );

      debugPrint(
          'Scheduled streak maintenance notification for $currentStreak streak');
    }
  }

  /// Sends urgent notification when streak is at risk of being broken
  /// Scheduled for later evening (8 PM) as a final reminder
  Future<void> onStreakAtRisk(int currentStreak) async {
    final title = 'Streak at Risk!';
    final body = NotificationMessages.streakAtRisk();

    // Schedule for 8 PM if no activity logged today
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, 20, 0, 0);

    // Only schedule if future time
    if (scheduledDate.isAfter(now)) {
      // System notification
      await _notificationService.scheduleNotification(
        id: _notificationService.generateUniqueId(),
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        category: NotificationService.streakCategory,
        payload: 'streak_at_risk',
      );

      // Create in-app notification
      await _inAppNotificationService.createNotification(
        type: 'NewStreak',
        message: body,
      );

      debugPrint(
          'Scheduled streak at risk notification for $currentStreak streak');
    }
  }

  // Engagement notification triggers

  /// Reminds inactive users to resume workouts
  /// Only triggers after 3+ days of inactivity to avoid being excessive
  Future<void> scheduleInactivityReminder(int daysWithoutWorkout) async {
    if (daysWithoutWorkout < 3) return; // Only remind after 3+ days

    final title = 'Missing Your Workouts';
    final body = NotificationMessages.inactivityReminder(daysWithoutWorkout);

    // Schedule for 10 AM
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, 10, 0, 0);

    // System notification
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.engagementCategory,
      payload: 'inactivity_reminder',
    );

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'NewStreak', // Using NewStreak type for consistency
      message: body,
    );

    debugPrint(
        'Scheduled inactivity reminder notification after $daysWithoutWorkout days');
  }

  /// Checks and schedules streak reminders if needed
  /// Based on user's current streak status and activity for the day
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

  /// Returns the current user ID or throws exception if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }
}
