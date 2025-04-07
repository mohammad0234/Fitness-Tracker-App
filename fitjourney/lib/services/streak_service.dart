// lib/services/streak_service.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/streak.dart';
import 'package:fitjourney/database_models/daily_log.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitjourney/utils/date_utils.dart';
import 'package:fitjourney/services/notification_trigger_service.dart';
import 'package:flutter/material.dart';

class StreakService {
  // Singleton instance
  static final StreakService instance = StreakService._internal();
  
  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Notification trigger service
  final NotificationTriggerService _notificationTriggerService = NotificationTriggerService.instance;
  
  // Private constructor
  StreakService._internal();
  
  // Get the current user ID or throw an error if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  // Get the user's current streak
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
  
  // Record a workout day
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
        final lastActivityDateKey = DateTime(
          lastActivityDate.year, 
          lastActivityDate.month, 
          lastActivityDate.day
        );
        
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
        });
  }
  
  // Record a rest day
  Future<void> logRestDay(DateTime date) async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;
    
    // Check if there's already an activity for this date
    final existingLogs = await db.query(
      'daily_log',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, normaliseDate(date)],
    );
    
    // Use a transaction for the database operations
    await db.transaction((txn) async {
      // Insert or update daily log
      if (existingLogs.isEmpty) {
        await txn.insert(
          'daily_log',
          DailyLog(
            userId: userId,
            date: date,
            activityType: 'rest',
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // If there's already a workout, don't downgrade to rest
        if (existingLogs.first['activity_type'] != 'workout') {
          await txn.update(
            'daily_log',
            {'activity_type': 'rest'},
            where: 'daily_log_id = ?',
            whereArgs: [existingLogs.first['daily_log_id']],
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
        isConsecutiveDay = difference.inDays <= 1; // Allow for same-day logs or next day
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
  }
  
  // Check for streak milestone achievements
  Future<void> _checkStreakMilestones(dynamic txn, String userId, int currentStreak) async {
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
  
  // Perform daily streak check (to be called once per day)
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
        lastActivityDate.year, 
        lastActivityDate.month, 
        lastActivityDate.day
      );
      
      final difference = today.difference(lastActivity).inDays;
      
      // If activity is not logged today, schedule streak maintenance notification
      if (difference == 0 && streak.currentStreak > 0) {
        // Activity already logged today
        // Do nothing
      } else if (difference == 1) {
        // Last activity was yesterday, schedule reminder
        await _notificationTriggerService.onStreakMaintenanceRequired(streak.currentStreak);
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
  
  // Get daily log history for a date range (for calendar view)
  Future<List<DailyLog>> getDailyLogHistory(DateTime startDate, DateTime endDate) async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;
    
    final logs = await db.query(
      'daily_log',
      where: 'user_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        userId, 
        normaliseDate(startDate),
        normaliseDate(endDate),
      ],
      orderBy: 'date ASC',
    );
    
    return logs.map((log) => DailyLog.fromMap(log)).toList();
  }
}