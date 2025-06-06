import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/exercise.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/database_models/workout_exercise.dart';
import 'package:fitjourney/database_models/workout_set.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/services/streak_service.dart';
import 'package:fitjourney/utils/date_utils.dart';

/// Service for managing workouts, exercises, and fitness activity tracking
/// Provides methods for creating, retrieving, and analyzing workout data
class WorkoutService {
  // Singleton instance - now uses the constructor with dependencies
  static final WorkoutService instance = WorkoutService._internal(
    DatabaseHelper.instance,
    firebase_auth.FirebaseAuth.instance,
    StreakService.instance,
  );

  // Dependencies as properties
  final DatabaseHelper _dbHelper;
  final firebase_auth.FirebaseAuth _auth;
  final StreakService _streakService;

  // Public constructor for dependency injection (for testing)
  WorkoutService(
    this._dbHelper,
    this._auth,
    this._streakService,
  );

  // Private constructor used by the singleton
  WorkoutService._internal(
    this._dbHelper,
    this._auth,
    this._streakService,
  );

  /// Returns current user ID or throws exception if not logged in
  String _getCurrentUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  /// Loads predefined exercises into the database if they don't exist
  Future<void> initializeExercises() async {
    await _dbHelper.initializeExercisesIfNeeded();
  }

  /// Retrieves all unique muscle groups available in the exercise database
  Future<List<String>> getAllMuscleGroups() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        "SELECT DISTINCT muscle_group FROM exercise WHERE muscle_group != 'Abs' ORDER BY muscle_group ASC");

    return result.map((map) => map['muscle_group'] as String).toList();
  }

  /// Gets all exercises for a specific muscle group
  /// Filters out certain bodyweight exercises that are handled differently
  Future<List<Exercise>> getExercisesByMuscleGroup(String muscleGroup) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'exercise',
      where:
          "muscle_group = ? AND name != 'Push-Up' AND name != 'Pull-Up' AND name != 'Tricep Dip'",
      whereArgs: [muscleGroup],
      orderBy: 'name ASC',
    );

    return result.map((map) => Exercise.fromMap(map)).toList();
  }

  /// Retrieves all exercises in the database
  /// Filters out abs and certain bodyweight exercises
  Future<List<Exercise>> getAllExercises() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'exercise',
      where:
          "muscle_group != 'Abs' AND name != 'Push-Up' AND name != 'Pull-Up' AND name != 'Tricep Dip'",
      orderBy: 'name ASC',
    );

    return result.map((map) => Exercise.fromMap(map)).toList();
  }

  /// Gets an exercise by its ID
  Future<Exercise?> getExerciseById(int exerciseId) async {
    return await _dbHelper.getExerciseById(exerciseId);
  }

  /// Creates a new workout and updates the user's streak
  /// Returns the ID of the newly created workout
  Future<int> createWorkout({
    required DateTime date,
    int? duration,
    String? notes,
  }) async {
    final userId = _getCurrentUserId();

    final workout = Workout(
      userId: userId,
      date: date,
      duration: duration,
      notes: notes,
    );

    final workoutId = await _dbHelper.insertWorkout(workout);

    // Add this code to update the streak
    try {
      await _streakService.logWorkout(date);
      print('Streak updated after workout creation');
    } catch (e) {
      print('Error updating streak: $e');
      // Don't throw - we want the workout to be saved even if streak update fails
    }

    return workoutId;
  }

  /// Retrieves a workout by its ID
  Future<Workout?> getWorkoutById(int workoutId) async {
    return await _dbHelper.getWorkoutById(workoutId);
  }

  /// Updates an existing workout's details
  Future<void> updateWorkout(Workout workout) async {
    if (workout.workoutId == null) {
      throw Exception('Cannot update a workout without an ID');
    }
    await _dbHelper.updateWorkout(workout);
  }

  /// Adds an exercise to an existing workout
  /// Returns the ID of the newly created workout exercise
  Future<int> addExerciseToWorkout({
    required int workoutId,
    required int exerciseId,
  }) async {
    final workoutExercise = WorkoutExercise(
      workoutId: workoutId,
      exerciseId: exerciseId,
    );

    return await _dbHelper.insertWorkoutExercise(workoutExercise);
  }

  /// Adds a set to a workout exercise with weight and rep information
  /// Returns the ID of the newly created set
  Future<int> addSetToWorkoutExercise({
    required int workoutExerciseId,
    required int setNumber,
    required int? reps,
    required double? weight,
  }) async {
    final workoutSet = WorkoutSet(
      workoutExerciseId: workoutExerciseId,
      setNumber: setNumber,
      reps: reps,
      weight: weight,
    );

    return await _dbHelper.insertWorkoutSet(workoutSet);
  }

  /// Retrieves all workouts for the current user
  Future<List<Workout>> getUserWorkouts() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getWorkoutsForUser(userId);
  }

  /// Gets detailed workout information including all exercises and sets
  /// Returns comprehensive data structure with full workout details
  Future<Map<String, dynamic>> getWorkoutDetails(int workoutId) async {
    // Get the workout
    final workout = await _dbHelper.getWorkoutById(workoutId);
    if (workout == null) {
      throw Exception('Workout not found');
    }

    // Get the exercises for this workout
    final exercises = await _dbHelper.getExercisesForWorkout(workoutId);

    // Get sets for each exercise
    final exercisesWithSets = await Future.wait(exercises.map((exercise) async {
      final workoutExerciseId = exercise['workout_exercise_id'] as int;
      final sets = await _dbHelper.getSetsForWorkoutExercise(workoutExerciseId);

      return {
        ...exercise,
        'sets': sets,
      };
    }));

    // Return comprehensive workout data
    return {
      'workout': workout,
      'exercises': exercisesWithSets,
    };
  }

  /// Deletes a workout and all associated exercises and sets
  Future<void> deleteWorkout(int workoutId) async {
    await _dbHelper.deleteWorkout(workoutId);
  }

  /// Gets all workouts for a specific date
  /// Used for daily view and tracking daily activity
  Future<List<Workout>> getWorkoutsForDate(DateTime date) async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;

    // Use normalizeDate to ensure consistent date formats
    final normalizedDate = normaliseDate(date);

    final result = await db.rawQuery(
        "SELECT * FROM workout WHERE user_id = ? AND date LIKE ?",
        [userId, "$normalizedDate%"]);

    return result.map((map) => Workout.fromMap(map)).toList();
  }
}
