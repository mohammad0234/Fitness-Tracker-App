import 'package:flutter_test/flutter_test.dart';
import 'package:fitjourney/database_models/notification.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:sqflite/sqflite.dart' as sqflite;

// This file tests the in-app notification functionality which handles storing and
// retrieving user notifications within the app, separate from system notifications.

// These stub classes mimic real database and authentication behavior for testing
// without external dependencies

/// Simulates a database that successfully inserts records and tracks
/// what values were inserted for verification
class StubDatabase implements sqflite.Database {
  final int returnValue;
  Map<String, Object?> lastInsertedValues = {};

  StubDatabase({this.returnValue = 1});

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, sqflite.ConflictAlgorithm? conflictAlgorithm}) {
    lastInsertedValues = Map.from(values);
    return Future.value(returnValue);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Simulates a database that throws an exception when trying to insert
/// Used to test error handling behavior
class FailingStubDatabase implements sqflite.Database {
  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, sqflite.ConflictAlgorithm? conflictAlgorithm}) {
    throw Exception('Database error');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Simulates the DatabaseHelper that provides access to the database
/// Allows tests to control which database implementation is provided
class StubDatabaseHelper implements DatabaseHelper {
  final sqflite.Database _database;

  StubDatabaseHelper(this._database);

  @override
  Future<sqflite.Database> get database async => _database;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Simulates a logged-in user for authentication testing
class StubUser implements firebase_auth.User {
  @override
  String get uid => 'test-user-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Simulates Firebase authentication
/// Can be configured with or without a user to test different auth states
class StubAuth implements firebase_auth.FirebaseAuth {
  final firebase_auth.User? _user;

  StubAuth(this._user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A testable version of the notification service with injectable dependencies
/// Allows controlling error handling behavior for testing different scenarios
class TestableInAppNotificationService {
  final DatabaseHelper _dbHelper;
  final firebase_auth.FirebaseAuth _auth;
  final bool catchExceptions;

  TestableInAppNotificationService(this._dbHelper, this._auth,
      {this.catchExceptions = true});

  Future<int?> createNotification({
    required String type,
    required String message,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final db = await _dbHelper.database;

      // Create notification model
      final notification = NotificationModel(
        userId: userId,
        type: type,
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Insert into database
      return await db.insert('notification', notification.toMap());
    } catch (e) {
      // Only catch and handle exceptions if specified
      if (!catchExceptions) {
        throw e;
      }
      print('Error creating in-app notification: $e');
      return null;
    }
  }
}

void main() {
  // Tests for the NotificationModel class ensure proper serialization and deserialization
  group('NotificationModel Tests', () {
    // Tests that the model correctly deserializes data from a map (like from database)
    test('NotificationModel.fromMap should create a valid notification object',
        () {
      // Arrange
      final now = DateTime.now();
      final map = {
        'notification_id': 1,
        'user_id': 'test-user-123',
        'type': 'GoalProgress',
        'message': 'You\'ve achieved your goal!',
        'timestamp': now.toIso8601String(),
        'is_read': 0,
      };

      // Act
      final notification = NotificationModel.fromMap(map);

      // Assert
      expect(notification.notificationId, equals(1));
      expect(notification.userId, equals('test-user-123'));
      expect(notification.type, equals('GoalProgress'));
      expect(notification.message, equals('You\'ve achieved your goal!'));
      expect(notification.timestamp.day, equals(now.day));
      expect(notification.isRead, equals(false));
    });

    // Tests that the model correctly serializes to a map format for database storage
    test('NotificationModel.toMap should convert a Notification to valid map',
        () {
      // Arrange
      final now = DateTime.now();
      final notification = NotificationModel(
        notificationId: 1,
        userId: 'test-user-123',
        type: 'NewStreak',
        message: 'You have a 7-day streak!',
        timestamp: now,
        isRead: true,
      );

      // Act
      final map = notification.toMap();

      // Assert
      expect(map['notification_id'], equals(1));
      expect(map['user_id'], equals('test-user-123'));
      expect(map['type'], equals('NewStreak'));
      expect(map['message'], equals('You have a 7-day streak!'));
      expect(map['timestamp'], equals(now.toIso8601String()));
      expect(map['is_read'], equals(1));
    });
  });

  // Tests for the notification service functionality
  group('InAppNotificationService Tests', () {
    // Verifies that a notification is successfully created when a user is logged in
    test(
        'createNotification should create notification in database when user is logged in',
        () async {
      // Arrange - Use stub implementations instead of mocks
      final stubDatabase = StubDatabase();
      final stubDbHelper = StubDatabaseHelper(stubDatabase);
      final stubAuth = StubAuth(StubUser());

      final notificationService =
          TestableInAppNotificationService(stubDbHelper, stubAuth);

      // Act
      final result = await notificationService.createNotification(
        type: 'GoalProgress',
        message: 'Congratulations on reaching your goal!',
      );

      // Assert
      expect(result, equals(1));
    });

    // Tests that the service gracefully handles database errors
    test('createNotification should handle exceptions gracefully', () async {
      // Arrange - Use a failing database
      final failingDb = FailingStubDatabase();
      final stubDbHelper = StubDatabaseHelper(failingDb);
      final stubAuth = StubAuth(StubUser());

      final notificationService =
          TestableInAppNotificationService(stubDbHelper, stubAuth);

      // Act
      final result = await notificationService.createNotification(
        type: 'GoalProgress',
        message: 'Congratulations on reaching your goal!',
      );

      // Assert
      expect(result, isNull);
    });

    // Verifies proper error handling when no user is logged in
    test('createNotification should throw exception when user is not logged in',
        () async {
      // Arrange - Auth with no user, using the non-catching version
      final stubDatabase = StubDatabase();
      final stubDbHelper = StubDatabaseHelper(stubDatabase);
      final stubAuth = StubAuth(null); // No user

      final notificationService = TestableInAppNotificationService(
          stubDbHelper, stubAuth,
          catchExceptions: false // Don't catch exceptions so they propagate
          );

      // Act & Assert - Directly expect the exception
      expect(
          () => notificationService.createNotification(
                type: 'GoalProgress',
                message: 'Test message',
              ),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('User not logged in'))));
    });

    // Tests that notifications are created with the correct properties
    test('createNotification should set correct notification properties',
        () async {
      // Arrange - Use a database that captures values
      final stubDatabase = StubDatabase();
      final stubDbHelper = StubDatabaseHelper(stubDatabase);
      final stubAuth = StubAuth(StubUser());

      final notificationService =
          TestableInAppNotificationService(stubDbHelper, stubAuth);

      // Act
      await notificationService.createNotification(
        type: 'Milestone',
        message: 'You set a new personal record!',
      );

      // Assert - Check the captured values
      expect(
          stubDatabase.lastInsertedValues['user_id'], equals('test-user-123'));
      expect(stubDatabase.lastInsertedValues['type'], equals('Milestone'));
      expect(stubDatabase.lastInsertedValues['message'],
          equals('You set a new personal record!'));
      expect(stubDatabase.lastInsertedValues['is_read'],
          equals(0)); // Should default to unread
    });
  });
}
