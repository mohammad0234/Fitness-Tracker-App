class Workout {
  final int? workoutId;
  final String userId;
  final DateTime date;
  final int? duration;
  final String? notes;

  Workout({
    this.workoutId,
    required this.userId,
    required this.date,
    this.duration,
    this.notes,
  });

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      workoutId: map['workout_id'],
      userId: map['user_id'],
      date: DateTime.parse(map['date']),
      duration: map['duration'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workout_id': workoutId,
      'user_id': userId,
      'date': date.toIso8601String(),
      'duration': duration,
      'notes': notes,
    };
  }
}
