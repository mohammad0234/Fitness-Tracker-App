class UserMetrics {
  final int? metricId;
  final String userId;
  final double weightKg;
  final DateTime measuredAt;

  UserMetrics({
    this.metricId,
    required this.userId,
    required this.weightKg,
    required this.measuredAt,
  });

  factory UserMetrics.fromMap(Map<String, dynamic> map) {
    return UserMetrics(
      metricId: map['metric_id'],
      userId: map['user_id'],
      weightKg: (map['weight_kg'] as num).toDouble(),
      measuredAt: DateTime.parse(map['measured_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'metric_id': metricId,
      'user_id': userId,
      'weight_kg': weightKg,
      'measured_at': measuredAt.toIso8601String(),
    };
  }
}
