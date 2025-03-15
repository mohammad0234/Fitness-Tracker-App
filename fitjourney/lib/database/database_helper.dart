import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Import local user model
import 'package:fitjourney/database_models/user.dart';

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

  // Additional CRUD methods for other tables as needed.
}
