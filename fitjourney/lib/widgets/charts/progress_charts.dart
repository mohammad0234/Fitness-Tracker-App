/**
 * ProgressCharts - A utility class that manages the creation and data fetching for various fitness tracking charts.
 * 
 * Features:
 * - Centralized chart creation with error handling
 * - Consistent error state presentation
 * - Automated data fetching from ProgressService
 * - Support for multiple chart types:
 *   - Muscle group distribution
 *   - Exercise-specific progress
 */

import 'package:flutter/material.dart';
import 'package:fitjourney/services/progress_service.dart';
import 'package:fitjourney/widgets/charts/muscle_group_pie_chart.dart';
import 'package:fitjourney/widgets/charts/exercise_progress_chart.dart';

class ProgressCharts {
  static final ProgressService _progressService = ProgressService.instance;

  /**
   * Creates a pie chart showing the distribution of exercises across muscle groups.
   * Automatically fetches and processes muscle group data for the specified period.
   * 
   * @param timeRange The time period to analyze
   * @returns A Widget containing either the pie chart or an error state
   */
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

  /**
   * Creates a progress chart for a specific exercise.
   * Shows weight progression and performance metrics over time.
   * 
   * @param exerciseId The unique identifier of the exercise to analyze
   * @returns A Widget containing either the progress chart or an error state
   */
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

  /**
   * Creates a standardized error display widget.
   * Used when chart data loading or processing fails.
   * 
   * Features:
   * - Consistent error styling across all charts
   * - Clear error message presentation
   * - Visual error indicator
   * - Contained within a bounded space
   * 
   * @param errorMessage The specific error message to display
   * @returns A Widget containing the formatted error display
   */
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
