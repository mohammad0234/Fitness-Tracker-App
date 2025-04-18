// lib/models/progress_data.dart
class ProgressData {
  final List<Map<String, dynamic>> volumeData;
  final List<Map<String, dynamic>> muscleGroupData;
  final Map<String, dynamic>? frequencyData;
  final Map<String, dynamic> progressSummary;
  final List<Map<String, dynamic>> personalBests;

  ProgressData({
    required this.volumeData,
    required this.muscleGroupData,
    this.frequencyData,
    required this.progressSummary,
    required this.personalBests,
  });

  // Create an empty data instance for initial states
  factory ProgressData.empty() {
    return ProgressData(
      volumeData: [],
      muscleGroupData: [],
      progressSummary: {},
      personalBests: [],
    );
  }
}
