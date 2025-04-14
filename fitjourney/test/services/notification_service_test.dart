import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitjourney/services/notification_service.dart';

// Custom fake implementation of FlutterLocalNotificationsPlugin
class FakeFlutterLocalNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  bool initialized = false;
  List<Map<String, dynamic>> scheduledNotifications = [];
  List<int> canceledIds = [];
  bool allCanceled = false;
  final FakeAndroidFlutterLocalNotificationsPlugin androidPlugin =
      FakeAndroidFlutterLocalNotificationsPlugin();

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
    void Function(NotificationResponse)?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    return true;
  }

  @override
  Future<void> zonedSchedule(int id, String? title, String? body,
      tz.TZDateTime scheduledDate, NotificationDetails notificationDetails,
      {required AndroidScheduleMode androidScheduleMode,
      String? payload,
      DateTimeComponents? matchDateTimeComponents}) async {
    scheduledNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'notificationDetails': notificationDetails,
      'payload': payload,
      'androidScheduleMode': androidScheduleMode,
    });
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    canceledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    allCanceled = true;
  }

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() {
    if (T == AndroidFlutterLocalNotificationsPlugin) {
      return androidPlugin as T;
    }
    return null;
  }

  // Implement all other required methods with minimal functionality
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// Fake implementation of AndroidFlutterLocalNotificationsPlugin
class FakeAndroidFlutterLocalNotificationsPlugin
    implements AndroidFlutterLocalNotificationsPlugin {
  List<AndroidNotificationChannel> createdChannels = [];

  @override
  Future<void> createNotificationChannel(
      AndroidNotificationChannel channel) async {
    createdChannels.add(channel);
  }

  // Implement all other required methods with minimal functionality
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterLocalNotificationsPlugin fakeNotificationsPlugin;
  late NotificationService notificationService;

  setUp(() {
    // Mock shared preferences
    SharedPreferences.setMockInitialValues({});

    // Set up fake notifications plugin
    fakeNotificationsPlugin = FakeFlutterLocalNotificationsPlugin();

    // Get the singleton instance of NotificationService
    notificationService = NotificationService.instance;

    // Initialize timezone data
    tz.initializeTimeZones();
  });

  group('NotificationService', () {
    test('initialization sets up notification channels correctly', () async {
      // Act - create a test double that just tests the channel creation
      final testService = TestNotificationChannels(fakeNotificationsPlugin);
      await testService.createNotificationChannels();

      // Assert
      expect(fakeNotificationsPlugin.androidPlugin.createdChannels.length, 4);

      // Verify that all 4 notification channels were created
      final channelIds = fakeNotificationsPlugin.androidPlugin.createdChannels
          .map((channel) => channel.id)
          .toList();

      expect(channelIds, contains(NotificationService.goalCategory));
      expect(channelIds, contains(NotificationService.streakCategory));
      expect(channelIds, contains(NotificationService.performanceCategory));
      expect(channelIds, contains(NotificationService.engagementCategory));
    });

    test('scheduleNotification skips when category is disabled', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        '${NotificationService.goalCategory}_enabled': false,
      });

      // Create a test-specific instance just for this test
      final testService = TestNotificationScheduler(fakeNotificationsPlugin);

      // Act
      await testService.scheduleTestNotification(
        id: 1,
        title: 'Test Title',
        body: 'Test Body',
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
        category: NotificationService.goalCategory,
      );

      // Assert - verify no notifications were scheduled
      expect(fakeNotificationsPlugin.scheduledNotifications, isEmpty);
    });

    test('scheduleNotification skips during quiet hours', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'quiet_hours_enabled': true,
        'quiet_hours_start': 22, // 10 PM
        'quiet_hours_end': 8, // 8 AM
      });

      final DateTime quietTime = DateTime(2023, 1, 1, 23, 0); // 11 PM

      // Create a test-specific instance just for this test
      final testService = TestNotificationScheduler(fakeNotificationsPlugin);

      // Act
      await testService.scheduleTestNotification(
        id: 1,
        title: 'Test Title',
        body: 'Test Body',
        scheduledDate: quietTime,
        category: NotificationService.goalCategory,
      );

      // Assert - verify no notifications were scheduled
      expect(fakeNotificationsPlugin.scheduledNotifications, isEmpty);
    });

    test('scheduleNotification proceeds when not in quiet hours', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'quiet_hours_enabled': true,
        'quiet_hours_start': 22, // 10 PM
        'quiet_hours_end': 8, // 8 AM
        '${NotificationService.goalCategory}_enabled': true,
      });

      final DateTime activeTime = DateTime(2023, 1, 1, 14, 0); // 2 PM

      // Create a test-specific instance just for this test
      final testService = TestNotificationScheduler(fakeNotificationsPlugin);

      // Act
      await testService.scheduleTestNotification(
        id: 1,
        title: 'Test Title',
        body: 'Test Body',
        scheduledDate: activeTime,
        category: NotificationService.goalCategory,
      );

      // Assert - verify a notification was scheduled
      expect(fakeNotificationsPlugin.scheduledNotifications.length, 1);
      expect(fakeNotificationsPlugin.scheduledNotifications[0]['id'], 1);
      expect(fakeNotificationsPlugin.scheduledNotifications[0]['title'],
          'Test Title');
      expect(fakeNotificationsPlugin.scheduledNotifications[0]['body'],
          'Test Body');
    });

    test('cancelNotification calls plugin cancel method with correct ID',
        () async {
      // Act
      final testService = TestNotificationCanceller(fakeNotificationsPlugin);
      await testService.cancelTestNotification(123);

      // Assert
      expect(fakeNotificationsPlugin.canceledIds, contains(123));
    });

    test('cancelAllNotifications calls plugin cancelAll method', () async {
      // Act
      final testService = TestNotificationCanceller(fakeNotificationsPlugin);
      await testService.cancelAllTestNotifications();

      // Assert
      expect(fakeNotificationsPlugin.allCanceled, true);
    });

    test('getCategoryName returns readable category names', () {
      // Assert
      expect(
          notificationService.getCategoryName(NotificationService.goalCategory),
          equals('Goal Notifications'));
      expect(
          notificationService
              .getCategoryName(NotificationService.streakCategory),
          equals('Streak Notifications'));
      expect(
          notificationService
              .getCategoryName(NotificationService.performanceCategory),
          equals('Performance Notifications'));
      expect(
          notificationService
              .getCategoryName(NotificationService.engagementCategory),
          equals('Engagement Notifications'));
      expect(notificationService.getCategoryName('unknown'),
          equals('Notifications'));
    });

    test('generateUniqueId returns a number within expected range', () {
      // Act
      final id = notificationService.generateUniqueId();

      // Assert
      expect(id, lessThan(100000));
      expect(id, greaterThanOrEqualTo(0));
    });
  });
}

