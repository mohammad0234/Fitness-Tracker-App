import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/database_models/streak.dart';
import 'package:fitjourney/database_models/user_metrics.dart';
import 'package:fitjourney/utils/date_utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();

  factory SyncService() {
    return instance;
  }

  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  StreamSubscription? _connectivitySubscription;
  Timer? _syncTimer;

  // New state variables for tracking sync status
  bool _isSyncing = false;
  DateTime? _lastSyncAttempt;
  DateTime? _lastSuccessfulSync;
  String? _lastSyncError;

  // Stream controller for sync status updates
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  // Initialize sync service and set up listeners
  Future<void> initialize() async {
    print('Initializing SyncService...');

    try {
      // Create or update sync_queue table
      final db = await _dbHelper.database;

      // Check if sync_queue exists
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_queue'");

      if (tables.isEmpty) {
        // Create table if it doesn't exist
        print('Creating sync_queue table from scratch');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0,
            last_error TEXT,
            synced INTEGER DEFAULT 0,
            UNIQUE(table_name, record_id, operation)
          );
        ''');
        print('Created sync_queue table');
      } else {
        print('sync_queue table exists, checking schema');

        // Get column info
        final columns = await db.rawQuery("PRAGMA table_info(sync_queue)");
        final columnNames =
            columns.map((col) => col['name'] as String).toList();

        // Check if columns exist and add them if they don't
        if (!columnNames.contains('retry_count')) {
          print('Adding retry_count column to sync_queue table');
          try {
            await db.execute(
                'ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER DEFAULT 0');
          } catch (e) {
            print('Error adding retry_count column: $e');
            // Column might already exist or can't be added, continue anyway
          }
        }

        if (!columnNames.contains('last_error')) {
          print('Adding last_error column to sync_queue table');
          try {
            await db
                .execute('ALTER TABLE sync_queue ADD COLUMN last_error TEXT');
          } catch (e) {
            print('Error adding last_error column: $e');
            // Column might already exist or can't be added, continue anyway
          }
        }
      }

      // Set up connectivity listener with improved error handling
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((result) {
        if (result != ConnectivityResult.none) {
          print('Network connection detected, attempting sync...');
          syncAll();
        } else {
          print('Network connection lost, sync paused');
          _updateSyncStatus(isSuccess: false, error: 'No network connection');
        }
      }, onError: (e) {
        print('Connectivity listener error: $e');
      });

      // Set up periodic sync (every 15 minutes)
      _syncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
          print('Periodic sync triggered');
          syncAll();
        }
      });

      // Initial sync attempt
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        print('Initial sync attempt');
        syncAll();
      }

      _updateSyncStatus(isSuccess: true);
    } catch (e) {
      print('Error initializing sync service: $e');
      _updateSyncStatus(isSuccess: false, error: 'Initialization error: $e');
      throw e; // Re-throw to inform caller
    }
  }

  // Clean up resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _syncStatusController.close();
  }

  // Add an item to the sync queue
  Future<void> queueForSync(
      String tableName, String recordId, String operation) async {
    final db = await _dbHelper.database;

    try {
      await db.insert(
        'sync_queue',
        {
          'table_name': tableName,
          'record_id': recordId,
          'operation': operation,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'retry_count': 0,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('Added to sync queue: $tableName, $recordId, $operation');

      // Attempt immediate sync if we're connected
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none && !_isSyncing) {
        syncAll();
      }
    } catch (e) {
      print('Error adding to sync queue: $e');
    }
  }

  // Sync all data
  Future<bool> syncAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Sync aborted: No logged in user');
      return false;
    }

    // Prevent concurrent syncs
    if (_isSyncing) {
      print('Sync already in progress, skipping');
      return false;
    }

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    _updateSyncStatus(isInProgress: true);

    try {
      print('Starting sync for user: ${user.uid}');

      // Process sync queue (upload changes to Firestore)
      final outgoingSuccess = await _processOutgoingSync(user.uid);

      // Download any changes from Firestore
      final incomingSuccess = await _processIncomingSync(user.uid);

      // Clean up sync queue if necessary
      await _cleanupSyncQueue();

      _lastSuccessfulSync = DateTime.now();
      _isSyncing = false;
      _updateSyncStatus(isSuccess: true);

      print('Sync completed successfully');
      return outgoingSuccess && incomingSuccess;
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      _updateSyncStatus(isSuccess: false, error: e.toString());

      print('Sync error: $e');
      return false;
    }
  }

  // Manual sync trigger (can be called from UI)
  Future<bool> triggerManualSync() async {
    // First ensure streak is included in sync
    await forceAddStreakToSyncQueue();
    return await syncAll();
  }

  // Force add streak to sync queue since it's not captured by regular CRUD operations
  Future<void> forceAddStreakToSyncQueue() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final streak = await _dbHelper.getStreakForUser(user.uid);
      if (streak != null) {
        print(
            'Adding current streak to sync queue: ${streak.currentStreak} days');
        await queueForSync('streak', user.uid, 'UPDATE');
      }
    } catch (e) {
      print('Error adding streak to sync queue: $e');
    }
  }

  // Update sync status and notify listeners
  void _updateSyncStatus({
    bool? isInProgress,
    bool? isSuccess,
    String? error,
  }) {
    final status = SyncStatus(
      isInProgress: isInProgress ?? _isSyncing,
      lastAttempt: _lastSyncAttempt,
      lastSuccess: _lastSuccessfulSync,
      lastError: error ?? _lastSyncError,
    );

    _syncStatusController.add(status);
  }

  // Process local changes and upload to Firestore
  Future<bool> _processOutgoingSync(String userId) async {
    final db = await _dbHelper.database;
    bool allSuccess = true;

    try {
      // Get all items in the sync queue
      final List<Map<String, dynamic>> queueItems = await db.query(
        'sync_queue',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC', // Process oldest items first
      );

      print('Found ${queueItems.length} items in outgoing sync queue');

      if (queueItems.isEmpty) {
        return true; // Nothing to sync
      }

      // Check if we need to explicitly sync daily logs
      bool hasDailyLogSync =
          queueItems.any((item) => item['table_name'] == 'daily_log');

      // If no daily logs being synced, check if we need to generate them
      if (!hasDailyLogSync) {
        await _generateDailyLogsFromWorkouts(userId);
      }

      // Group items by table for more efficient processing
      final Map<String, List<Map<String, dynamic>>> itemsByTable = {};

      for (final item in queueItems) {
        final tableName = item['table_name'] as String;
        itemsByTable[tableName] = itemsByTable[tableName] ?? [];
        itemsByTable[tableName]!.add(item);
      }

      // Process each table group
      for (final tableName in itemsByTable.keys) {
        final items = itemsByTable[tableName]!;
        print('Processing ${items.length} items for table $tableName');

        for (final item in items) {
          final String recordId = item['record_id'];
          final String operation = item['operation'];
          final int queueId = item['id'];
          final int retryCount = item['retry_count'] ?? 0;

          // Skip items that have been retried too many times
          if (retryCount > 5) {
            print('Skipping item after 5 retries: $tableName, $recordId');
            continue;
          }

          try {
            print('Processing sync item: $tableName, $recordId, $operation');

            if (operation == 'INSERT' || operation == 'UPDATE') {
              // Get the actual data to sync
              Map<String, dynamic>? dataToSync;
              bool recordExists = true;

              switch (tableName) {
                case 'users':
                  final user = await _dbHelper.getUserById(recordId);
                  if (user != null) {
                    dataToSync = user.toMap();
                  } else {
                    recordExists = false;
                  }
                  break;
                case 'workout':
                  try {
                    final workout =
                        await _dbHelper.getWorkoutById(int.parse(recordId));
                    if (workout != null) {
                      dataToSync = workout.toMap();

                      // Also get associated workout exercises and sets
                      dataToSync['exercises'] =
                          await _getWorkoutExercisesData(workout.workoutId!);
                    } else {
                      recordExists = false;
                    }
                  } catch (e) {
                    print('Error getting workout data: $e');
                    recordExists = false;
                  }
                  break;
                case 'goal':
                  final goal = await _dbHelper.getGoalById(int.parse(recordId));
                  if (goal != null) {
                    dataToSync = goal.toMap();
                  } else {
                    recordExists = false;
                  }
                  break;
                case 'streak':
                  final streak = await _dbHelper.getStreakForUser(userId);
                  if (streak != null) {
                    dataToSync = streak.toMap();
                  } else {
                    recordExists = false;
                  }
                  break;
                case 'user_metrics':
                  // Add implementation for user metrics
                  break;
              }

              if (!recordExists) {
                // Record doesn't exist anymore (may have been deleted), mark as synced
                print(
                    'Record no longer exists: $tableName, $recordId, marking as synced');
                await db.update(
                  'sync_queue',
                  {'synced': 1},
                  where: 'id = ?',
                  whereArgs: [queueId],
                );
                continue;
              }

              if (dataToSync != null) {
                // Add a timestamp for conflict resolution
                dataToSync['last_updated'] = FieldValue.serverTimestamp();

                // Upload to Firestore
                await _firestore
                    .collection('users')
                    .doc(userId)
                    .collection(tableName)
                    .doc(recordId)
                    .set(dataToSync, SetOptions(merge: true));

                print('Successfully synced: $tableName, $recordId');

                // Mark as synced
                await db.update(
                  'sync_queue',
                  {'synced': 1},
                  where: 'id = ?',
                  whereArgs: [queueId],
                );
              } else {
                throw Exception('No data found to sync');
              }
            } else if (operation == 'DELETE') {
              // Delete from Firestore
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection(tableName)
                  .doc(recordId)
                  .delete();

              print('Successfully deleted: $tableName, $recordId');

              // Mark as synced
              await db.update(
                'sync_queue',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [queueId],
              );
            }
          } catch (e) {
            allSuccess = false;
            print('Error syncing item $queueId: $e');

            // Update retry count and error
            await db.update(
              'sync_queue',
              {
                'retry_count': retryCount + 1,
                'last_error': e.toString(),
              },
              where: 'id = ?',
              whereArgs: [queueId],
            );
          }
        }
      }

      // Verify all items were processed
      final remainingCount = Sqflite.firstIntValue(await db
              .rawQuery('SELECT COUNT(*) FROM sync_queue WHERE synced = 0')) ??
          0;

      print('Remaining unsynced items: $remainingCount');

      return allSuccess;
    } catch (e) {
      print('Error in outgoing sync process: $e');
      return false;
    }
  }

  // Helper method to get workout exercise data
  Future<List<Map<String, dynamic>>> _getWorkoutExercisesData(
      int workoutId) async {
    final db = await _dbHelper.database;
    final exercises = await db.query(
      'workout_exercise',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );

    final result = <Map<String, dynamic>>[];

    for (final exercise in exercises) {
      final exerciseId = exercise['workout_exercise_id'] as int;
      final sets = await db.query(
        'workout_set',
        where: 'workout_exercise_id = ?',
        whereArgs: [exerciseId],
      );

      final exerciseData = Map<String, dynamic>.from(exercise);
      exerciseData['sets'] = sets;
      result.add(exerciseData);
    }

    return result;
  }

  // Download changes from Firestore
  Future<bool> _processIncomingSync(String userId) async {
    bool allSuccess = true;

    try {
      // Sync user profile
      if (!await _syncUserProfile(userId)) allSuccess = false;

      // Sync workouts
      if (!await _syncWorkouts(userId)) allSuccess = false;

      // Sync goals
      if (!await _syncGoals(userId)) allSuccess = false;

      // Sync metrics
      if (!await _syncMetrics(userId)) allSuccess = false;

      // Sync streak
      if (!await _syncStreak(userId)) allSuccess = false;

      return allSuccess;
    } catch (e) {
      print('Error in incoming sync: $e');
      return false;
    }
  }

  // Clean up old sync queue items
  Future<void> _cleanupSyncQueue() async {
    final db = await _dbHelper.database;

    // Remove successfully synced items older than 7 days
    final oneWeekAgo =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    await db.delete(
      'sync_queue',
      where: 'synced = 1 AND timestamp < ?',
      whereArgs: [oneWeekAgo],
    );
  }

  // Sync user profile from Firestore to SQLite
  Future<bool> _syncUserProfile(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        if (userData != null) {
          final appUser = AppUser(
            userId: userId,
            firstName: userData['first_name'],
            lastName: userData['last_name'],
            heightCm: userData['height_cm'],
            registrationDate: userData['registration_date'] != null
                ? DateTime.parse(userData['registration_date'])
                : null,
            lastLogin: userData['last_login'] != null
                ? DateTime.parse(userData['last_login'])
                : null,
          );

          await _dbHelper.insertUser(appUser);
          return true;
        }
      }
      return true; // No profile data to sync is not an error
    } catch (e) {
      print('Error syncing user profile: $e');
      return false;
    }
  }

  // Sync workouts from Firestore to SQLite
  Future<bool> _syncWorkouts(String userId) async {
    try {
      print('Syncing workouts for user: $userId');
      // Timestamp of last successful sync
      final lastSyncTime =
          _lastSuccessfulSync?.subtract(const Duration(minutes: 5)) ??
              DateTime(2000);

      // Get all workouts updated since last sync
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workout')
          .where('last_updated', isGreaterThan: lastSyncTime)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No updated workouts to sync');
        return true;
      }

      print('Found ${querySnapshot.docs.length} workouts to sync');
      final db = await _dbHelper.database;

      // Process each workout
      for (final doc in querySnapshot.docs) {
        try {
          final workoutData = doc.data();
          final workoutId = int.parse(doc.id);

          // Check if workout exists locally
          final existingWorkout = await _dbHelper.getWorkoutById(workoutId);

          if (existingWorkout == null) {
            // Insert new workout
            print('Creating new workout: $workoutId');
            final workout = Workout(
              workoutId: workoutId,
              userId: userId,
              date: workoutData['date'] != null
                  ? DateTime.parse(workoutData['date'])
                  : DateTime.now(),
              duration: workoutData['duration'],
              notes: workoutData['notes'],
            );

            await db.transaction((txn) async {
              // Insert workout
              await txn.insert(
                'workout',
                workout.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              // Insert associated exercises and sets
              if (workoutData['exercises'] != null) {
                final exercises = workoutData['exercises'] as List<dynamic>;
                for (final exerciseData in exercises) {
                  final workoutExerciseId = await txn.insert(
                    'workout_exercise',
                    {
                      'workout_id': workoutId,
                      'exercise_id': exerciseData['exercise_id'],
                    },
                  );

                  if (exerciseData['sets'] != null) {
                    final sets = exerciseData['sets'] as List<dynamic>;
                    for (final setData in sets) {
                      await txn.insert(
                        'workout_set',
                        {
                          'workout_exercise_id': workoutExerciseId,
                          'set_number': setData['set_number'],
                          'reps': setData['reps'],
                          'weight': setData['weight'],
                        },
                      );
                    }
                  }
                }
              }
            });
          } else {
            // Update existing workout
            print('Updating existing workout: $workoutId');
            final workout = Workout(
              workoutId: workoutId,
              userId: userId,
              date: workoutData['date'] != null
                  ? DateTime.parse(workoutData['date'])
                  : existingWorkout.date,
              duration: workoutData['duration'] ?? existingWorkout.duration,
              notes: workoutData['notes'] ?? existingWorkout.notes,
            );

            await db.transaction((txn) async {
              // Update workout
              await txn.update(
                'workout',
                workout.toMap(),
                where: 'workout_id = ?',
                whereArgs: [workoutId],
              );

              // For simplicity, delete and recreate exercises and sets
              // In a production app, you might want to implement a more sophisticated
              // diffing algorithm to only update what changed

              // Get all workout_exercise records for this workout
              final workoutExercises = await txn.query(
                'workout_exercise',
                where: 'workout_id = ?',
                whereArgs: [workoutId],
              );

              // Delete associated sets for each workout_exercise
              for (var exercise in workoutExercises) {
                final workoutExerciseId =
                    exercise['workout_exercise_id'] as int;
                await txn.delete(
                  'workout_set',
                  where: 'workout_exercise_id = ?',
                  whereArgs: [workoutExerciseId],
                );
              }

              // Delete workout_exercise records
              await txn.delete(
                'workout_exercise',
                where: 'workout_id = ?',
                whereArgs: [workoutId],
              );

              // Insert new exercises and sets if available
              if (workoutData['exercises'] != null) {
                final exercises = workoutData['exercises'] as List<dynamic>;
                for (final exerciseData in exercises) {
                  final workoutExerciseId = await txn.insert(
                    'workout_exercise',
                    {
                      'workout_id': workoutId,
                      'exercise_id': exerciseData['exercise_id'],
                    },
                  );

                  if (exerciseData['sets'] != null) {
                    final sets = exerciseData['sets'] as List<dynamic>;
                    for (final setData in sets) {
                      await txn.insert(
                        'workout_set',
                        {
                          'workout_exercise_id': workoutExerciseId,
                          'set_number': setData['set_number'],
                          'reps': setData['reps'],
                          'weight': setData['weight'],
                        },
                      );
                    }
                  }
                }
              }
            });
          }
        } catch (e) {
          print('Error syncing workout ${doc.id}: $e');
          // Continue with other workouts even if one fails
        }
      }

      return true;
    } catch (e) {
      print('Error syncing workouts: $e');
      return false;
    }
  }

  // Sync goals from Firestore to SQLite
  Future<bool> _syncGoals(String userId) async {
    try {
      print('Syncing goals for user: $userId');
      // Timestamp of last successful sync
      final lastSyncTime =
          _lastSuccessfulSync?.subtract(const Duration(minutes: 5)) ??
              DateTime(2000);

      // Get all goals updated since last sync
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('goal')
          .where('last_updated', isGreaterThan: lastSyncTime)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No updated goals to sync');
        return true;
      }

      print('Found ${querySnapshot.docs.length} goals to sync');

      // Process each goal
      for (final doc in querySnapshot.docs) {
        try {
          final goalData = doc.data();
          final goalId = int.parse(doc.id);

          // Check if goal exists locally
          final existingGoal = await _dbHelper.getGoalById(goalId);

          if (existingGoal == null) {
            // Insert new goal
            print('Creating new goal: $goalId');
            final goal = Goal(
              goalId: goalId,
              userId: userId,
              type: goalData['type'],
              exerciseId: goalData['exercise_id'],
              targetValue: goalData['target_value'] != null
                  ? (goalData['target_value'] as num).toDouble()
                  : null,
              startDate: goalData['start_date'] != null
                  ? DateTime.parse(goalData['start_date'])
                  : DateTime.now(),
              endDate: goalData['end_date'] != null
                  ? DateTime.parse(goalData['end_date'])
                  : DateTime.now().add(const Duration(days: 30)),
              achieved:
                  goalData['achieved'] == 1 || goalData['achieved'] == true,
              currentProgress: goalData['current_progress'] != null
                  ? (goalData['current_progress'] as num).toDouble()
                  : 0,
            );

            await _dbHelper.insertGoal(goal);
          } else {
            // Update existing goal
            print('Updating existing goal: $goalId');
            final goal = Goal(
              goalId: goalId,
              userId: userId,
              type: goalData['type'] ?? existingGoal.type,
              exerciseId: goalData['exercise_id'] ?? existingGoal.exerciseId,
              targetValue: goalData['target_value'] != null
                  ? (goalData['target_value'] as num).toDouble()
                  : existingGoal.targetValue,
              startDate: goalData['start_date'] != null
                  ? DateTime.parse(goalData['start_date'])
                  : existingGoal.startDate,
              endDate: goalData['end_date'] != null
                  ? DateTime.parse(goalData['end_date'])
                  : existingGoal.endDate,
              achieved: goalData['achieved'] == 1 ||
                  goalData['achieved'] == true ||
                  existingGoal.achieved,
              currentProgress: goalData['current_progress'] != null
                  ? (goalData['current_progress'] as num).toDouble()
                  : existingGoal.currentProgress,
            );

            // Update without marking for sync (to avoid circular updates)
            final db = await _dbHelper.database;
            await db.update(
              'goal',
              goal.toMap(),
              where: 'goal_id = ?',
              whereArgs: [goalId],
            );
          }
        } catch (e) {
          print('Error syncing goal ${doc.id}: $e');
          // Continue with other goals even if one fails
        }
      }

      return true;
    } catch (e) {
      print('Error syncing goals: $e');
      return false;
    }
  }

  // Sync metrics from Firestore to SQLite
  Future<bool> _syncMetrics(String userId) async {
    try {
      print('Syncing metrics for user: $userId');
      // Timestamp of last successful sync
      final lastSyncTime =
          _lastSuccessfulSync?.subtract(const Duration(minutes: 5)) ??
              DateTime(2000);

      // Get all metrics updated since last sync
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_metrics')
          .where('last_updated', isGreaterThan: lastSyncTime)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No updated metrics to sync');
        return true;
      }

      print('Found ${querySnapshot.docs.length} metrics to sync');
      final db = await _dbHelper.database;

      // Process each metric entry
      for (final doc in querySnapshot.docs) {
        try {
          final metricData = doc.data();
          final metricId = int.parse(doc.id);

          // Check if metric exists locally
          final existingMetric = await db.query(
            'user_metrics',
            where: 'metric_id = ?',
            whereArgs: [metricId],
          );

          if (existingMetric.isEmpty) {
            // Insert new metric
            print('Creating new metric: $metricId');
            await db.insert(
              'user_metrics',
              {
                'metric_id': metricId,
                'user_id': userId,
                'weight_kg': metricData['weight_kg'],
                'measured_at': metricData['measured_at'] ??
                    DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            // Update existing metric
            print('Updating existing metric: $metricId');
            await db.update(
              'user_metrics',
              {
                'weight_kg': metricData['weight_kg'],
                'measured_at': metricData['measured_at'] ??
                    existingMetric.first['measured_at'],
              },
              where: 'metric_id = ?',
              whereArgs: [metricId],
            );
          }
        } catch (e) {
          print('Error syncing metric ${doc.id}: $e');
          // Continue with other metrics even if one fails
        }
      }

      return true;
    } catch (e) {
      print('Error syncing metrics: $e');
      return false;
    }
  }

  // Sync streak from Firestore to SQLite
  Future<bool> _syncStreak(String userId) async {
    try {
      print('Syncing streak for user: $userId');

      // Fetch streak data from Firestore
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('streak')
          .doc(userId)
          .get();

      if (!docSnapshot.exists) {
        print('No streak data found in Firestore');
        return true; // Not an error
      }

      final streakData = docSnapshot.data();
      if (streakData == null) {
        print('Streak data is null');
        return true; // Not an error
      }

      // Always use Firestore streak data on a new device if it's available
      final db = await _dbHelper.database;
      final hasLocalStreak = Sqflite.firstIntValue(await db
          .rawQuery('SELECT COUNT(*) FROM streak WHERE user_id = ?', [userId]));

      if (hasLocalStreak == 0) {
        print('No local streak data found, using Firestore data');
        final streak = Streak(
          userId: userId,
          currentStreak: streakData['current_streak'] as int? ?? 0,
          longestStreak: streakData['longest_streak'] as int? ?? 0,
          lastActivityDate: streakData['last_activity_date'] != null
              ? DateTime.parse(streakData['last_activity_date'])
              : null,
          lastWorkoutDate: streakData['last_workout_date'] != null
              ? DateTime.parse(streakData['last_workout_date'])
              : null,
        );

        // Insert streak record
        await db.insert('streak', streak.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        print(
            'Inserted Firestore streak data locally: ${streak.currentStreak} days');
      } else {
        // Check if streak exists locally
        final localStreak = await _dbHelper.getStreakForUser(userId);

        // Compare which streak is more up-to-date or has higher values
        if (localStreak != null) {
          final remoteLastActivity = streakData['last_activity_date'] != null
              ? DateTime.parse(streakData['last_activity_date'])
              : null;

          final localLastActivity = localStreak.lastActivityDate;

          if (remoteLastActivity != null && localLastActivity != null) {
            // If local data is more recent, keep it (do nothing)
            if (localLastActivity.isAfter(remoteLastActivity)) {
              print('Local streak data is more recent, keeping it');

              // But also update Firestore to match local
              await _updateStreakInFirestore(localStreak);
              return true;
            }
          }

          // If local streak is longer, keep it (save back to Firestore)
          final remoteCurrentStreak = streakData['current_streak'] as int? ?? 0;
          final remoteLongestStreak = streakData['longest_streak'] as int? ?? 0;

          if (localStreak.currentStreak > remoteCurrentStreak ||
              localStreak.longestStreak > remoteLongestStreak) {
            print('Local streak values are higher, keeping them');

            // Update Firestore with local streak
            await _updateStreakInFirestore(localStreak);
            return true;
          }

          // If we got here, we should use the Firestore streak data
          print('Using Firestore streak data');
          final streak = Streak(
            userId: userId,
            currentStreak: streakData['current_streak'] as int? ?? 0,
            longestStreak: streakData['longest_streak'] as int? ?? 0,
            lastActivityDate: streakData['last_activity_date'] != null
                ? DateTime.parse(streakData['last_activity_date'])
                : null,
            lastWorkoutDate: streakData['last_workout_date'] != null
                ? DateTime.parse(streakData['last_workout_date'])
                : null,
          );

          // Update local streak
          await _dbHelper.updateUserStreak(streak);
        }
      }

      // Now sync the daily activity logs for the calendar
      await _syncDailyLogs(userId);

      return true;
    } catch (e) {
      print('Error syncing streak: $e');
      return false;
    }
  }

  // Sync daily activity logs for calendar display
  Future<bool> _syncDailyLogs(String userId) async {
    try {
      print('Syncing daily logs for user: $userId');

      // Get logs from last 3 months
      final threeMothsAgo = DateTime.now().subtract(const Duration(days: 90));
      final formattedDate = threeMothsAgo.toIso8601String();

      print('Fetching daily logs since: $formattedDate');

      // Check if the notes column exists in daily_log
      final db = await _dbHelper.database;
      final columns = await db.rawQuery('PRAGMA table_info(daily_log)');
      final hasNotesColumn = columns.any((col) => col['name'] == 'notes');
      print('Daily log has notes column: $hasNotesColumn');

      // First try to fetch all daily logs
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_log')
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No daily logs found in Firestore');

        // Also create daily logs from workouts if none exist
        await _createDailyLogsFromWorkouts(userId);

        return true;
      }

      print('Found ${querySnapshot.docs.length} daily logs to sync');

      // Process each log
      for (final doc in querySnapshot.docs) {
        try {
          final logData = doc.data();
          final logId = int.parse(doc.id);

          // Check if this log already exists locally
          final existingLog = await db.query(
            'daily_log',
            where: 'daily_log_id = ?',
            whereArgs: [logId],
          );

          if (existingLog.isEmpty) {
            // Insert new log
            print('Creating new daily log: $logId');

            // Prepare data map based on available columns
            Map<String, dynamic> insertData = {
              'daily_log_id': logId,
              'user_id': userId,
              'date': logData['date'],
              'activity_type': logData['activity_type'] ?? 'workout',
            };

            // Only add notes if the column exists
            if (hasNotesColumn && logData['notes'] != null) {
              insertData['notes'] = logData['notes'];
            }

            await db.insert(
              'daily_log',
              insertData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            // Update existing log
            print('Updating existing daily log: $logId');

            // Prepare update data based on available columns
            Map<String, dynamic> updateData = {
              'date': logData['date'],
              'activity_type': logData['activity_type'] ?? 'workout',
            };

            // Only add notes if the column exists
            if (hasNotesColumn && logData['notes'] != null) {
              updateData['notes'] = logData['notes'];
            }

            await db.update(
              'daily_log',
              updateData,
              where: 'daily_log_id = ?',
              whereArgs: [logId],
            );
          }
        } catch (e) {
          print('Error syncing daily log ${doc.id}: $e');
          // Continue with other logs
        }
      }

      return true;
    } catch (e) {
      print('Error syncing daily logs: $e');
      return false;
    }
  }

  // Create daily logs from workouts if no logs exist
  Future<void> _createDailyLogsFromWorkouts(String userId) async {
    try {
      print('Creating daily logs from workouts');

      // Get workouts from Firestore
      final workoutsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workout')
          .get();

      if (workoutsSnapshot.docs.isEmpty) {
        print('No workouts found to create logs from');
        return;
      }

      print(
          'Found ${workoutsSnapshot.docs.length} workouts to create logs from');
      final db = await _dbHelper.database;

      // Check if the notes column exists
      bool hasNotesColumn = true;
      try {
        final columns = await db.rawQuery('PRAGMA table_info(daily_log)');
        hasNotesColumn = columns.any((col) => col['name'] == 'notes');
        print('Daily log has notes column: $hasNotesColumn');
      } catch (e) {
        print('Error checking daily_log schema: $e');
        hasNotesColumn = false;
      }

      // For each workout, create a daily log
      for (final doc in workoutsSnapshot.docs) {
        try {
          final workoutData = doc.data();
          if (workoutData['date'] == null) continue;

          // Generate a unique ID for the log
          final logId =
              DateTime.now().millisecondsSinceEpoch + int.parse(doc.id);

          // Check if log exists for this date
          final date = workoutData['date'] as String;
          final existingLog = await db.query(
            'daily_log',
            where: 'user_id = ? AND date = ?',
            whereArgs: [userId, date],
          );

          if (existingLog.isEmpty) {
            // Insert new log
            print('Creating daily log from workout for date: $date');

            // Prepare data based on schema
            Map<String, dynamic> logData = {
              'daily_log_id': logId,
              'user_id': userId,
              'date': date,
              'activity_type': 'workout',
            };

            // Only add notes if the column exists
            if (hasNotesColumn && workoutData['notes'] != null) {
              logData['notes'] = workoutData['notes'];
            }

            // Insert locally
            await db.insert(
              'daily_log',
              logData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Also insert to Firestore
            final firestoreData = {
              'date': date,
              'activity_type': 'workout',
              'user_id': userId,
              'last_updated': FieldValue.serverTimestamp(),
            };

            // Add notes to Firestore data if available
            if (workoutData['notes'] != null) {
              firestoreData['notes'] = workoutData['notes'];
            }

            await _firestore
                .collection('users')
                .doc(userId)
                .collection('daily_log')
                .doc(logId.toString())
                .set(firestoreData);
          }
        } catch (e) {
          print('Error creating log from workout ${doc.id}: $e');
        }
      }
    } catch (e) {
      print('Error creating daily logs from workouts: $e');
    }
  }

  // Helper method to update streak in Firestore
  Future<void> _updateStreakInFirestore(Streak streak) async {
    try {
      await _firestore
          .collection('users')
          .doc(streak.userId)
          .collection('streak')
          .doc(streak.userId)
          .set(
        {
          'current_streak': streak.currentStreak,
          'longest_streak': streak.longestStreak,
          'last_activity_date': streak.lastActivityDate?.toIso8601String(),
          'last_workout_date': streak.lastWorkoutDate?.toIso8601String(),
          'last_updated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating streak in Firestore: $e');
    }
  }

  // Generate daily logs from workout data
  Future<void> _generateDailyLogsFromWorkouts(String userId) async {
    try {
      final db = await _dbHelper.database;

      // Check if the notes column exists
      bool hasNotesColumn = true;
      try {
        final columns = await db.rawQuery('PRAGMA table_info(daily_log)');
        hasNotesColumn = columns.any((col) => col['name'] == 'notes');
        print('Daily log has notes column (generate): $hasNotesColumn');
      } catch (e) {
        print('Error checking daily_log schema: $e');
        hasNotesColumn = false;
      }

      // Get workouts that might need daily logs (last 3 months)
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final workouts = await db.query(
        'workout',
        where: 'user_id = ? AND date > ?',
        whereArgs: [userId, normaliseDate(threeMonthsAgo)],
      );

      print('Checking ${workouts.length} workouts for generating daily logs');

      // Create a set to track unique dates
      final processedDates = <String>{};

      for (final workout in workouts) {
        try {
          final workoutDate = workout['date'] as String?;
          if (workoutDate == null || processedDates.contains(workoutDate)) {
            continue; // Skip null dates or already processed dates
          }

          processedDates.add(workoutDate);

          // Check if a daily log exists for this date
          final existingLog = await db.query(
            'daily_log',
            where: 'user_id = ? AND date = ?',
            whereArgs: [userId, workoutDate],
          );

          if (existingLog.isEmpty) {
            // Create a new daily log
            final logId =
                DateTime.now().millisecondsSinceEpoch + workoutDate.hashCode;

            // Prepare data based on schema
            Map<String, dynamic> logData = {
              'daily_log_id': logId,
              'user_id': userId,
              'date': workoutDate,
              'activity_type': 'workout',
            };

            // Only add notes if the column exists
            if (hasNotesColumn && workout['notes'] != null) {
              logData['notes'] = workout['notes'];
            }

            await db.insert(
              'daily_log',
              logData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Mark for sync
            await queueForSync('daily_log', logId.toString(), 'INSERT');
            print('Created and queued daily log for workout on $workoutDate');
          }
        } catch (e) {
          print('Error processing workout for daily log: $e');
        }
      }
    } catch (e) {
      print('Error generating daily logs from workouts: $e');
    }
  }
}

// Class to represent sync status for UI updates
class SyncStatus {
  final bool isInProgress;
  final DateTime? lastAttempt;
  final DateTime? lastSuccess;
  final String? lastError;

  SyncStatus({
    required this.isInProgress,
    this.lastAttempt,
    this.lastSuccess,
    this.lastError,
  });
}
