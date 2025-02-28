class WorkoutSet {
  final int? workoutSetId;
  final int workoutExerciseId;
  final int setNumber;
  final int? reps;
  final double? weight;

  WorkoutSet({
    this.workoutSetId,
    required this.workoutExerciseId,
    required this.setNumber,
    this.reps,
    this.weight,
  });

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      workoutSetId: map['workout_set_id'],
      workoutExerciseId: map['workout_exercise_id'],
      setNumber: map['set_number'],
      reps: map['reps'],
      weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workout_set_id': workoutSetId,
      'workout_exercise_id': workoutExerciseId,
      'set_number': setNumber,
      'reps': reps,
      'weight': weight,
    };
  }
}
