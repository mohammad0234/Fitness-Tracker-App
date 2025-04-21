// lib/services/streak_service.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/streak.dart';
import 'package:fitjourney/database_models/daily_log.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitjourney/utils/date_utils.dart';
import 'package:fitjourney/services/notification_trigger_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing user workout streaks and daily activity tracking
/// Handles streak calculation, maintenance, and milestone achievements
class StreakService {
  // Singleton instance
  static final StreakService instance = StreakService._internal();

  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Notification trigger service
  final NotificationTriggerService _notificationTriggerService =
      NotificationTriggerService.instance;

  // Private constructor
  StreakService._internal();

  /// Returns current user ID or throws exception if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  /// Retrieves the user's current streak information
  /// Creates a new streak record if one doesn't exist
  Future<Streak> getUserStreak() async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    // Check if streak record exists for user
    final streakRecords = await db.query(
      'streak',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (streakRecords.isEmpty) {
      // Check if we have a streak in Firebase before creating a new one with 0
      try {
        final firestore = FirebaseFirestore.instance;

        final streakDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('streak')
            .doc(userId)
            .get();

        if (streakDoc.exists && streakDoc.data() != null) {
          final data = streakDoc.data()!;
          final cloudStreak = Streak(
            userId: userId,
            currentStreak: data['current_streak'] as int? ?? 0,
            longestStreak: data['longest_streak'] as int? ?? 0,
            lastActivityDate: data['last_activity_date'] != null
                ? DateTime.parse(data['last_activity_date'])
                : null,
            lastWorkoutDate: data['last_workout_date'] != null
                ? DateTime.parse(data['last_workout_date'])
                : null,
          );

          await db.insert('streak', cloudStreak.toMap());
          debugPrint(
              'Created local streak from cloud data: ${cloudStreak.currentStreak} days');
          return cloudStreak;
        }
      } catch (e) {
        debugPrint('Error checking cloud streak: $e');
        // Continue with creating a new streak
      }

      // Create a new streak record if none exists
      final newStreak = Streak(
        userId: userId,
        currentStreak: 0,
        longestStreak: 0,
      );

      await db.insert('streak', newStreak.toMap());
      return newStreak;
    }

    return Streak.fromMap(streakRecords.first);
  }

  /// Records a workout for the current day and updates streak information
  /// Handles streak incrementation, milestone tracking, and notifications
  Future<void> logWorkout(DateTime date) async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    // Ensure the date is truncated to just the date part
    final dateKey = DateTime(date.year, date.month, date.day);

