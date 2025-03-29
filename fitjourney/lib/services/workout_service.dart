import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/exercise.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/database_models/workout_exercise.dart';
import 'package:fitjourney/database_models/workout_set.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/services/goal_tracking_service.dart';
import 'package:fitjourney/services/goal_service.dart';

class WorkoutService {
  // Singleton instance
  static final WorkoutService instance = WorkoutService._internal();
  
  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Private constructor
  WorkoutService._internal();
  
  // Get the current user ID or throw an error if not logged in
  String _getCurrentUserId() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }
  
  // Initialize predefined exercises
  Future<void> initializeExercises() async {
    await _dbHelper.initializeExercisesIfNeeded();
  }
  
  // Get all available muscle groups
  Future<List<String>> getAllMuscleGroups() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT muscle_group FROM exercise ORDER BY muscle_group ASC'
    );
    
    return result.map((map) => map['muscle_group'] as String).toList();
  }
  
  // Get exercises by muscle group
  Future<List<Exercise>> getExercisesByMuscleGroup(String muscleGroup) async {
    return await _dbHelper.getExercisesByMuscleGroup(muscleGroup);
  }
  
  // Get all exercises
  Future<List<Exercise>> getAllExercises() async {
    return await _dbHelper.getAllExercises();
  }
  
  // Get an exercise by ID
Future<Exercise?> getExerciseById(int exerciseId) async {
  return await _dbHelper.getExerciseById(exerciseId);
}
  // Create a new workout
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
    
    return await _dbHelper.insertWorkout(workout);
  }

  // Get a workout by ID
  Future<Workout?> getWorkoutById(int workoutId) async {
    return await _dbHelper.getWorkoutById(workoutId);
}

  // Update an existing workout
  Future<void> updateWorkout(Workout workout) async {
    if (workout.workoutId == null) {
      throw Exception('Cannot update a workout without an ID');
  }
  await _dbHelper.updateWorkout(workout);
  }
  
  // Add an exercise to a workout
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
  
  // Add a set to a workout exercise
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
  
  // Create a complete workout with exercises and sets
  Future<int> logCompleteWorkout({
    required DateTime date,
    int? duration,
    String? notes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final userId = _getCurrentUserId();
    
    return await _dbHelper.saveCompleteWorkout(
      userId: userId,
      date: date,
      duration: duration,
      notes: notes,
      exercises: exercises,
    );
  }
  
  // Get all workouts for the current user
  Future<List<Workout>> getUserWorkouts() async {
    final userId = _getCurrentUserId();
    return await _dbHelper.getWorkoutsForUser(userId);
  }
  
  // Get detailed workout information
  Future<Map<String, dynamic>> getWorkoutDetails(int workoutId) async {
    // Get the workout
    final workout = await _dbHelper.getWorkoutById(workoutId);
    if (workout == null) {
      throw Exception('Workout not found');
    }
    
    // Get the exercises for this workout
    final exercises = await _dbHelper.getExercisesForWorkout(workoutId);
    
    // Get sets for each exercise
    final exercisesWithSets = await Future.wait(
      exercises.map((exercise) async {
        final workoutExerciseId = exercise['workout_exercise_id'] as int;
        final sets = await _dbHelper.getSetsForWorkoutExercise(workoutExerciseId);
        
        return {
          ...exercise,
          'sets': sets,
        };
      })
    );
    
    // Return comprehensive workout data
    return {
      'workout': workout,
      'exercises': exercisesWithSets,
    };
  }
  
  // Calculate total volume for a workout (weight * reps)
  Future<double> calculateWorkoutVolume(int workoutId) async {
    final details = await getWorkoutDetails(workoutId);
    double totalVolume = 0;
    
    for (var exercise in details['exercises']) {
      for (var set in exercise['sets']) {
        final reps = set.reps ?? 0;
        final weight = set.weight ?? 0;
        totalVolume += reps * weight;
      }
    }
    
    return totalVolume;
  }
  
  // Get personal best for an exercise
  Future<double?> getPersonalBestWeight(int exerciseId) async {
    final userId = _getCurrentUserId();
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT MAX(ws.weight) as max_weight
      FROM workout_set ws
      JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
      JOIN workout w ON we.workout_id = w.workout_id
      WHERE w.user_id = ? AND we.exercise_id = ?
    ''', [userId, exerciseId]);
    
    if (result.isNotEmpty && result.first['max_weight'] != null) {
      return result.first['max_weight'] as double;
    }
    
    return null;
  }
  
  // Delete a workout and all associated data
  Future<void> deleteWorkout(int workoutId) async {
    await _dbHelper.deleteWorkout(workoutId);
  }

// Check and update personal best for an exercise
// Modified version that doesn't use personal_best table
Future<bool> checkAndUpdatePersonalBest(int exerciseId, double weight) async {
  final userId = _getCurrentUserId();
  
  // Get current max weight from workout data
  final db = await _dbHelper.database;
  final maxWeightResult = await db.rawQuery('''
    SELECT MAX(ws.weight) as max_weight
    FROM workout_set ws
    JOIN workout_exercise we ON ws.workout_exercise_id = we.workout_exercise_id
    JOIN workout w ON we.workout_id = w.workout_id
    WHERE we.exercise_id = ? AND w.user_id = ? AND ws.weight IS NOT NULL
  ''', [exerciseId, userId]);
  
  final double? currentMax = maxWeightResult.isNotEmpty && maxWeightResult.first['max_weight'] != null
      ? (maxWeightResult.first['max_weight'] as num).toDouble()
      : null;
  
  // Check if this is a new personal best
  bool isNewPersonalBest = currentMax == null || weight > currentMax;
  
  if (isNewPersonalBest) {
    // Create milestone for the new personal best
    await db.insert(
      'milestone',
      {
        'user_id': userId,
        'type': 'PersonalBest',
        'exercise_id': exerciseId,
        'value': weight,
        'date': DateTime.now().toIso8601String(),
      },
    );
    
    // Update any related goals
    await GoalTrackingService.instance.updateGoalsAfterPersonalBest(exerciseId, weight);
  }
  
  return isNewPersonalBest;
}

}
