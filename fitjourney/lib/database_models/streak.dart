class Streak {
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;

  Streak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
  });

  factory Streak.fromMap(Map<String, dynamic> map) {
    return Streak(
      userId: map['user_id'],
      currentStreak: map['current_streak'] ?? 0,
      longestStreak: map['longest_streak'] ?? 0,
      lastActivityDate: map['last_activity_date'] != null ? DateTime.parse(map['last_activity_date']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date': lastActivityDate?.toIso8601String(),
    };
  }
}
