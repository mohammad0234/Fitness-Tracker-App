class DailyLog {
  final int? dailyLogId;
  final String userId;
  final DateTime date;
  final String activityType; // 'workout' or 'rest'

  DailyLog({
    this.dailyLogId,
    required this.userId,
    required this.date,
    required this.activityType,
  });

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      dailyLogId: map['daily_log_id'],
      userId: map['user_id'],
      date: DateTime.parse(map['date']),
      activityType: map['activity_type'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'daily_log_id': dailyLogId,
      'user_id': userId,
      'date': date.toIso8601String(),
      'activity_type': activityType,
    };
  }
}
