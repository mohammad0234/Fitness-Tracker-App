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

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  // Getter for the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Initialise or open the database file
  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'myfitness.db');


  //   final dbFile = File(path);
  //   if (await dbFile.exists()) {
  //     await dbFile.delete();
  //     print("Deleted existing database");
  // }

    print("Database Path: $path"); // Debug print
    return await openDatabase(
      path,
      version: 1, 
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onOpen: (db) => print("Database Opened!"),
    );
  }

//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//   if (oldVersion < 2) {
//     print("Upgrading database from version $oldVersion to $newVersion");
//     // Create sync_queue table when upgrading to version 2
//     await db.execute('''
//       CREATE TABLE IF NOT EXISTS sync_queue (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         table_name TEXT NOT NULL,
//         record_id TEXT NOT NULL,
//         operation TEXT NOT NULL,
//         timestamp INTEGER NOT NULL,
//         synced BOOLEAN DEFAULT FALSE,
//         UNIQUE(table_name, record_id, operation)
//       );
//     ''');
//   }
// }

  // Enable foreign key constraints
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Create all tables
  Future<void> _onCreate(Database db, int version) async {
    // USERS table
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

    // USER_METRICS table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_metrics (
        metric_id   INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT NOT NULL,
        weight_kg   REAL CHECK (weight_kg > 0),
        measured_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
    ''');

    // EXERCISE table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise (
        exercise_id  INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT NOT NULL,
        muscle_group TEXT,
        description  TEXT
      );
    ''');

    // WORKOUT table
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

    // WORKOUT_EXERCISE table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_exercise (
        workout_exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id          INTEGER NOT NULL,
        exercise_id         INTEGER NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workout(workout_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id)
      );
    ''');

    // WORKOUT_SET table
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

    // GOAL table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal (
        goal_id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          TEXT NOT NULL,
        type             TEXT NOT NULL CHECK (type IN ('ExerciseTarget','WorkoutFrequency')),
        exercise_id      INTEGER,
        target_value     REAL,
        start_date       DATE NOT NULL,
        end_date         DATE NOT NULL,
        achieved         BOOLEAN DEFAULT FALSE,
        current_progress REAL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(user_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id),
        CHECK (
          (type = 'ExerciseTarget' AND exercise_id IS NOT NULL) OR
          (type = 'WorkoutFrequency' AND exercise_id IS NULL)
        )
      );
    ''');

    // DAILY_LOG table
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

    // STREAK table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS streak (
        user_id            TEXT PRIMARY KEY,
        current_streak     INT DEFAULT 0,
        longest_streak     INT DEFAULT 0,
        last_activity_date DATE,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
    ''');

    // NOTIFICATION table
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

    // MILESTONE table
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

    // PERSONAL_BEST table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS personal_best (
        personal_best_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          TEXT NOT NULL,
        exercise_id      INTEGER NOT NULL,
        max_weight       REAL,
        date             DATE NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id)
      );
    ''');
    
    // SYNC_QUEUE table
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

  // Mark a record for sync
  Future<void> markForSync(String tableName, String recordId, String operation) async {
    final db = await database;
    
    await db.insert(
      'sync_queue',
      {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert a new user into the 'users' table and mark for sync
  Future<void> insertUser(AppUser user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await markForSync('users', user.userId, 'INSERT');
  }

  // Retrieve a user by user_id
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

  // Update the last_login timestamp for a user
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

  // ----- Workout CRUD Operations -----

// Insert a new workout and mark for sync
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

// Get a workout by id
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

// Get all workouts for a user
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

// Update a workout
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

// Delete a workout
Future<void> deleteWorkout(int workoutId) async {
  final db = await database;
  
  // Use a transaction to ensure all related data is deleted
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
  
  await markForSync('workout', workoutId.toString(), 'DELETE');
}

// ----- Exercise CRUD Operations -----

// Insert a pre-defined exercise
Future<int> insertExercise(Exercise exercise) async {
  final db = await database;
  final exerciseId = await db.insert(
    'exercise',
    exercise.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  
  return exerciseId;
}

// Get all exercises
Future<List<Exercise>> getAllExercises() async {
  final db = await database;
  final result = await db.query('exercise');
  
  return result.map((map) => Exercise.fromMap(map)).toList();
}

// Get exercises by muscle group
Future<List<Exercise>> getExercisesByMuscleGroup(String muscleGroup) async {
  final db = await database;
  final result = await db.query(
    'exercise',
    where: 'muscle_group = ?',
    whereArgs: [muscleGroup],
    orderBy: 'name ASC',
  );
  
  return result.map((map) => Exercise.fromMap(map)).toList();
}

// Get an exercise by id
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

// ----- WorkoutExercise CRUD Operations -----

// Insert a workout exercise
Future<int> insertWorkoutExercise(WorkoutExercise workoutExercise) async {
  final db = await database;
  final workoutExerciseId = await db.insert(
    'workout_exercise',
    workoutExercise.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  
  return workoutExerciseId;
}

// Get all exercises for a workout
Future<List<Map<String, dynamic>>> getExercisesForWorkout(int workoutId) async {
  final db = await database;
  
  // Join workout_exercise with exercise to get exercise details
  final result = await db.rawQuery('''
    SELECT we.workout_exercise_id, we.workout_id, e.* 
    FROM workout_exercise we
    JOIN exercise e ON we.exercise_id = e.exercise_id
    WHERE we.workout_id = ?
    ORDER BY we.workout_exercise_id ASC
  ''', [workoutId]);
  
  return result;
}

// ----- WorkoutSet CRUD Operations -----

// Insert a workout set
Future<int> insertWorkoutSet(WorkoutSet workoutSet) async {
  final db = await database;
  final workoutSetId = await db.insert(
    'workout_set',
    workoutSet.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  
  return workoutSetId;
}

// Get all sets for a workout exercise
Future<List<WorkoutSet>> getSetsForWorkoutExercise(int workoutExerciseId) async {
  final db = await database;
  final result = await db.query(
    'workout_set',
    where: 'workout_exercise_id = ?',
    whereArgs: [workoutExerciseId],
    orderBy: 'set_number ASC',
  );
  
  return result.map((map) => WorkoutSet.fromMap(map)).toList();
}

// Update a workout set
Future<void> updateWorkoutSet(WorkoutSet workoutSet) async {
  final db = await database;
  await db.update(
    'workout_set',
    workoutSet.toMap(),
    where: 'workout_set_id = ?',
    whereArgs: [workoutSet.workoutSetId],
  );
}

// Delete a workout set
Future<void> deleteWorkoutSet(int workoutSetId) async {
  final db = await database;
  await db.delete(
    'workout_set',
    where: 'workout_set_id = ?',
    whereArgs: [workoutSetId],
  );
}

// ----- Utility Methods for Workout Logging -----

// Save a complete workout with exercises and sets in a transaction
Future<int> saveCompleteWorkout({
  required String userId,
  required DateTime date,
  required int? duration,
  required String? notes,
  required List<Map<String, dynamic>> exercises,
}) async {
  final db = await database;
  int workoutId = 0;
  
  await db.transaction((txn) async {
    // 1. Insert the workout
    workoutId = await txn.insert(
      'workout',
      {
        'user_id': userId,
        'date': date.toIso8601String(),
        'duration': duration,
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
      }
    }
  });
  
  // Mark for sync
  await markForSync('workout', workoutId.toString(), 'INSERT');
  
  return workoutId;
}

// Initialize database with predefined exercises
Future<void> initializeExercisesIfNeeded() async {
  final db = await database;
  final exerciseCount = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM exercise')
  );
  
  if (exerciseCount == 0) {
    // No exercises exist, populate with default exercises
    await db.transaction((txn) async {
      // Chest exercises
      await txn.insert('exercise', {
        'name': 'Bench Press',
        'muscle_group': 'Chest',
        'description': 'Lie on a flat bench and push a weighted barbell upward.'
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
        'name': 'Push-Up',
        'muscle_group': 'Chest',
        'description': 'A bodyweight exercise where you push your body up from the ground.'
      });
      
      // Back exercises
      await txn.insert('exercise', {
        'name': 'Deadlift',
        'muscle_group': 'Back',
        'description': 'Lift a weighted barbell off the ground to hip level.'
      });
      await txn.insert('exercise', {
        'name': 'Pull-Up',
        'muscle_group': 'Back',
        'description': 'Pull your body upward while hanging from a bar.'
      });
      await txn.insert('exercise', {
        'name': 'Bent Over Row',
        'muscle_group': 'Back',
        'description': 'Bend at the waist and pull weights up toward your torso.'
      });
      await txn.insert('exercise', {
        'name': 'Lat Pulldown',
        'muscle_group': 'Back',
        'description': 'Pull a weighted bar down while seated.'
      });
      
      // Leg exercises
      await txn.insert('exercise', {
        'name': 'Squat',
        'muscle_group': 'Legs',
        'description': 'Bend your knees and lower your body while keeping your back straight.'
      });
      await txn.insert('exercise', {
        'name': 'Leg Press',
        'muscle_group': 'Legs',
        'description': 'Push a weighted platform away from you with your legs.'
      });
      await txn.insert('exercise', {
        'name': 'Leg Extension',
        'muscle_group': 'Legs',
        'description': 'Extend your legs against resistance while seated.'
      });
      await txn.insert('exercise', {
        'name': 'Leg Curl',
        'muscle_group': 'Legs',
        'description': 'Curl your legs toward your backside against resistance.'
      });
      
      // Shoulder exercises
      await txn.insert('exercise', {
        'name': 'Shoulder Press',
        'muscle_group': 'Shoulders',
        'description': 'Push weights overhead from shoulder height.'
      });
      await txn.insert('exercise', {
        'name': 'Lateral Raise',
        'muscle_group': 'Shoulders',
        'description': 'Raise weights out to the sides until arms are parallel to the floor.'
      });
      await txn.insert('exercise', {
        'name': 'Front Raise',
        'muscle_group': 'Shoulders',
        'description': 'Raise weights in front of you until arms are parallel to the floor.'
      });
      
      // Biceps exercises
      await txn.insert('exercise', {
        'name': 'Bicep Curl',
        'muscle_group': 'Biceps',
        'description': 'Curl weights up toward your shoulders.'
      });
      await txn.insert('exercise', {
        'name': 'Hammer Curl',
        'muscle_group': 'Biceps',
        'description': 'Curl weights with palms facing inward.'
      });
      
      // Triceps exercises
      await txn.insert('exercise', {
        'name': 'Tricep Extension',
        'muscle_group': 'Triceps',
        'description': 'Extend your arms against resistance.'
      });
      await txn.insert('exercise', {
        'name': 'Tricep Dip',
        'muscle_group': 'Triceps',
        'description': 'Lower and raise your body using your arms while supported.'
      });
      
      // Abs exercises
      await txn.insert('exercise', {
        'name': 'Crunch',
        'muscle_group': 'Abs',
        'description': 'Raise your torso toward your knees while lying down.'
      });
      await txn.insert('exercise', {
        'name': 'Plank',
        'muscle_group': 'Abs',
        'description': 'Hold a position similar to a push-up, supporting your weight on forearms and toes.'
      });
      await txn.insert('exercise', {
        'name': 'Leg Raise',
        'muscle_group': 'Abs',
        'description': 'Raise your legs while lying on your back.'
      });
    });
  }
}

  // Additional CRUD methods for other tables as needed.
}
