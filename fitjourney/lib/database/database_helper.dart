import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Import local database models
import 'package:fitjourney/database_models/user.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/database_models/exercise.dart';
import 'package:fitjourney/database_models/workout_set.dart';
import 'package:fitjourney/database_models/workout_exercise.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/database_models/daily_log.dart';
import 'package:fitjourney/database_models/streak.dart';
import 'package:fitjourney/services/goal_tracking_service.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:fitjourney/utils/date_utils.dart';

/// DatabaseHelper is the core class that manages all local SQLite database operations.
/// I've implemented it using the singleton pattern to ensure only one instance
/// exists throughout the app lifecycle, preventing multiple database connections.
/// This class handles all CRUD operations for workouts, exercises, goals, and user data,
/// serving as the backbone of the app's offline-first data architecture.
class DatabaseHelper {
  // Singleton instance - ensures we only have one database helper throughout the app
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database; // The actual database instance

  // Private constructor to enforce singleton pattern
  DatabaseHelper._internal();

  /// Returns the database instance, creating it if it doesn't exist yet.
  /// This lazy initialization pattern ensures the database is only created
  /// when first needed, improving startup performance.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();

    // Run migrations to update database schema if needed
    // This is important for handling app updates with schema changes
    await _runMigrations(_database!);

    return _database!;
  }

  /// Initializes the SQLite database file.
  /// This creates or opens the database file in the app's documents directory,
  /// which is where app-specific persistent data should be stored.
  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'myfitness.db');

    print("Database Path: $path"); // Debug print to verify database location
    return await openDatabase(
      path,
      version: 1, // Increment this when schema changes
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onOpen: (db) => print("Database Opened!"),
    );
  }

  /// Enables foreign key constraints for the SQLite database.
  /// This is critical for maintaining referential integrity between tables
  /// (e.g., ensuring workouts aren't orphaned when a user is deleted).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Creates all database tables when the database is first initialized.
  /// This defines the entire schema of the application, with carefully designed
  /// relationships between entities. I've used foreign keys to maintain data integrity
  /// and added check constraints to ensure data validity (e.g., weight > 0).
  Future<void> _onCreate(Database db, int version) async {
    // USERS table - stores basic user profile information
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        user_id           TEXT PRIMARY KEY,
        first_name        TEXT NOT NULL,
        last_name         TEXT NOT NULL,
        height_cm         REAL CHECK (height_cm > 0),
        registration_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_login        DATETIME
      );
    ''');

    // USER_METRICS table - tracks user weight measurements over time
    // This separation allows for historical tracking of metrics
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_metrics (
        metric_id   INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT NOT NULL,
        weight_kg   REAL CHECK (weight_kg > 0),
        measured_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
    ''');

    // EXERCISE table - predefined exercises with muscle groups
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise (
        exercise_id  INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT NOT NULL,
        muscle_group TEXT,
        description  TEXT
      );
    ''');

    // WORKOUT table - records workout sessions with date and duration
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout (
        workout_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    TEXT NOT NULL,
        date       DATETIME NOT NULL,
        duration   INT,
        notes      TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
    ''');

    // WORKOUT_EXERCISE table - junction table linking workouts to exercises
    // This implements the many-to-many relationship between workouts and exercises
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_exercise (
        workout_exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id          INTEGER NOT NULL,
        exercise_id         INTEGER NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workout(workout_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id)
      );
    ''');

    // WORKOUT_SET table - stores individual sets within a workout exercise
    // Tracks reps and weight for performance monitoring
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_set (
        workout_set_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id  INTEGER NOT NULL,
        set_number           INT NOT NULL,
        reps                 INT,
        weight               REAL,
        FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercise(workout_exercise_id)
      );
    ''');

    // GOAL table - tracks user fitness goals with different types
    // Uses check constraints to enforce data validity based on goal type
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal (
        goal_id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          TEXT NOT NULL,
        type             TEXT NOT NULL CHECK (type IN ('ExerciseTarget','WorkoutFrequency','WeightTarget')),
        exercise_id      INTEGER,
        target_value     REAL,
        start_date       DATE NOT NULL,
        end_date         DATE NOT NULL,
        achieved         BOOLEAN DEFAULT FALSE,
        current_progress REAL DEFAULT 0,
        achieved_date    DATE,
        FOREIGN KEY (user_id) REFERENCES users(user_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id),
        CHECK (
          (type = 'ExerciseTarget' AND exercise_id IS NOT NULL) OR
          (type = 'WorkoutFrequency' AND exercise_id IS NULL) OR
          (type = 'WeightTarget' AND exercise_id IS NULL)
        )
      );
    ''');

    // DAILY_LOG table - records activity status for each day (workout or rest)
    // Includes a unique constraint to prevent duplicate entries for the same day
    await db.execute('''
  CREATE TABLE IF NOT EXISTS daily_log (
    daily_log_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id       TEXT NOT NULL,
    date          DATE NOT NULL,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('workout','rest')),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    UNIQUE (user_id, date)
  );
