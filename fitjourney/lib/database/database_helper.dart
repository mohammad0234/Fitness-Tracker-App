import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  // Access the database via this getter
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Initialize or open the database
  Future<Database> _initDB() async {
    // Get the application documents directory
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    // Name the database file 'myfitness.db'
    final path = join(documentsDirectory.path, 'myfitness.db');

    // Open the database
    return await openDatabase(
      path,
      version: 1, // Increment if you add migrations later
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade, // If you need migrations
    );
  }

  /// Enable foreign key support
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create all tables in onCreate
  Future<void> _onCreate(Database db, int version) async {
    // USERS
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

    // USER_METRICS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_metrics (
        metric_id   INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT NOT NULL,
        weight_kg   REAL CHECK (weight_kg > 0),
        measured_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
    ''');

    // EXERCISE
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise (
        exercise_id  INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT NOT NULL,
        muscle_group TEXT,
        description  TEXT
      );
    ''');

    // WORKOUT
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

    // WORKOUT_EXERCISE
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_exercise (
        workout_exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id          INTEGER NOT NULL,
        exercise_id         INTEGER NOT NULL,
        FOREIGN KEY (workout_id)  REFERENCES workout(workout_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id)
      );
    ''');

    // WORKOUT_SET
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

    // GOAL
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
        FOREIGN KEY (user_id)     REFERENCES users(user_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id),
        CHECK (
          (type = 'ExerciseTarget'    AND exercise_id IS NOT NULL) OR
          (type = 'WorkoutFrequency'  AND exercise_id IS NULL)
        )
      );
    ''');

    // DAILY_LOG
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

    // STREAK
    await db.execute('''
      CREATE TABLE IF NOT EXISTS streak (
        user_id            TEXT PRIMARY KEY,
        current_streak     INT DEFAULT 0,
        longest_streak     INT DEFAULT 0,
        last_activity_date DATE,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
    ''');

    // NOTIFICATION
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

    // MILESTONE
    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestone (
        milestone_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id      TEXT NOT NULL,
        type         TEXT NOT NULL CHECK (type IN ('PersonalBest','LongestStreak','GoalAchieved')),
        exercise_id  INTEGER,
        value        REAL,
        date         DATE NOT NULL,
        FOREIGN KEY (user_id)     REFERENCES users(user_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id)
      );
    ''');

    // PERSONAL_BEST
    await db.execute('''
      CREATE TABLE IF NOT EXISTS personal_best (
        personal_best_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          TEXT NOT NULL,
        exercise_id      INTEGER NOT NULL,
        max_weight       REAL,
        date             DATE NOT NULL,
        FOREIGN KEY (user_id)     REFERENCES users(user_id),
        FOREIGN KEY (exercise_id) REFERENCES exercise(exercise_id)
      );
    ''');
  }

  // If you need to handle database migrations (changing schemas, etc.) in the future,
  // implement a method like this:
  // Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < newVersion) {
  //     // e.g., add a column, create new tables, etc.
  //   }
  // }

  /// Example method to drop all tables for testing or resetting 
  /*
  Future<void> dropAllTables() async {
    final db = await database;
    // Make sure foreign_keys are off if you're dropping everything
    await db.execute('PRAGMA foreign_keys = OFF');

    await db.execute('DROP TABLE IF EXISTS personal_best');
    await db.execute('DROP TABLE IF EXISTS milestone');
    await db.execute('DROP TABLE IF EXISTS notification');
    await db.execute('DROP TABLE IF EXISTS streak');
    await db.execute('DROP TABLE IF EXISTS daily_log');
    await db.execute('DROP TABLE IF EXISTS goal');
    await db.execute('DROP TABLE IF EXISTS workout_set');
    await db.execute('DROP TABLE IF EXISTS workout_exercise');
    await db.execute('DROP TABLE IF EXISTS workout');
    await db.execute('DROP TABLE IF EXISTS exercise');
    await db.execute('DROP TABLE IF EXISTS user_metrics');
    await db.execute('DROP TABLE IF EXISTS users');

    // Re-enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }
  */
}
