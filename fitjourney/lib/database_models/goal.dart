class Goal {
  final int? goalId;
  final String userId;
  final String type; // 'ExerciseTarget' or 'WorkoutFrequency' or 'WeightTarget'
  final int? exerciseId;
  final double? targetValue;
  final DateTime startDate;
  final DateTime endDate;
  final bool achieved;
  final double currentProgress;
  final double? startingWeight; // Added for weight goals
  final DateTime? achievedDate; // Date when the goal was actually achieved

  Goal({
    this.goalId,
    required this.userId,
    required this.type,
    this.exerciseId,
    this.targetValue,
    required this.startDate,
    required this.endDate,
    this.achieved = false,
    this.currentProgress = 0,
    this.startingWeight,
    this.achievedDate,
  });

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      goalId: map['goal_id'],
      userId: map['user_id'],
      type: map['type'],
      exerciseId: map['exercise_id'],
      targetValue: map['target_value'] != null
          ? (map['target_value'] as num).toDouble()
          : null,
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      achieved: map['achieved'] == 1 || map['achieved'] == true,
      currentProgress: map['current_progress'] != null
          ? (map['current_progress'] as num).toDouble()
          : 0,
      startingWeight: map['starting_weight'] != null
          ? (map['starting_weight'] as num).toDouble()
          : null,
      achievedDate: map['achieved_date'] != null
          ? DateTime.parse(map['achieved_date'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goal_id': goalId,
      'user_id': userId,
      'type': type,
      'exercise_id': exerciseId,
      'target_value': targetValue,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'achieved': achieved ? 1 : 0,
      'current_progress': currentProgress,
      'starting_weight': startingWeight,
      'achieved_date': achievedDate?.toIso8601String(),
    };
  }
}
