class Milestone {
  final int? milestoneId;
  final String userId;
  final String type; // 'PersonalBest', 'LongestStreak', or 'GoalAchieved'
  final int? exerciseId;
  final double? value;
  final DateTime date;

  Milestone({
    this.milestoneId,
    required this.userId,
    required this.type,
    this.exerciseId,
    this.value,
    required this.date,
  });

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      milestoneId: map['milestone_id'],
      userId: map['user_id'],
      type: map['type'],
      exerciseId: map['exercise_id'],
      value: map['value'] != null ? (map['value'] as num).toDouble() : null,
      date: DateTime.parse(map['date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'milestone_id': milestoneId,
      'user_id': userId,
      'type': type,
      'exercise_id': exerciseId,
      'value': value,
      'date': date.toIso8601String(),
    };
  }
}
