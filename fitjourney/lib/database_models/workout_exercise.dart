class WorkoutExercise {
  final int? workoutExerciseId;
  final int workoutId;
  final int exerciseId;

  WorkoutExercise({
    this.workoutExerciseId,
    required this.workoutId,
    required this.exerciseId,
  });

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      workoutExerciseId: map['workout_exercise_id'],
      workoutId: map['workout_id'],
      exerciseId: map['exercise_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workout_exercise_id': workoutExerciseId,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
    };
  }
}
