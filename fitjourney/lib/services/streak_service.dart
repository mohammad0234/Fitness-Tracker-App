// lib/services/streak_service.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/streak.dart';
import 'package:fitjourney/database_models/daily_log.dart';

class StreakService {
  // Singleton instance
  static final StreakService instance = StreakService._internal();
  
  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
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
    
    // Check if there's already an activity for this date
    final existingLogs = await db.query(
      'daily_log',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date.toIso8601String().split('T')[0]],
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
            activityType: 'workout',
          ).toMap(),
        );
      } else {
        await txn.update(
          'daily_log',
          {'activity_type': 'workout'},
          where: 'daily_log_id = ?',
          whereArgs: [existingLogs.first['daily_log_id']],
        );
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
      
      // Update streak
      if (isConsecutiveDay) {
        currentStreak += 1; // Increment streak for a workout
      } else {
        currentStreak = 1; // Reset and start new streak
      }
      
      // Update longest streak if needed
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
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
            'last_workout_date': date.toIso8601String(),
          },
        );
      } else {
        await txn.update(
          'streak',
          {
            'current_streak': currentStreak,
            'longest_streak': longestStreak,
            'last_activity_date': date.toIso8601String(),
            'last_workout_date': date.toIso8601String(),
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
      
      // Check for milestone achievements
      await _checkStreakMilestones(txn, userId, currentStreak);
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
      whereArgs: [userId, date.toIso8601String().split('T')[0]],
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
      
      // If more than 1 day has passed since last activity, reset streak
      if (difference > 1) {
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
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'date ASC',
    );
    
    return logs.map((log) => DailyLog.fromMap(log)).toList();
  }
}