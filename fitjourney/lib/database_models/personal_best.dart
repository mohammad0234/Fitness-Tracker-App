class PersonalBest {
  final int? personalBestId;
  final String userId;
  final int exerciseId;
  final double? maxWeight;
  final DateTime date;

  PersonalBest({
    this.personalBestId,
    required this.userId,
    required this.exerciseId,
    this.maxWeight,
    required this.date,
  });

  factory PersonalBest.fromMap(Map<String, dynamic> map) {
    return PersonalBest(
      personalBestId: map['personal_best_id'],
      userId: map['user_id'],
      exerciseId: map['exercise_id'],
      maxWeight: map['max_weight'] != null ? (map['max_weight'] as num).toDouble() : null,
      date: DateTime.parse(map['date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'personal_best_id': personalBestId,
      'user_id': userId,
      'exercise_id': exerciseId,
      'max_weight': maxWeight,
      'date': date.toIso8601String(),
    };
  }
}
