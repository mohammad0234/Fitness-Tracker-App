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

  /// Sends notifications at key progress milestones (50%, 75%, 90%)
  /// Only triggers at specific thresholds to avoid notification fatigue
  Future<void> onGoalProgressUpdated(Goal goal, double previousProgress,
      {String? exerciseName}) async {
    if (goal.achieved) return; // Don't show progress for achieved goals

    final double progress = goal.currentProgress / (goal.targetValue ?? 1);
    final double prevProgressPercent =
        previousProgress / (goal.targetValue ?? 1);

    // Calculate milestone thresholds
    final bool reached50Percent = progress >= 0.5 && prevProgressPercent < 0.5;
    final bool reached75Percent =
        progress >= 0.75 && prevProgressPercent < 0.75;
    final bool reached90Percent = progress >= 0.9 && prevProgressPercent < 0.9;

    if (!reached50Percent && !reached75Percent && !reached90Percent) {
      return; // No milestone reached
    }

    // Get goal name
    String goalName;
    if (goal.type == 'WeightTarget') {
      goalName = 'Weight';
    } else {
      goalName = exerciseName ??
          (goal.type == 'WorkoutFrequency' ? 'Workout Frequency' : 'Strength');
    }

    String title = 'Goal Progress';
    String body;

    if (reached90Percent) {
      body = NotificationMessages.goalProgress(goalName, 0.9);
    } else if (reached75Percent) {
      body = NotificationMessages.goalProgress(goalName, 0.75);
    } else {
      body = NotificationMessages.goalProgress(goalName, 0.5);
    }

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

    debugPrint('Scheduled goal progress notification for ${goal.goalId}');
  }

  /// Alerts user when a goal is about to expire (within 3 days)
  /// Helps users focus on goals that need attention soon
  Future<void> onGoalNearingExpiration(Goal goal,
      {String? exerciseName}) async {
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
      9,
      0,
      0,
    );

    // System notification
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.goalCategory,
      payload: 'goal_${goal.goalId}',
    );

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'GoalProgress',
      message: body,
    );

    debugPrint('Scheduled goal expiration notification for ${goal.goalId}');
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

  // Performance notification triggers

  /// Celebrates when user achieves a new personal best for an exercise
  /// Immediate notification to recognize user achievement
  Future<void> onPersonalBest(int exerciseId, double weight) async {
    // Get exercise name
    final exercise = await _dbHelper.getExerciseById(exerciseId);
    if (exercise == null) return;

    final title = 'New Personal Best!';
    final body = NotificationMessages.personalBest(exercise.name, weight);

    // Schedule for immediate delivery (system notification)
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.performanceCategory,
      payload: 'personal_best_${exercise.exerciseId}',
    );

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'Milestone',
      message: body,
    );

    debugPrint('Scheduled personal best notification for ${exercise.name}');
  }

  /// Notifies user of significant improvements in workout volume
  /// Only triggers for improvements of 10% or more to avoid notification fatigue
  Future<void> onWorkoutVolumeImprovement(
      String muscleGroup, int percentageImprovement) async {
    if (percentageImprovement < 10)
      return; // Only notify for significant improvements

    final title = 'Progress Update';
    final body = NotificationMessages.progressInsight(
        muscleGroup, percentageImprovement);

    // Schedule for the next morning at 9 AM
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final scheduledDate =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0, 0);

    // System notification
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.performanceCategory,
      payload: 'volume_improvement_$muscleGroup',
    );

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'Milestone',
      message: body,
    );

    debugPrint('Scheduled volume improvement notification for $muscleGroup');
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

  /// Suggests a workout for a specific muscle group
  /// Scheduled for the next morning to encourage planning
  Future<void> scheduleWorkoutSuggestion(String muscleGroup) async {
    final title = 'Workout Suggestion';
    final body = NotificationMessages.workoutSuggestion(muscleGroup);

    // Schedule for 8 AM tomorrow
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final scheduledDate =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0, 0);

    // System notification
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.engagementCategory,
      payload: 'workout_suggestion_$muscleGroup',
    );

    // Create in-app notification
    await _inAppNotificationService.createNotification(
      type: 'Milestone', // Using Milestone type for consistency
      message: body,
    );

    debugPrint('Scheduled workout suggestion notification for $muscleGroup');
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

  /// Notifies user of significant weight milestones for their weight goals
  /// Triggers notifications at meaningful increments (every 2.5kg)
  Future<void> onWeightMilestone(
      Goal goal, double weightChange, bool isLoss) async {
    // Only notify at significant milestones (e.g., every 2.5kg)
    final significantChange = (weightChange.abs() % 2.5) < 0.1;
    if (!significantChange) return;

    final title = 'Weight Milestone';
    final body =
        NotificationMessages.weightMilestone(isLoss, weightChange.abs());

    // System notification
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.goalCategory,
      payload: 'goal_${goal.goalId}',
    );

    // In-app notification
    await _inAppNotificationService.createNotification(
      type: 'GoalProgress',
      message: body,
    );

    debugPrint('Scheduled weight milestone notification');
  }

  /// Updates user on progress toward their weight goal
  /// Provides feedback on whether user is on track or needs to adjust
  Future<void> onWeightGoalPaceUpdate(
      Goal goal, bool onTrack, bool isLoss) async {
    final title = 'Goal Progress Update';
    final body = NotificationMessages.weightGoalPace(isLoss, onTrack);

    // System notification
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      category: NotificationService.goalCategory,
      payload: 'goal_${goal.goalId}',
    );

    // In-app notification
    await _inAppNotificationService.createNotification(
      type: 'GoalProgress',
      message: body,
    );

    debugPrint('Scheduled weight pace notification');
  }

  /// Reminds user to log their weight for active weight goals
  /// Scheduled for the next morning to encourage consistent tracking
  Future<void> scheduleWeightLogReminder() async {
    // This would ideally be run by a periodic task,
    // here we'll just define the logic for when it's called

    final title = 'Action Needed';
    final body = NotificationMessages.weightLogReminder();

    // Schedule for a reasonable time (morning)
    final scheduledDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      9,
      0,
      0,
    ).add(const Duration(days: 1)); // Schedule for tomorrow morning

    // System notification
    await _notificationService.scheduleNotification(
      id: _notificationService.generateUniqueId(),
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      category: NotificationService.goalCategory,
    );

    debugPrint('Scheduled weight log reminder');
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
