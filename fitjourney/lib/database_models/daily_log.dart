// lib/database_models/daily_log.dart

import 'package:fitjourney/utils/date_utils.dart';

class DailyLog {
  final int? dailyLogId;
  final String userId;
  final DateTime date;
  final String activityType; // 'workout' or 'rest'
  final String? notes; // Optional notes about the daily activity

  DailyLog({
    this.dailyLogId,
    required this.userId,
    required this.date,
    required this.activityType,
    this.notes,
  });

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      dailyLogId: map['daily_log_id'],
      userId: map['user_id'],
      date: DateTime.parse(map['date']),
      activityType: map['activity_type'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'daily_log_id': dailyLogId,
      'user_id': userId,
      'date': normaliseDate(date),
      'activity_type': activityType,
      'notes': notes,
    };
  }
}