''');

    // STREAK table - tracks user's workout consistency
    // Using the user_id as primary key since each user has only one streak record
    await db.execute('''
  CREATE TABLE IF NOT EXISTS streak (
    user_id            TEXT PRIMARY KEY,
    current_streak     INT DEFAULT 0,
    longest_streak     INT DEFAULT 0,
    last_activity_date DATE,
    last_workout_date  DATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
  );
''');

    // NOTIFICATION table - stores in-app notifications for achievements and reminders
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification (
        notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         TEXT NOT NULL,
        type            TEXT NOT NULL CHECK (type IN ('GoalProgress','NewStreak','Milestone')),
        message         TEXT NOT NULL,
        timestamp       DATETIME DEFAULT CURRENT_TIMESTAMP,
        is_read         BOOLEAN DEFAULT FALSE,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
    ''');

    // MILESTONE table - records significant achievements like personal bests
    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestone (
        milestone_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id      TEXT NOT NULL,
        type         TEXT NOT NULL CHECK (type IN ('PersonalBest','LongestStreak','GoalAchieved')),
        exercise_id  INTEGER,
        value        REAL,
        date         DATE NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id)
      );
    ''');

    // SYNC_QUEUE table - manages data synchronization with cloud storage
    // A critical component of the offline-first architecture
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        synced BOOLEAN DEFAULT FALSE,
        UNIQUE(table_name, record_id, operation)
      );
    ''');
  }

