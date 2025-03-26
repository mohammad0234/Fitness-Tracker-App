import 'package:flutter/material.dart';
import 'package:fitjourney/services/progress_service.dart';
import 'package:fitjourney/widgets/charts/workout_volume_chart.dart';
import 'package:fitjourney/widgets/charts/muscle_group_pie_chart.dart';
import 'package:fitjourney/widgets/charts/exercise_progress_chart.dart';
import 'package:fitjourney/widgets/charts/workout_frequency_chart.dart';

class ProgressCharts {
  static final ProgressService _progressService = ProgressService.instance;

  /// Creates a workout volume chart for the given time period
  static Future<Widget> buildWorkoutVolumeChart({
    required String timeRange,
  }) async {
    try {
      // Get date range for the selected period
      final dateRange = _progressService.getDateRangeForPeriod(timeRange);
      
      // Fetch data
      final volumeData = await _progressService.getWorkoutVolumeData(
        startDate: dateRange['startDate']!,
        endDate: dateRange['endDate']!,
      );
      
      // Return chart widget
      return WorkoutVolumeChart(
        volumeData: volumeData,
        timeRange: timeRange,
      );
    } catch (e) {
      return _buildErrorWidget('Error loading workout volume data: $e');
    }
  }

  /// Creates a muscle group distribution pie chart for the given time period
  static Future<Widget> buildMuscleGroupChart({
    required String timeRange,
  }) async {
    try {
      // Get date range for the selected period
      final dateRange = _progressService.getDateRangeForPeriod(timeRange);
      
      // Fetch data
      final muscleGroupData = await _progressService.getMuscleGroupDistribution(
        startDate: dateRange['startDate']!,
        endDate: dateRange['endDate']!,
      );
      
      // Return chart widget
      return MuscleGroupPieChart(
        muscleGroupData: muscleGroupData,
      );
    } catch (e) {
      return _buildErrorWidget('Error loading muscle group data: $e');
    }
  }

  /// Creates an exercise progress chart for the specified exercise
  static Future<Widget> buildExerciseProgressChart({
    required int exerciseId,
  }) async {
    try {
      // Fetch data
      final exerciseData = await _progressService.getExerciseProgressData(
        exerciseId,
      );
      
      // Return chart widget
      return ExerciseProgressChart(
        exerciseData: exerciseData,
      );
    } catch (e) {
      return _buildErrorWidget('Error loading exercise progress data: $e');
    }
  }

  /// Creates a workout frequency chart for the given time period
  static Future<Widget> buildWorkoutFrequencyChart({
    required String timeRange,
  }) async {
    try {
      // Get date range for the selected period
      final dateRange = _progressService.getDateRangeForPeriod(timeRange);
      
      // Fetch data
      final frequencyData = await _progressService.getWorkoutFrequencyData(
        startDate: dateRange['startDate']!,
        endDate: dateRange['endDate']!,
      );
      
      // Return chart widget
      return WorkoutFrequencyChart(
        frequencyData: frequencyData,
      );
    } catch (e) {
      return _buildErrorWidget('Error loading workout frequency data: $e');
    }
  }

  /// Helper method to build an error widget when data loading fails
  static Widget _buildErrorWidget(String errorMessage) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade400,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}