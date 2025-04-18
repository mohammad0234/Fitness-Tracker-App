import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'dart:io' show Platform;

/// Service for handling system notifications including scheduling, categorizing, and managing app notifications
class NotificationService {
  // Singleton instance
  static final NotificationService instance = NotificationService._internal();

  // Private constructor
  NotificationService._internal();

  // Define notification plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Stream for receiving notification responses
  final BehaviorSubject<String?> selectNotificationSubject =
      BehaviorSubject<String?>();

  // Notification categories
  static const String goalCategory = 'goal_notifications';
  static const String streakCategory = 'streak_notifications';
  static const String performanceCategory = 'performance_notifications';
  static const String engagementCategory = 'engagement_notifications';

  /// Initializes the notification service and creates notification channels
  Future<void> init() async {
    tz.initializeTimeZones();

    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          debugPrint('notification payload: ${response.payload}');
          selectNotificationSubject.add(response.payload);
        }
      },
    );

    await _createNotificationChannels();
  }

  /// Creates Android notification channels for different notification types
  Future<void> _createNotificationChannels() async {
    AndroidNotificationChannel goalChannel = const AndroidNotificationChannel(
      goalCategory,
      'Goal Notifications',
      description: 'Notifications related to your fitness goals',
      importance: Importance.high,
    );

    AndroidNotificationChannel streakChannel = const AndroidNotificationChannel(
      streakCategory,
      'Streak Notifications',
      description: 'Notifications related to your workout streaks',
      importance: Importance.high,
    );

    AndroidNotificationChannel performanceChannel =
        const AndroidNotificationChannel(
      performanceCategory,
      'Performance Notifications',
      description: 'Notifications about your fitness performance',
      importance: Importance.defaultImportance,
    );

    AndroidNotificationChannel engagementChannel =
        const AndroidNotificationChannel(
      engagementCategory,
      'Engagement Notifications',
      description: 'Reminders and suggestions for your workouts',
      importance: Importance.defaultImportance,
    );

    final androidPlatform =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlatform?.createNotificationChannel(goalChannel);
    await androidPlatform?.createNotificationChannel(streakChannel);
    await androidPlatform?.createNotificationChannel(performanceChannel);
    await androidPlatform?.createNotificationChannel(engagementChannel);
  }

  /// Schedules a notification for delivery at the specified date and time
  /// Respects user preferences for notification categories and quiet hours
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    required String category,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final categoryEnabled = prefs.getBool('${category}_enabled') ?? true;

    if (!categoryEnabled) {
      debugPrint('Notifications disabled for category: $category');
      return;
    }

    if (await _isInQuietHours(scheduledDate)) {
      debugPrint('Notification scheduled during quiet hours, skipping');
      return;
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      category,
      getCategoryName(category),
      channelDescription: 'Notifications for $category',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
        'Scheduled notification: ID=$id, Title=$title, Date=$scheduledDate');
  }

  /// Checks if a given time falls within the user's configured quiet hours
  Future<bool> _isInQuietHours(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? false;

    if (!quietHoursEnabled) return false;

    final quietHoursStart = prefs.getInt('quiet_hours_start') ?? 22; // 10 PM
    final quietHoursEnd = prefs.getInt('quiet_hours_end') ?? 8; // 8 AM
    final hour = time.hour;

    if (quietHoursStart <= quietHoursEnd) {
      return hour >= quietHoursStart || hour < quietHoursEnd;
    } else {
      return hour >= quietHoursStart || hour < quietHoursEnd;
    }
  }

  /// Cancels a specific notification by ID
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancels all pending notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Returns a readable name for a notification category
  String getCategoryName(String category) {
    switch (category) {
      case goalCategory:
        return 'Goal Notifications';
      case streakCategory:
        return 'Streak Notifications';
      case performanceCategory:
        return 'Performance Notifications';
      case engagementCategory:
        return 'Engagement Notifications';
      default:
        return 'Notifications';
    }
  }

  /// Generates a unique notification ID based on current timestamp
  int generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }

  /// Opens system settings for exact alarm permissions
  Future<void> openExactAlarmSettings() async {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    }
  }

  /// Disposes resources used by the notification service
  void dispose() {
    selectNotificationSubject.close();
  }
}
