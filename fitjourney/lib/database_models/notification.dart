class NotificationModel {
  final int? notificationId;
  final String userId;
  final String type; // 'GoalProgress', 'NewStreak', or 'Milestone'
  final String message;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    this.notificationId,
    required this.userId,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      notificationId: map['notification_id'],
      userId: map['user_id'],
      type: map['type'],
      message: map['message'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['is_read'] == 1 || map['is_read'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'type': type,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }
}
