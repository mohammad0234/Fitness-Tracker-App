// lib/models/progress_data.dart
class ProgressData {
  final List<Map<String, dynamic>> muscleGroupData;
  final Map<String, dynamic> progressSummary;
  final List<Map<String, dynamic>> personalBests;
  final List<Map<String, dynamic>> exerciseVolumeData;

  ProgressData({
    required this.muscleGroupData,
    required this.progressSummary,
    required this.personalBests,
    this.exerciseVolumeData = const [],
  });

  /// Creates an empty ProgressData object
  factory ProgressData.empty() => ProgressData(
        muscleGroupData: [],
        progressSummary: {},
        personalBests: [],
        exerciseVolumeData: [],
      );
}