    await db.transaction((txn) async {
      // Insert or update daily log
      final existingLogs = await txn.query(
        'daily_log',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, normaliseDate(date)],
      );

      if (existingLogs.isEmpty) {
        await txn.insert(
          'daily_log',
          DailyLog(
            userId: userId,
            date: date,
            activityType: 'workout',
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await txn.update(
          'daily_log',
          {'activity_type': 'workout'},
          where: 'daily_log_id = ?',
          whereArgs: [existingLogs.first['daily_log_id']],
        );
      }

      // Get current streak information
      final streakRecords = await txn.query(
        'streak',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      debugPrint('Existing streak records: ${streakRecords.length}');

      // Initialize streak variables
      int currentStreak = 0;
      int longestStreak = 0;
      DateTime? lastActivityDate;

      if (streakRecords.isNotEmpty) {
        final streak = Streak.fromMap(streakRecords.first);
        currentStreak = streak.currentStreak;
        longestStreak = streak.longestStreak;
        lastActivityDate = streak.lastActivityDate;

        debugPrint('Existing streak: $currentStreak');
        debugPrint('Last activity date: $lastActivityDate');
      }

      // Check for consecutive day
      if (lastActivityDate != null) {
        final lastActivityDateKey = DateTime(lastActivityDate.year,
            lastActivityDate.month, lastActivityDate.day);

        final daysDifference = dateKey.difference(lastActivityDateKey).inDays;

        debugPrint('Days difference: $daysDifference');

        if (daysDifference == 1) {
          // Consecutive day - increment streak
          currentStreak += 1;
        } else if (daysDifference > 1) {
          // Not consecutive - reset streak
          currentStreak = 1;
        } else if (daysDifference == 0 && currentStreak == 0) {
          // Same day, but streak is 0 - set to 1
          currentStreak = 1;
        }
      } else {
        // First activity ever - start streak at 1
        currentStreak = 1;
      }

      // Update longest streak
      bool isLongestStreak = false;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
        isLongestStreak = true;
      }

      debugPrint('New streak: $currentStreak');
      debugPrint('Longest streak: $longestStreak');

      // Update or insert streak record
      if (streakRecords.isEmpty) {
        await txn.insert(
          'streak',
          {
            'user_id': userId,
            'current_streak': currentStreak,
            'longest_streak': longestStreak,
            'last_activity_date': dateKey.toIso8601String(),
            'last_workout_date': dateKey.toIso8601String(),
          },
        );
      } else {
        await txn.update(
          'streak',
          {
            'current_streak': currentStreak,
            'longest_streak': longestStreak,
            'last_activity_date': dateKey.toIso8601String(),
            'last_workout_date': dateKey.toIso8601String(),
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }

      // Check for milestone achievements
      await _checkStreakMilestones(txn, userId, currentStreak);

      // Store values for notifications after transaction completes
      return {
        'currentStreak': currentStreak,
        'isLongestStreak': isLongestStreak,
      };
    }).then((result) async {
      // Handle post-transaction notifications
      final currentStreak = result['currentStreak'] as int;
      final isLongestStreak = result['isLongestStreak'] as bool;
      //final longestStreak = result['longestStreak'] as int;

      // If it's a new longest streak, we might want to notify this too
      if (isLongestStreak && currentStreak > 7) {
        // Send a special notification for breaking your own record
        // This would be a custom implementation
      }

      // Mark streak for sync with Firestore
      try {
        await _dbHelper.markForSync('streak', userId, 'UPDATE');
        print('Marked streak for sync after logging workout');
      } catch (e) {
        print('Error marking streak for sync: $e');
      }
    });
  }

  /// Records a rest day while maintaining the current streak
  /// Rest days count for streak maintenance but don't increment streak count
  Future<void> logRestDay(DateTime date) async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    // Check if there's already an activity for this date
    final existingLogs = await db.query(
      'daily_log',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, normaliseDate(date)],
    );

    int dailyLogId = 0;

    // Use a transaction for the database operations
    await db.transaction((txn) async {
      // Insert or update daily log
      if (existingLogs.isEmpty) {
        // Create a new log with a unique ID
        dailyLogId = DateTime.now().millisecondsSinceEpoch;
        await txn.insert(
          'daily_log',
          DailyLog(
            dailyLogId: dailyLogId,
            userId: userId,
            date: date,
            activityType: 'rest',
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        dailyLogId = existingLogs.first['daily_log_id'] as int;
        // If there's already a workout, don't downgrade to rest
        if (existingLogs.first['activity_type'] != 'workout') {
          await txn.update(
            'daily_log',
            {'activity_type': 'rest'},
            where: 'daily_log_id = ?',
            whereArgs: [dailyLogId],
          );
        } else {
          // Already logged a workout, no need to update
          return;
        }
      }

      // Get current streak
      final streakRecords = await txn.query(
        'streak',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Initialize streak variables
      int currentStreak = 0;
      int longestStreak = 0;
      DateTime? lastActivityDate;

      if (streakRecords.isNotEmpty) {
        final streak = Streak.fromMap(streakRecords.first);
        currentStreak = streak.currentStreak;
        longestStreak = streak.longestStreak;
        lastActivityDate = streak.lastActivityDate;
      }

      // Check if this is a consecutive day
      bool isConsecutiveDay = false;
      if (lastActivityDate != null) {
        final difference = date.difference(lastActivityDate);
        isConsecutiveDay =
            difference.inDays <= 1; // Allow for same-day logs or next day
      }

      // For rest days, maintain the streak but don't increment
      if (!isConsecutiveDay) {
        currentStreak = 0; // Reset if not consecutive
      }

      // Update streak record
      if (streakRecords.isEmpty) {
        await txn.insert(
          'streak',
          {
            'user_id': userId,
            'current_streak': currentStreak,
            'longest_streak': longestStreak,
            'last_activity_date': date.toIso8601String(),
            'last_workout_date': null,
          },
        );
      } else {
        await txn.update(
          'streak',
          {
            'current_streak': currentStreak,
            'longest_streak': longestStreak,
            'last_activity_date': date.toIso8601String(),
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
    });

    // Mark the daily log for sync after transaction completes
    if (dailyLogId > 0) {
      try {
        await _dbHelper.markForSync('daily_log', dailyLogId.toString(),
            existingLogs.isEmpty ? 'INSERT' : 'UPDATE');
        print('Marked rest day log for sync: $dailyLogId');
      } catch (e) {
        print('Error marking rest day log for sync: $e');
      }
    }

    // Also mark streak for sync
    try {
      await _dbHelper.markForSync('streak', userId, 'UPDATE');
      print('Marked streak for sync after logging rest day');
    } catch (e) {
      print('Error marking streak for sync: $e');
    }
  }

  /// Tracks and celebrates significant streak milestones
  /// Triggers notifications at key streak lengths (7 days, 30 days)
  Future<void> _checkStreakMilestones(
      dynamic txn, String userId, int currentStreak) async {
    // Check for 7-day streak
    if (currentStreak == 7) {
      await txn.insert(
        'milestone',
        {
          'user_id': userId,
          'type': 'LongestStreak',
          'value': 7,
          'date': DateTime.now().toIso8601String(),
        },
      );

      // Schedule notification for 7-day streak milestone
      // Note: Can't use await in transaction, so we don't await this call
      _notificationTriggerService.onStreakMilestone(7);
    }

    // Check for 30-day streak
    if (currentStreak == 30) {
      await txn.insert(
        'milestone',
        {
          'user_id': userId,
          'type': 'LongestStreak',
          'value': 30,
          'date': DateTime.now().toIso8601String(),
        },
      );

      // Schedule notification for 30-day streak milestone
      _notificationTriggerService.onStreakMilestone(30);
    }
  }

  /// Performs daily check of streak status and sends notifications if needed
  /// Should be called once per day to maintain accurate streak tracking
  Future<void> performDailyStreakCheck() async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    // Get current streak info
    final streakRecords = await db.query(
      'streak',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (streakRecords.isEmpty) {
      return; // No streak to check
    }

    final streak = Streak.fromMap(streakRecords.first);
    final lastActivityDate = streak.lastActivityDate;

    if (lastActivityDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastActivity = DateTime(
          lastActivityDate.year, lastActivityDate.month, lastActivityDate.day);

      final difference = today.difference(lastActivity).inDays;

      // If activity is not logged today, schedule streak maintenance notification
      if (difference == 0 && streak.currentStreak > 0) {
        // Activity already logged today
        // Do nothing
      } else if (difference == 1) {
        // Last activity was yesterday, schedule reminder
        await _notificationTriggerService
            .onStreakMaintenanceRequired(streak.currentStreak);
      } else if (difference > 1) {
        // If more than 1 day has passed since last activity, reset streak
        await db.update(
          'streak',
          {'current_streak': 0},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
    }
  }

  /// Retrieves user's activity history for a specified date range
  /// Returns a list of daily logs with workout and rest day information
  Future<List<DailyLog>> getDailyLogHistory(
      DateTime startDate, DateTime endDate) async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    print('Loading daily logs from $startDate to $endDate for user $userId');
    try {
      // Ensure date normalization
      final startDateStr = normaliseDate(startDate);
      final endDateStr = normaliseDate(endDate);

      // Query with proper date format
      final dailyLogs = await db.query(
        'daily_log',
        where: 'user_id = ? AND date BETWEEN ? AND ?',
        whereArgs: [userId, startDateStr, endDateStr],
        orderBy: 'date DESC', // Most recent first
      );

      print('Found ${dailyLogs.length} daily logs in local database');

      // Convert to DailyLog objects
      final result = dailyLogs.map((log) => DailyLog.fromMap(log)).toList();

      // IMPROVED APPROACH: Even if we have logs, ensure all workout days are properly represented
      // This ensures consistency between devices
      await _ensureWorkoutsHaveDailyLogs(startDate, endDate);

      // If we still have no logs after trying to create them, do a deeper check of workout data
      if (result.isEmpty) {
        print('No daily logs found, creating them from workouts');
        await _createDailyLogsFromWorkouts(startDate, endDate);

        // Try again after creating logs
        final newLogs = await db.query(
          'daily_log',
          where: 'user_id = ? AND date BETWEEN ? AND ?',
          whereArgs: [userId, startDateStr, endDateStr],
          orderBy: 'date DESC',
        );

        print('After creation: found ${newLogs.length} daily logs');
        return newLogs.map((log) => DailyLog.fromMap(log)).toList();
      }

      return result;
    } catch (e) {
      print('Error retrieving daily logs: $e');
      return [];
    }
  }

  /// Ensures all workout days have corresponding daily log entries
  /// Creates missing logs to maintain data consistency across features
  Future<void> _ensureWorkoutsHaveDailyLogs(
      DateTime startDate, DateTime endDate) async {
    try {
      final userId = _getCurrentUserId();
      final db = await _dbHelper.database;

      // Get all workouts for the date range
      final workouts = await db.query(
        'workout',
        where: 'user_id = ? AND date BETWEEN ? AND ?',
        whereArgs: [userId, normaliseDate(startDate), normaliseDate(endDate)],
      );

      print(
          'Checking ${workouts.length} workouts to ensure they have daily logs');

      // Create a set of dates that have workouts
      final workoutDates = <String>{};
      for (final workout in workouts) {
        final workoutDate = workout['date'] as String?;
        if (workoutDate != null) {
          workoutDates.add(workoutDate);
        }
      }

      // For each workout date, ensure there's a daily log
      for (final workoutDate in workoutDates) {
        // Check if a log already exists for this date
        final existingLog = await db.query(
          'daily_log',
          where: 'user_id = ? AND date = ?',
          whereArgs: [userId, workoutDate],
        );

        if (existingLog.isEmpty) {
          // Generate a unique ID
          final logId =
              DateTime.now().millisecondsSinceEpoch + workoutDate.hashCode;

          // Create a new log
          print('Creating daily log for workout date: $workoutDate');
          final log = DailyLog(
            dailyLogId: logId,
            userId: userId,
            date: DateTime.parse(workoutDate),
            activityType: 'workout',
          );

          // Insert into database
          await db.insert('daily_log', log.toMap());

          // Mark for sync
          await _dbHelper.markForSync('daily_log', logId.toString(), 'INSERT');
        }
      }
    } catch (e) {
      print('Error ensuring workouts have daily logs: $e');
    }
  }

  /// Creates daily log entries based on existing workout records
  /// Used for data repair if daily logs are missing but workouts exist
  Future<void> _createDailyLogsFromWorkouts(
      DateTime startDate, DateTime endDate) async {
    try {
      final userId = _getCurrentUserId();
      final db = await _dbHelper.database;

      // Get all workouts for the date range
      final workouts = await db.query(
        'workout',
        where: 'user_id = ? AND date BETWEEN ? AND ?',
        whereArgs: [userId, normaliseDate(startDate), normaliseDate(endDate)],
      );

      print('Found ${workouts.length} workouts for creating logs');

      // Create a daily log for each workout date
      for (final workout in workouts) {
        try {
          final workoutDate = workout['date'] as String;

          // Check if a log already exists for this date
          final existingLog = await db.query(
            'daily_log',
            where: 'user_id = ? AND date = ?',
            whereArgs: [userId, workoutDate],
          );

          if (existingLog.isEmpty) {
            // Generate a unique ID
            final logId = DateTime.now().millisecondsSinceEpoch +
                (workout['workout_id'] as int);

            // Create a new log
            print('Creating daily log for workout on $workoutDate');
            final log = DailyLog(
              dailyLogId: logId,
              userId: userId,
              date: DateTime.parse(workoutDate),
              activityType: 'workout',
              notes: workout['notes'] as String?,
            );

            // Insert into database
            await db.insert('daily_log', log.toMap());

            // Mark for sync
            await _dbHelper.markForSync(
                'daily_log', logId.toString(), 'INSERT');
          }
        } catch (e) {
          print('Error creating log for workout: $e');
        }
      }
    } catch (e) {
      print('Error creating daily logs from workouts: $e');
    }
  }
}