// -------------------------
  // CRUD Operations
  // -------------------------

  /// Marks a database record for synchronization with Firebase Cloud Firestore.
  /// This is a crucial part of my offline-first architecture, ensuring data changes
  /// made while offline are properly synchronized when connectivity is restored.
  /// It adds the changed record to a sync queue table that's processed by the SyncService.
  ///
  /// @param tableName The name of the database table containing the record
  /// @param recordId The unique identifier of the record to sync
  /// @param operation The operation type (INSERT, UPDATE, DELETE)
  Future<void> markForSync(
      String tableName, String recordId, String operation) async {
    try {
      // Direct database operation to avoid circular dependencies with SyncService
      final db = await database;

      // Add to sync queue with current timestamp
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

      print('Marked for sync: $tableName, $recordId, $operation');
    } catch (e) {
      print('Error marking for sync: $e');
      // Don't throw - sync failure shouldn't break app functionality
      // This ensures the app remains usable even if sync fails
    }
  }

  /// Inserts a new user into the database and marks it for cloud synchronization.
  /// Used during user registration and when a user first logs in on a new device.
  ///
  /// @param user The AppUser object containing user details to insert
  Future<void> insertUser(AppUser user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await markForSync('users', user.userId, 'INSERT');
  }

  /// Retrieves a user from the database by their unique user ID.
  /// Used for loading profile information and checking if a user exists locally.
  ///
  /// @param userId The unique Firebase Auth ID of the user
  /// @return AppUser object if found, null otherwise
  Future<AppUser?> getUserById(String userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isNotEmpty) {
      return AppUser.fromMap(result.first);
    }
    return null;
  }

  /// Updates the last login timestamp for a user.
  /// Important for tracking user activity and calculating analytics.
  ///
  /// @param userId The unique ID of the user whose login time to update
  Future<void> updateUserLastLogin(String userId) async {
    final db = await database;
    await db.update(
      'users',
      {'last_login': DateTime.now().toIso8601String()},
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    await markForSync('users', userId, 'UPDATE');
  }

  /// ----- Workout CRUD Operations -----
  /// These methods handle the core functionality of tracking workouts,
  /// which is the primary purpose of the fitness tracking app.

  /// Inserts a new workout session into the database.
  /// The foundation of the app's workout tracking capability.
  ///
  /// @param workout The Workout object to insert
  /// @return The ID of the newly inserted workout
  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    final workoutId = await db.insert(
      'workout',
      workout.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await markForSync('workout', workoutId.toString(), 'INSERT');
    return workoutId;
  }

  /// Retrieves a specific workout by its ID.
  /// Used for displaying workout details and editing existing workouts.
  ///
  /// @param workoutId The unique identifier of the workout to retrieve
  /// @return Workout object if found, null otherwise
  Future<Workout?> getWorkoutById(int workoutId) async {
    final db = await database;
    final result = await db.query(
      'workout',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );

    if (result.isNotEmpty) {
      return Workout.fromMap(result.first);
    }
    return null;
  }

  /// Gets all workouts for a specific user, ordered by date (newest first).
  /// Used for workout history display and progress analysis.
  ///
  /// @param userId The ID of the user whose workouts to retrieve
  /// @return List of Workout objects sorted by date (descending)
  Future<List<Workout>> getWorkoutsForUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'workout',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );

    return result.map((map) => Workout.fromMap(map)).toList();
  }

  /// Updates an existing workout with new information.
  /// Enables users to correct mistakes or add additional details.
  ///
  /// @param workout The Workout object with updated values
  Future<void> updateWorkout(Workout workout) async {
    final db = await database;
    await db.update(
      'workout',
      workout.toMap(),
      where: 'workout_id = ?',
      whereArgs: [workout.workoutId],
    );

    await markForSync('workout', workout.workoutId.toString(), 'UPDATE');
  }

  /// Deletes a workout and all its associated data (exercises and sets).
  /// This uses a transaction to ensure data integrity - either all related data
  /// is deleted or none of it is, preventing orphaned records.
  ///
  /// @param workoutId The ID of the workout to delete
  Future<void> deleteWorkout(int workoutId) async {
    final db = await database;

    // Use a transaction to ensure all related data is deleted atomically
    // This guarantees database integrity even if the operation is interrupted
    await db.transaction((txn) async {
      // First, get all workout_exercise records
      final workoutExercises = await txn.query(
        'workout_exercise',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );

      // Delete associated sets for each workout_exercise
      for (var exercise in workoutExercises) {
        final workoutExerciseId = exercise['workout_exercise_id'] as int;
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

      // Delete the workout record
      await txn.delete(
        'workout',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );
    });

    // Mark for cloud sync to ensure deleted workout is removed from cloud storage too
    await markForSync('workout', workoutId.toString(), 'DELETE');
  }

  // ----- Exercise CRUD Operations -----

  /// Inserts a new exercise into the exercise library.
  /// Used when initializing the app with predefined exercises or
  /// when users create custom exercises.
  ///
  /// @param exercise The Exercise object to insert
  /// @return The ID of the newly inserted exercise
  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    final exerciseId = await db.insert(
      'exercise',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return exerciseId;
  }

  /// Retrieves all exercises in the exercise library.
  /// Used for exercise selection during workout logging.
  /// I've excluded certain exercises (like abs) that I'm planning to add
  /// in a future update with specialized tracking.
  ///
  /// @return List of all Exercise objects, alphabetically sorted
  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final result = await db.query(
      'exercise',
      where: "muscle_group != 'Abs' AND name != 'Push-Up'",
      orderBy: 'name ASC',
    );

    return result.map((map) => Exercise.fromMap(map)).toList();
  }

  /// Gets exercises filtered by a specific muscle group.
  /// This powers the muscle group filtering in the exercise selection screen,
  /// helping users quickly find relevant exercises.
  ///
  /// @param muscleGroup The muscle group to filter by (e.g., "Chest", "Back")
  /// @return List of Exercise objects for the specified muscle group
  Future<List<Exercise>> getExercisesByMuscleGroup(String muscleGroup) async {
    final db = await database;
    final result = await db.query(
      'exercise',
      where: "muscle_group = ? AND name != 'Push-Up'",
      whereArgs: [muscleGroup],
      orderBy: 'name ASC',
    );

    return result.map((map) => Exercise.fromMap(map)).toList();
  }

  /// Retrieves a specific exercise by its ID.
  /// Used when displaying exercise details or for tracking specific
  /// exercise progress over time.
  ///
  /// @param exerciseId The ID of the exercise to retrieve
  /// @return Exercise object if found, null otherwise
  Future<Exercise?> getExerciseById(int exerciseId) async {
    final db = await database;
    final result = await db.query(
      'exercise',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );

    if (result.isNotEmpty) {
      return Exercise.fromMap(result.first);
    }
    return null;
  }

  /// ----- WorkoutExercise CRUD Operations -----
  /// WorkoutExercise represents the junction between workouts and exercises,
  /// enabling the many-to-many relationship between them.

  /// Associates an exercise with a workout by creating a workout_exercise record.
  /// This is a key step in the workout logging flow, where users select
  /// exercises to include in their workout.
  ///
  /// @param workoutExercise The WorkoutExercise object linking a workout and exercise
  /// @return The ID of the newly created workout_exercise record
  Future<int> insertWorkoutExercise(WorkoutExercise workoutExercise) async {
    final db = await database;
    final workoutExerciseId = await db.insert(
      'workout_exercise',
      workoutExercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return workoutExerciseId;
  }

  /// Retrieves all exercises associated with a specific workout.
  /// Used when displaying workout details or editing a workout.
  /// I've implemented this with a JOIN to fetch complete exercise details
  /// in a single query, improving performance.
  ///
  /// @param workoutId The ID of the workout whose exercises to retrieve
  /// @return List of maps containing joined workout_exercise and exercise data
  Future<List<Map<String, dynamic>>> getExercisesForWorkout(
      int workoutId) async {
    final db = await database;

    // Using a JOIN query to get both workout_exercise and exercise data at once
    // This is more efficient than multiple separate queries
    final result = await db.rawQuery('''
      SELECT we.workout_exercise_id, we.workout_id, e.* 
      FROM workout_exercise we
      JOIN exercise e ON we.exercise_id = e.exercise_id
      WHERE we.workout_id = ?
      ORDER BY we.workout_exercise_id ASC
    ''', [workoutId]);

    return result;
  }

  /// ----- WorkoutSet CRUD Operations -----
  /// WorkoutSet represents the actual performance data (reps, weight)
  /// for each exercise in a workout.

  /// Records a set for a specific exercise within a workout.
  /// This captures the actual performance metrics (reps, weight) that form
  /// the foundation for progress tracking.
  ///
  /// @param workoutSet The WorkoutSet object containing set details
  /// @return The ID of the newly created workout_set record
  Future<int> insertWorkoutSet(WorkoutSet workoutSet) async {
    final db = await database;
    final workoutSetId = await db.insert(
      'workout_set',
      workoutSet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return workoutSetId;
  }

  /// Retrieves all sets for a specific exercise within a workout.
  /// Used for displaying detailed workout information and for
  /// calculating volume and tracking progress.
  ///
  /// @param workoutExerciseId The ID of the workout_exercise record
  /// @return List of WorkoutSet objects for the specified workout exercise
  Future<List<WorkoutSet>> getSetsForWorkoutExercise(
      int workoutExerciseId) async {
    final db = await database;
    final result = await db.query(
      'workout_set',
      where: 'workout_exercise_id = ?',
      whereArgs: [workoutExerciseId],
      orderBy: 'set_number ASC',
    );

    return result.map((map) => WorkoutSet.fromMap(map)).toList();
  }

  /// Updates an existing workout set with new information.
  /// Allows users to correct or adjust recorded performance data.
  ///
  /// @param workoutSet The WorkoutSet object with updated values
  Future<void> updateWorkoutSet(WorkoutSet workoutSet) async {
    final db = await database;
    await db.update(
      'workout_set',
      workoutSet.toMap(),
      where: 'workout_set_id = ?',
      whereArgs: [workoutSet.workoutSetId],
    );
  }

  /// Deletes a specific workout set.
  /// Used when removing sets from a workout during editing.
  ///
  /// @param workoutSetId The ID of the workout set to delete
  Future<void> deleteWorkoutSet(int workoutSetId) async {
    final db = await database;
    await db.delete(
      'workout_set',
      where: 'workout_set_id = ?',
      whereArgs: [workoutSetId],
    );
  }

  /// ----- Utility Methods for Workout Logging -----
  /// These methods provide higher-level functionality by combining
  /// multiple database operations for common use cases.

  /// Saves a complete workout with all its exercises and sets in a single transaction.
  /// This is the core method for workout logging, ensuring all related data
  /// is saved atomically. It also handles personal best detection and streak updates.
  ///
  /// I'm particularly proud of this implementation as it encapsulates complex logic
  /// for personal best detection while maintaining database integrity through transactions.
  ///
  /// @param userId The user ID who performed the workout
  /// @param date The date of the workout
  /// @param duration Optional duration of the workout in minutes
  /// @param notes Optional notes about the workout
  /// @param exercises List of exercises with their sets
  /// @return The ID of the newly created workout
  Future<int> saveCompleteWorkout({
    required String userId,
    required DateTime date,
    required int? duration,
    required String? notes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final db = await database;
    int workoutId = 0;

    // Track potential personal bests to evaluate after saving the workout
    final exercisesToCheckForPB = <int>{};
    final exerciseMaxWeights = <int, double>{};

    // Use a transaction to ensure all related data is saved atomically
    // This prevents partial data being saved if an error occurs
    await db.transaction((txn) async {
      // 1. Insert the workout record first
      workoutId = await txn.insert(
        'workout',
        {
          'user_id': userId,
          'date': normaliseDate(date),
          'duration': duration == 0 ? null : duration,
          'notes': notes,
        },
      );

      // 2. Insert each exercise and its sets
      for (var exercise in exercises) {
        final workoutExerciseId = await txn.insert(
          'workout_exercise',
          {
            'workout_id': workoutId,
            'exercise_id': exercise['exercise_id'],
          },
        );

        // 3. Insert sets for this exercise
        for (var set in exercise['sets']) {
          await txn.insert(
            'workout_set',
            {
              'workout_exercise_id': workoutExerciseId,
              'set_number': set['set_number'],
              'reps': set['reps'],
              'weight': set['weight'],
            },
          );

          // Track possible personal bests while processing sets
          if (set['weight'] != null && set['weight'] > 0) {
            final int exerciseId = exercise['exercise_id'];
            final double weight = set['weight'];

            if (!exercisesToCheckForPB.contains(exerciseId)) {
              exercisesToCheckForPB.add(exerciseId);
              exerciseMaxWeights[exerciseId] = weight;
            } else if (weight > (exerciseMaxWeights[exerciseId] ?? 0)) {
              exerciseMaxWeights[exerciseId] = weight;
            }
          }
        }
      }
    });

    // After the transaction, check for personal bests and create milestones
    // I've separated this from the transaction as it's not critical for data integrity
    // and allows for more complex queries across workout history
    for (var exerciseId in exercisesToCheckForPB) {
      final maxWeight = exerciseMaxWeights[exerciseId];
      if (maxWeight != null) {
        // Get current max weight to see if this is a new personal best
        // This query finds the max weight ever lifted for this exercise by this user
        final prevMaxResult = await db.rawQuery('''
        SELECT MAX(ws.weight) as max_weight
        FROM workout_set ws
        JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
        JOIN workout w ON we.workout_id = w.workout_id
        WHERE we.exercise_id = ? AND w.user_id = ? AND w.workout_id != ? AND ws.weight IS NOT NULL
      ''', [exerciseId, userId, workoutId]);

        final double? prevMax = prevMaxResult.isNotEmpty &&
                prevMaxResult.first['max_weight'] != null
            ? (prevMaxResult.first['max_weight'] as num).toDouble()
            : null;

        // If this is a new personal best, create a milestone record
        if (prevMax == null || maxWeight > prevMax) {
          await db.insert(
            'milestone',
            {
              'user_id': userId,
              'type': 'PersonalBest',
              'exercise_id': exerciseId,
              'value': maxWeight,
              'date': DateTime.now().toIso8601String(),
            },
          );

          // Update any related strength goals directly
          // This helps maintain real-time goal progress
          await GoalTrackingService.instance
              .updateGoalsAfterPersonalBest(exerciseId, maxWeight);
        }
      }
    }

    // Mark for sync to ensure cloud backup
    await markForSync('workout', workoutId.toString(), 'INSERT');

    // After saving workout, update goals based on this new workout
    final workout = Workout(
      workoutId: workoutId,
      userId: userId,
      date: date,
      duration: duration,
      notes: notes,
    );

    // Update goals that depend on workout frequency or volume
    await GoalTrackingService.instance.updateGoalsAfterWorkout(workout);

    // Update streak when workout is logged
    // This maintains the continuous activity tracking feature
    try {
      await StreakService.instance.logWorkout(date);
    } catch (e) {
      print('Error updating streak: $e');
      // Don't throw - we want to keep the workout even if streak update fails
      // This follows the principle of resilience in error handling
    }

    return workoutId;
  }

  /// Initializes the exercise database with predefined exercises if empty.
  /// This provides users with a comprehensive starter library of exercises
  /// without requiring them to create exercises manually.
  ///
  /// I've carefully selected exercises covering all major muscle groups
  /// and included detailed descriptions for proper form guidance.
  Future<void> initializeExercisesIfNeeded() async {
    final db = await database;
    final exerciseCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM exercise'));

    if (exerciseCount == 0) {
      // No exercises exist, populate with default exercises
      // Using a transaction for bulk inserts improves performance
      await db.transaction((txn) async {
        // Chest exercises
        await txn.insert('exercise', {
          'name': 'Bench Press',
          'muscle_group': 'Chest',
          'description':
              'Lie on a flat bench and push a weighted barbell upward.'
        });
        await txn.insert('exercise', {
          'name': 'Incline Dumbbell Press',
          'muscle_group': 'Chest',
          'description': 'Lie on an inclined bench and push dumbbells upward.'
        });
        await txn.insert('exercise', {
          'name': 'Chest Fly',
          'muscle_group': 'Chest',
          'description': 'Lie on a bench and move weights in an arc motion.'
        });
        await txn.insert('exercise', {
          'name': 'Cable Fly',
          'muscle_group': 'Chest',
          'description':
              'Stand between cable pulleys and bring handles together in front of your chest in an arc motion.'
        });

        // Back exercises
        await txn.insert('exercise', {
          'name': 'Deadlift',
          'muscle_group': 'Back',
          'description': 'Lift a weighted barbell off the ground to hip level.'
        });
        await txn.insert('exercise', {
          'name': 'Bent Over Row',
          'muscle_group': 'Back',
          'description':
              'Bend at the waist and pull weights up toward your torso.'
        });
        await txn.insert('exercise', {
          'name': 'Lat Pulldown',
          'muscle_group': 'Back',
          'description': 'Pull a weighted bar down while seated.'
        });
        await txn.insert('exercise', {
          'name': 'Barbell Row',
          'muscle_group': 'Back',
          'description':
              'Bend forward with a slight knee bend and pull a barbell towards your lower chest/upper abdomen.'
        });
        await txn.insert('exercise', {
          'name': 'T-Bar Row',
          'muscle_group': 'Back',
          'description':
              'Using a T-bar row machine or landmine setup, pull the weight toward your torso while maintaining a hinged position.'
        });

        // Additional muscle groups continue below...
      });
    }
  }

  /// ----- Goal CRUD Operations -----
  /// These methods manage fitness goals, one of the key motivational
  /// features of the app.

  /// Creates a new fitness goal and marks it for cloud synchronization.
  /// Goals are a central motivational feature of the app, allowing users
  /// to set targets for workouts, specific exercises, or body weight.
  ///
  /// @param goal The Goal object containing goal details
  /// @return The ID of the newly created goal
  Future<int> insertGoal(Goal goal) async {
    final db = await database;
    final goalId = await db.insert(
      'goal',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await markForSync('goal', goalId.toString(), 'INSERT');
    return goalId;
  }

  /// Retrieves a specific goal by its ID.
  /// Used when displaying goal details or updating goal progress.
  ///
  /// @param goalId The ID of the goal to retrieve
  /// @return Goal object if found, null otherwise
  Future<Goal?> getGoalById(int goalId) async {
    final db = await database;
    final result = await db.query(
      'goal',
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );

    if (result.isNotEmpty) {
      return Goal.fromMap(result.first);
    }
    return null;
  }

  /// Gets all goals for a user, sorted by end date.
  /// Used in the goals overview screen to display all user goals.
  ///
  /// @param userId The ID of the user whose goals to retrieve
  /// @return List of all Goal objects for the user
  Future<List<Goal>> getGoalsForUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'goal',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'end_date ASC',
    );

    return result.map((map) => Goal.fromMap(map)).toList();
  }

  /// Gets only active (not achieved) goals for a user.
  /// This powers the "Current Goals" section of the goals page,
  /// focusing user attention on goals still in progress.
  ///
  /// @param userId The ID of the user whose active goals to retrieve
  /// @return List of active Goal objects
  Future<List<Goal>> getActiveGoals(String userId) async {
    final db = await database;
    final result = await db.query(
      'goal',
      where: 'user_id = ? AND achieved = 0',
      whereArgs: [userId],
      orderBy: 'end_date ASC',
    );

    return result.map((map) => Goal.fromMap(map)).toList();
  }

  /// Gets completed (achieved) goals for a user.
  /// This powers the "Completed Goals" section, providing users
  /// with a sense of accomplishment from past achievements.
  ///
  /// @param userId The ID of the user whose completed goals to retrieve
  /// @return List of achieved Goal objects
  Future<List<Goal>> getCompletedGoals(String userId) async {
    final db = await database;
    final result = await db.query(
      'goal',
      where: 'user_id = ? AND achieved = 1',
      whereArgs: [userId],
      orderBy: 'achieved_date DESC, end_date DESC',
    );

    return result.map((map) => Goal.fromMap(map)).toList();
  }

  /// Updates the progress of a goal towards its target.
  /// Called whenever relevant activities occur that contribute to goal progress.
  ///
  /// @param goalId The ID of the goal to update
  /// @param progress The new progress value
  Future<void> updateGoalProgress(int goalId, double progress) async {
    final db = await database;
    await db.update(
      'goal',
      {'current_progress': progress},
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );

    await markForSync('goal', goalId.toString(), 'UPDATE');
  }

  /// Marks a goal as achieved and creates related milestone and notification.
  /// This uses a transaction to ensure all related records are created atomically.
  ///
  /// @param goalId The ID of the goal to mark as achieved
  Future<void> markGoalAchieved(int goalId) async {
    final db = await database;
    final now = DateTime.now();

    // Start a transaction to update the goal and create milestone/notification
    // This ensures database consistency if the operation is interrupted
    await db.transaction((txn) async {
      // Update goal
      await txn.update(
        'goal',
        {
          'achieved': 1,
          'achieved_date':
              now.toIso8601String(), // Add the current date as achieved_date
        },
        where: 'goal_id = ?',
        whereArgs: [goalId],
      );

      // Get goal details for milestone creation
      final goalResult = await txn.query(
        'goal',
        where: 'goal_id = ?',
        whereArgs: [goalId],
      );

      if (goalResult.isNotEmpty) {
        final goal = Goal.fromMap(goalResult.first);

        // Create milestone for achievement - this tracks major accomplishments
        await txn.insert(
          'milestone',
          {
            'user_id': goal.userId,
            'type': 'GoalAchieved',
            'exercise_id': goal.exerciseId,
            'value': goal.targetValue,
            'date': now.toIso8601String(),
          },
        );

        // Create notification to inform the user of their achievement
        // This triggers the celebratory notification in the app
        await txn.insert(
          'notification',
          {
            'user_id': goal.userId,
            'type': 'GoalProgress',
            'message': 'Congratulations! You\'ve achieved your goal.',
            'timestamp': now.toIso8601String(),
            'is_read': 0,
          },
        );
      }
    });

    await markForSync('goal', goalId.toString(), 'UPDATE');
  }

  /// Deletes a goal and marks it for deletion in cloud storage.
  /// Used when users abandon or remove goals.
  ///
  /// @param goalId The ID of the goal to delete
  Future<void> deleteGoal(int goalId) async {
    final db = await database;
    await db.delete(
      'goal',
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );

    await markForSync('goal', goalId.toString(), 'DELETE');
  }

  /// Counts workouts within a specified date range for a user.
  /// Critical for workout frequency goals where progress is measured
  /// by the number of workouts completed in a timeframe.
  ///
  /// @param userId The ID of the user whose workouts to count
  /// @param startDate The beginning of the date range
  /// @param endDate The end of the date range
  /// @return Count of workouts within the specified date range
  Future<int> countWorkoutsInDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM workout
      WHERE user_id = ? AND date BETWEEN ? AND ?
    ''', [userId, normaliseDate(startDate), normaliseDate(endDate)]);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Updates an existing goal with new parameters.
  /// This enables users to modify goal targets, timeframes, or other attributes.
  ///
  /// @param goal The Goal object with updated values
  Future<void> updateGoal(Goal goal) async {
    final db = await database;

    await db.update(
      'goal',
      goal.toMap(),
      where: 'goal_id = ?',
      whereArgs: [goal.goalId],
    );

    await markForSync('goal', goal.goalId.toString(), 'UPDATE');
  }

  /// Updates the status of all goals for a user.
  /// This is called periodically to check for achieved or expired goals.
  /// It's a key part of the app's automated goal tracking system.
  ///
  /// @param userId The ID of the user whose goals to update
  Future<void> updateAllGoalStatuses(String userId) async {
    final db = await database;

    // Get all active goals
    final goals = await getActiveGoals(userId);

    // Check each goal for completion or expiration
    for (final goal in goals) {
      // Mark achieved goals
      if (goal.currentProgress >= (goal.targetValue ?? 0) && !goal.achieved) {
        await markGoalAchieved(goal.goalId!);
      }

      // Check for expired goals
      if (normaliseDate(DateTime.now()).compareTo(normaliseDate(goal.endDate)) >
              0 &&
          !goal.achieved) {
        // Goal has expired without being achieved
        // Using value 2 to differentiate expired from achieved (1) and active (0)
        await db.update(
          'goal',
          {'achieved': 2}, // 2 indicates expired
          where: 'goal_id = ?',
          whereArgs: [goal.goalId],
        );

        await markForSync('goal', goal.goalId.toString(), 'UPDATE');
      }
    }
  }

  /// ----- Streak Management Methods -----
  /// These methods handle the workout streak feature, which encourages
  /// consistent workout habits through gamification.

  /// Retrieves the current streak information for a user.
  /// This powers the streak display on the home screen, which is
  /// a key motivational element for maintaining consistency.
  ///
  /// @param userId The ID of the user whose streak to retrieve
  /// @return Streak object if found, null otherwise
  Future<Streak?> getStreakForUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'streak',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return Streak.fromMap(result.first);
    }
    return null;
  }

  /// Updates a user's streak information and synchronizes with cloud storage.
  /// Called when workouts or rest days are recorded to maintain streak count.
  ///
  /// @param streak The Streak object with updated values
  Future<void> updateUserStreak(Streak streak) async {
    final db = await database;
    await db.update(
      'streak',
      streak.toMap(),
      where: 'user_id = ?',
      whereArgs: [streak.userId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await markForSync('streak', streak.userId, 'UPDATE');
  }

  /// ----- Daily Activity Logging Methods -----
  /// These methods track daily workout or rest activity,
  /// which powers the calendar view and streak calculations.

  /// Records a daily activity (workout or rest day).
  /// This maintains the calendar history and feeds into streak calculations.
  /// I've implemented logic to prevent downgrading from workout to rest,
  /// ensuring activity tracking accuracy.
  ///
  /// @param log The DailyLog object containing activity details
  /// @return The ID of the created or updated log
  Future<int> logDailyActivity(DailyLog log) async {
    final db = await database;
    int logId = 0;

    // Check for existing log on the same date to prevent duplicates
    final existingLogs = await db.query(
      'daily_log',
      where: 'user_id = ? AND date = ?',
      whereArgs: [log.userId, log.date.toIso8601String().split('T')[0]],
    );

    if (existingLogs.isEmpty) {
      // Insert new log if none exists for this date
      logId = await db.insert('daily_log', log.toMap());
      await markForSync('daily_log', logId.toString(), 'INSERT');
    } else {
      // Update existing log, but don't downgrade from workout to rest
      // This prevents accidental loss of workout status
      logId = existingLogs.first['daily_log_id'] as int;
      if (!(existingLogs.first['activity_type'] == 'workout' &&
          log.activityType == 'rest')) {
        await db.update(
          'daily_log',
          {'activity_type': log.activityType},
          where: 'daily_log_id = ?',
          whereArgs: [logId],
        );
        await markForSync('daily_log', logId.toString(), 'UPDATE');
      }
    }
    return logId;
  }

  /// Retrieves daily activity logs for a specified date range.
  /// Powers the calendar view and activity history displays.
  ///
  /// @param userId The ID of the user whose logs to retrieve
  /// @param startDate The beginning of the date range
  /// @param endDate The end of the date range
  /// @return List of DailyLog objects within the specified date range
  Future<List<DailyLog>> getDailyLogsForDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    final db = await database;

    final result = await db.query(
      'daily_log',
      where: 'user_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        userId,
        normaliseDate(startDate),
        normaliseDate(endDate),
      ],
      orderBy: 'date ASC',
    );

    return result.map((log) => DailyLog.fromMap(log)).toList();
  }

  /// Runs database migrations to update schema when necessary.
  /// This method is critical for app sustainability and user data retention:
  /// 1. Enables seamless app updates without data loss or corruption
  /// 2. Preserves user workout history and progress when updating
  /// 3. Essential for production mobile apps with an evolving feature set
  /// @param db The database instance to run migrations on
  Future<void> _runMigrations(Database db) async {
    try {
      // Check if the daily_log table has a notes column
      // This demonstrates how to safely add columns to existing tables
      final columns = await db.rawQuery('PRAGMA table_info(daily_log)');
      final hasNotesColumn = columns.any((col) => col['name'] == 'notes');

      if (!hasNotesColumn) {
        print('Running migration: Adding notes column to daily_log table');
        await db.execute('ALTER TABLE daily_log ADD COLUMN notes TEXT');
      }

      // Support for WeightTarget goals - a more complex migration
      // This demonstrates how to modify tables with constraints
      try {
        // We can't easily modify the check constraint, so recreate the goal table with new constraints
        // First, check if we need to do this by attempting to insert a test weight goal
        final testGoalResult = await db.rawQuery('''
          SELECT name FROM sqlite_master 
          WHERE type='table' AND name='goal' AND 
          sql LIKE '%WeightTarget%'
        ''');

        if (testGoalResult.isEmpty) {
          print('Running migration: Adding support for WeightTarget goals');

          // Backup existing goals to prevent data loss
          final goals = await db.query('goal');

          // Rename current goal table
          await db.execute('ALTER TABLE goal RENAME TO goal_old');

          // Create new goal table with updated constraints
          await db.execute('''
            CREATE TABLE IF NOT EXISTS goal (
              goal_id          INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id          TEXT NOT NULL,
              type             TEXT NOT NULL CHECK (type IN ('ExerciseTarget','WorkoutFrequency','WeightTarget')),
              exercise_id      INTEGER,
              target_value     REAL,
              start_date       DATE NOT NULL,
              end_date         DATE NOT NULL,
              achieved         BOOLEAN DEFAULT FALSE,
              current_progress REAL DEFAULT 0,
              achieved_date    DATE,
              FOREIGN KEY (user_id) REFERENCES users(user_id),
              FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id),
              CHECK (
                (type = 'ExerciseTarget' AND exercise_id IS NOT NULL) OR
                (type = 'WorkoutFrequency' AND exercise_id IS NULL) OR
                (type = 'WeightTarget' AND exercise_id IS NULL)
              )
            );
          ''');

          // Copy data from old table to new table
          for (var goal in goals) {
            await db.insert('goal', goal);
          }

          // Drop old table
          await db.execute('DROP TABLE goal_old');

          print('Migration completed: WeightTarget goals now supported');
        }
      } catch (e) {
        print('Error updating goal table constraints: $e');
        // Continue without throwing - this shouldn't break app functionality
        // Demonstrates graceful error handling in migrations
      }

      // Add starting_weight column to goal table for weight goals
      // This shows how to handle data model evolution over time
      final List<Map<String, dynamic>> goalColumns =
          await db.rawQuery('PRAGMA table_info(goal)');
      final goalColumnNames =
          goalColumns.map((col) => col['name'] as String).toList();

      if (!goalColumnNames.contains('starting_weight')) {
        print('Adding starting_weight column to goal table');
        await db.execute('ALTER TABLE goal ADD COLUMN starting_weight REAL');

        // Update existing weight goals with appropriate starting weights
        // This maintains data integrity during the migration
        await db.execute('''
          UPDATE goal 
          SET starting_weight = current_progress 
          WHERE type = 'WeightTarget'
        ''');

        print('Added starting_weight column to goal table');
      }

      // Add achieved_date column to goal table for tracking when goals are completed
      if (!goalColumnNames.contains('achieved_date')) {
        print('Adding achieved_date column to goal table');
        await db.execute('ALTER TABLE goal ADD COLUMN achieved_date TEXT');

        // For already achieved goals, set achieved_date to the current date
        // This ensures backward compatibility for existing data
        await db.execute('''
          UPDATE goal 
          SET achieved_date = ? 
          WHERE achieved = 1 AND achieved_date IS NULL
        ''', [DateTime.now().toIso8601String()]);

        print('Added achieved_date column to goal table');
      }

      // Future migrations would be added here as the app evolves
    } catch (e) {
      print('Error running migrations: $e');
      // Failures in migrations are logged but don't crash the app
      // This allows users to continue using core functionality
    }
  }

  /// Records a user weight measurement for a specific date.
  /// Used for manual weight entry and importing weight data.
  /// This is used primarily for weight tracking and weight-related goals.
  ///
  /// @param userId The ID of the user whose weight to record
  /// @param weight The weight measurement in kilograms
  /// @param date The date of the measurement
  /// @return The ID of the newly created weight record
  Future<int> insertUserWeight(
      String userId, double weight, DateTime date) async {
    final db = await database;
    return await db.insert('user_metrics', {
      'user_id': userId,
      'weight_kg': weight,
      'measured_at': date.toIso8601String(),
    });
  }
}
