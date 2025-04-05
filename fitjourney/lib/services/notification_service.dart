import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Initialize the notification service
  Future<void> init() async {
    tz.initializeTimeZones();

    // Define initialization settings for Android
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Define initialization settings
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Initialize the plugin with the new callback approach
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          debugPrint('notification payload: ${response.payload}');
          selectNotificationSubject.add(response.payload);
        }
      },
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    // Goal notification channel
    AndroidNotificationChannel goalChannel = const AndroidNotificationChannel(
      goalCategory,
      'Goal Notifications',
      description: 'Notifications related to your fitness goals',
      importance: Importance.high,
    );

    // Streak notification channel
    AndroidNotificationChannel streakChannel = const AndroidNotificationChannel(
      streakCategory,
      'Streak Notifications',
      description: 'Notifications related to your workout streaks',
      importance: Importance.high,
    );

    // Performance notification channel
    AndroidNotificationChannel performanceChannel = const AndroidNotificationChannel(
      performanceCategory,
      'Performance Notifications',
      description: 'Notifications about your fitness performance',
      importance: Importance.defaultImportance,
    );

    // Engagement notification channel
    AndroidNotificationChannel engagementChannel = const AndroidNotificationChannel(
      engagementCategory,
      'Engagement Notifications',
      description: 'Reminders and suggestions for your workouts',
      importance: Importance.defaultImportance,
    );

    // Create the channels
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(goalChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(streakChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(performanceChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(engagementChannel);
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    required String category,
  }) async {
    // Check if notifications are enabled for this category
    final prefs = await SharedPreferences.getInstance();
    final categoryEnabled = prefs.getBool('${category}_enabled') ?? true;
    
    if (!categoryEnabled) {
      debugPrint('Notifications disabled for category: $category');
      return;
    }

    // Check if within quiet hours
    if (await _isInQuietHours(scheduledDate)) {
      debugPrint('Notification scheduled during quiet hours, skipping');
      return;
    }

    // Android-specific notification details
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      category,
      getCategoryName(category),
      channelDescription: 'Notifications for $category',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // Platform-specific notification details
    NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // Schedule the notification with the new required parameter
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint('Scheduled notification: ID=$id, Title=$title, Date=$scheduledDate');
  }

  // Check if a time is within quiet hours
  Future<bool> _isInQuietHours(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
    
    if (!quietHoursEnabled) {
      return false;
    }
    
    final quietHoursStart = prefs.getInt('quiet_hours_start') ?? 22; // 10 PM
    final quietHoursEnd = prefs.getInt('quiet_hours_end') ?? 8; // 8 AM
    
    final hour = time.hour;
    
    if (quietHoursStart <= quietHoursEnd) {
      // Simple case: e.g., 22:00 to 08:00
      return hour >= quietHoursStart || hour < quietHoursEnd;
    } else {
      // Wrap around case: e.g., 22:00 to 08:00
      return hour >= quietHoursStart || hour < quietHoursEnd;
    }
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Get a readable name for notification categories
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

  // Generate a unique notification ID
  int generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }

  // Dispose resources
  void dispose() {
    selectNotificationSubject.close();
  }
}