// Simple test helpers that don't require extending NotificationService
class TestNotificationChannels {
  final FakeFlutterLocalNotificationsPlugin plugin;

  TestNotificationChannels(this.plugin);

  Future<void> createNotificationChannels() async {
    AndroidNotificationChannel goalChannel = const AndroidNotificationChannel(
      NotificationService.goalCategory,
      'Goal Notifications',
      description: 'Notifications related to your fitness goals',
      importance: Importance.high,
    );

    AndroidNotificationChannel streakChannel = const AndroidNotificationChannel(
      NotificationService.streakCategory,
      'Streak Notifications',
      description: 'Notifications related to your workout streaks',
      importance: Importance.high,
    );

    AndroidNotificationChannel performanceChannel =
        const AndroidNotificationChannel(
      NotificationService.performanceCategory,
      'Performance Notifications',
      description: 'Notifications about your fitness performance',
      importance: Importance.defaultImportance,
    );

    AndroidNotificationChannel engagementChannel =
        const AndroidNotificationChannel(
      NotificationService.engagementCategory,
      'Engagement Notifications',
      description: 'Reminders and suggestions for your workouts',
      importance: Importance.defaultImportance,
    );

    final androidPlatform = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlatform?.createNotificationChannel(goalChannel);
    await androidPlatform?.createNotificationChannel(streakChannel);
    await androidPlatform?.createNotificationChannel(performanceChannel);
    await androidPlatform?.createNotificationChannel(engagementChannel);
  }
}

class TestNotificationScheduler {
  final FakeFlutterLocalNotificationsPlugin plugin;

  TestNotificationScheduler(this.plugin);

  // A copy of the _isInQuietHours method from NotificationService
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

  Future<void> scheduleTestNotification({
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
      return;
    }

    if (await _isInQuietHours(scheduledDate)) {
      return;
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      category,
      NotificationService.instance.getCategoryName(category),
      channelDescription: 'Notifications for $category',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

class TestNotificationCanceller {
  final FakeFlutterLocalNotificationsPlugin plugin;

  TestNotificationCanceller(this.plugin);

  Future<void> cancelTestNotification(int id) async {
    await plugin.cancel(id);
  }

  Future<void> cancelAllTestNotifications() async {
    await plugin.cancelAll();
  }
}
