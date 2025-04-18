// lib/screens/workout_comparison_screen.dart
import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:intl/intl.dart';

class WorkoutComparisonScreen extends StatefulWidget {
  final int firstWorkoutId;
  final int secondWorkoutId;

  const WorkoutComparisonScreen({
    Key? key,
    required this.firstWorkoutId,
    required this.secondWorkoutId,
  }) : super(key: key);

  @override
  State<WorkoutComparisonScreen> createState() =>
      _WorkoutComparisonScreenState();
}

class _WorkoutComparisonScreenState extends State<WorkoutComparisonScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Workout data
  Workout? _firstWorkout;
  Workout? _secondWorkout;

  // Comparison data
  Map<String, dynamic> _comparisonData = {};

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
  }

  Future<void> _loadWorkoutData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load both workouts in parallel
      final results = await Future.wait([
        _workoutService.getWorkoutDetails(widget.firstWorkoutId),
        _workoutService.getWorkoutDetails(widget.secondWorkoutId),
      ]);

      final firstWorkoutDetails = results[0];
      final secondWorkoutDetails = results[1];

      // Extract workout and exercises
      final firstWorkout = firstWorkoutDetails['workout'] as Workout;
      final secondWorkout = secondWorkoutDetails['workout'] as Workout;

      final firstWorkoutExercises =
          firstWorkoutDetails['exercises'] as List<Map<String, dynamic>>;
      final secondWorkoutExercises =
          secondWorkoutDetails['exercises'] as List<Map<String, dynamic>>;

      // Generate comparison data
      final comparisonData = _generateComparisonData(firstWorkout,
          secondWorkout, firstWorkoutExercises, secondWorkoutExercises);

      setState(() {
        _firstWorkout = firstWorkout;
        _secondWorkout = secondWorkout;
        _comparisonData = comparisonData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workout data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Map<String, dynamic> _generateComparisonData(
    Workout firstWorkout,
    Workout secondWorkout,
    List<Map<String, dynamic>> firstWorkoutExercises,
    List<Map<String, dynamic>> secondWorkoutExercises,
  ) {
    // Calculate total volumes
    double firstTotalVolume = 0;
    double secondTotalVolume = 0;

    // Calculate total volume for first workout
    for (var exercise in firstWorkoutExercises) {
      final sets = exercise['sets'] as List;
      double exerciseVolume = 0;
      for (var set in sets) {
        final weight = set.weight ?? 0.0;
        final reps = (set.reps ?? 0) as int;
        exerciseVolume += weight * reps;
      }
      firstTotalVolume += exerciseVolume;

      // Add volume to exercise info for reference
      exercise['total_volume'] = exerciseVolume;
    }

    // Calculate total volume for second workout
    for (var exercise in secondWorkoutExercises) {
      final sets = exercise['sets'] as List;
      double exerciseVolume = 0;
      for (var set in sets) {
        final weight = set.weight ?? 0.0;
        final reps = (set.reps ?? 0) as int;
        exerciseVolume += weight * reps;
      }
      secondTotalVolume += exerciseVolume;

      // Add volume to exercise info for reference
      exercise['total_volume'] = exerciseVolume;
    }

    // Calculate volume difference
    final volumeDifference = secondTotalVolume - firstTotalVolume;
    final volumePercentChange = firstTotalVolume > 0
        ? (volumeDifference / firstTotalVolume) * 100
        : 0.0;

    // Identify matching exercises
    List<Map<String, dynamic>> matchingExercises = [];
    List<Map<String, dynamic>> uniqueToFirst = [];
    List<Map<String, dynamic>> uniqueToSecond = [];

    // Create a map of exercise IDs for the second workout for quick lookup
    final secondWorkoutExerciseIds = <int, Map<String, dynamic>>{};
    for (var exercise in secondWorkoutExercises) {
      final exerciseId = exercise['exercise_id'] as int;
      secondWorkoutExerciseIds[exerciseId] = exercise;
    }

    // Compare exercises
    for (var firstExercise in firstWorkoutExercises) {
      final exerciseId = firstExercise['exercise_id'] as int;

      if (secondWorkoutExerciseIds.containsKey(exerciseId)) {
        // This is a matching exercise
        final secondExercise = secondWorkoutExerciseIds[exerciseId]!;

        // Calculate max weight and volume for first exercise
        double firstMaxWeight = 0;
        double firstTotalVolume = 0;
        int firstTotalReps = 0;
        final firstSets = firstExercise['sets'] as List;

        for (var set in firstSets) {
          final weight = set.weight ?? 0.0;
          final reps = (set.reps ?? 0) as int;
          if (weight > firstMaxWeight) {
            firstMaxWeight = weight;
          }
          firstTotalVolume += weight * reps;
          firstTotalReps += reps;
        }

        // Calculate max weight and volume for second exercise
        double secondMaxWeight = 0;
        double secondTotalVolume = 0;
        int secondTotalReps = 0;
        final secondSets = secondExercise['sets'] as List;

        for (var set in secondSets) {
          final weight = set.weight ?? 0.0;
          final reps = (set.reps ?? 0) as int;
          if (weight > secondMaxWeight) {
            secondMaxWeight = weight;
          }
          secondTotalVolume += weight * reps;
          secondTotalReps += reps;
        }

        // Calculate differences
        final weightDifference = secondMaxWeight - firstMaxWeight;
        final weightPercentChange = firstMaxWeight > 0
            ? (weightDifference / firstMaxWeight) * 100
            : 0.0;

        final volumeDifference = secondTotalVolume - firstTotalVolume;
        final volumePercentChange = firstTotalVolume > 0
            ? (volumeDifference / firstTotalVolume) * 100
            : 0.0;

        // Generate explanation for unusual scenarios
        String? explanation;

        // Case: Volume improved significantly despite lower or same max weight
        if (volumePercentChange > 15 && weightPercentChange <= 0) {
          final repDifference = secondTotalReps - firstTotalReps;
          explanation =
              'Volume increased by ${volumePercentChange.toStringAsFixed(1)}% despite ${weightDifference < 0 ? 'lower' : 'same'} max weight. This is due to ${repDifference > 0 ? 'more reps' : 'more total sets'}.';
        }
        // Case: Volume decreased despite higher max weight
        else if (volumePercentChange < -15 && weightPercentChange > 0) {
          final repDifference = secondTotalReps - firstTotalReps;
          explanation =
              'Volume decreased by ${volumePercentChange.abs().toStringAsFixed(1)}% despite higher max weight. This is due to ${repDifference < 0 ? 'fewer total reps' : 'fewer sets'}.';
        }
        // Case: Large volume increase
        else if (volumePercentChange > 50) {
          explanation =
              'Significant volume increase: ${volumePercentChange.toStringAsFixed(1)}%. This shows major progression in work capacity.';
        }

        matchingExercises.add({
          'name': firstExercise['name'],
          'muscleGroup': firstExercise['muscle_group'],
          'firstMaxWeight': firstMaxWeight,
          'secondMaxWeight': secondMaxWeight,
          'weightDifference': weightDifference,
          'weightPercentChange': weightPercentChange,
          'firstTotalVolume': firstTotalVolume,
          'secondTotalVolume': secondTotalVolume,
          'volumeDifference': volumeDifference,
          'volumePercentChange': volumePercentChange,
          'firstSets': firstSets.length,
          'secondSets': secondSets.length,
          'firstTotalReps': firstTotalReps,
          'secondTotalReps': secondTotalReps,
          'explanation': explanation,
        });

        // Remove from the map so we don't process it again
        secondWorkoutExerciseIds.remove(exerciseId);
      } else {
        // This exercise is unique to the first workout
        uniqueToFirst.add(firstExercise);
      }
    }

    // Any remaining exercises in the map are unique to the second workout
    for (var exerciseId in secondWorkoutExerciseIds.keys) {
      uniqueToSecond.add(secondWorkoutExerciseIds[exerciseId]!);
    }

    // Sort matching exercises by biggest improvement or decline
    matchingExercises.sort((a, b) => (b['weightPercentChange'] as double)
        .abs()
        .compareTo((a['weightPercentChange'] as double).abs()));

    // Generate overall summary text
    String? summaryText;

    if (matchingExercises.isNotEmpty) {
      if (volumePercentChange > 30 &&
          matchingExercises
              .any((e) => e['weightPercentChange'] as double > 0)) {
        summaryText =
            'Great progress! Both volume and strength have improved significantly.';
      } else if (volumePercentChange < -20) {
        summaryText =
            'Volume has decreased. This might be due to fewer sets/reps or lower weights.';
      } else if (matchingExercises
          .every((e) => (e['weightPercentChange'] as double) < 0)) {
        summaryText =
            'Weights have decreased across all exercises. This could be due to fatigue or technique focus.';
      }
    }

    // Determine if there are significant data inconsistencies
    bool hasInconsistentData = matchingExercises.any((e) =>
        ((e['weightPercentChange'] as double) < -10 &&
            (e['volumePercentChange'] as double) > 50) ||
        ((e['weightPercentChange'] as double) > 10 &&
            (e['volumePercentChange'] as double) < -50));

    return {
      'firstTotalVolume': firstTotalVolume,
      'secondTotalVolume': secondTotalVolume,
      'volumeDifference': volumeDifference,
      'volumePercentChange': volumePercentChange,
      'matchingExercises': matchingExercises,
      'uniqueToFirst': uniqueToFirst,
      'uniqueToSecond': uniqueToSecond,
      'firstExerciseCount': firstWorkoutExercises.length,
      'secondExerciseCount': secondWorkoutExercises.length,
      'isImproved': volumePercentChange > 0,
      'summaryText': summaryText,
      'hasInconsistentData': hasInconsistentData,
      'daysBetween': secondWorkout.date.difference(firstWorkout.date).inDays,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Comparison'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkoutData,
            tooltip: 'Refresh comparison',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorState()
              : _buildComparisonContent(),
    );
  }

  Widget _buildComparisonContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          _buildSummaryCard(),

          // Matching exercises section
          if (_comparisonData['matchingExercises'].isNotEmpty) ...[
            _buildSectionHeader(
              'Same Exercises in Both Workouts',
              '${_comparisonData['matchingExercises'].length}',
              Icons.compare_arrows,
              Colors.blue.shade700,
            ),
            ..._buildMatchingExercisesCards(),
          ],

          // Unique exercises section
          if (_comparisonData['uniqueToFirst'].isNotEmpty ||
              _comparisonData['uniqueToSecond'].isNotEmpty) ...[
            _buildSectionHeader(
              'Exercises Found in Only One Workout',
              '',
              Icons.fitness_center,
              Colors.purple.shade700,
            ),
            _buildUniqueExercisesSection(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, String count, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (count.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final firstDate = DateFormat('MMM d, yyyy').format(_firstWorkout!.date);
    final secondDate = DateFormat('MMM d, yyyy').format(_secondWorkout!.date);

    final firstVolume = _comparisonData['firstTotalVolume'] as double;
    final secondVolume = _comparisonData['secondTotalVolume'] as double;
    final volumeChange = _comparisonData['volumePercentChange'] as double;
    final isImproved = _comparisonData['isImproved'] as bool;

    final daysBetween = _comparisonData['daysBetween'] as int;
    final summaryText = _comparisonData['summaryText'] as String?;
    final hasInconsistentData =
        _comparisonData['hasInconsistentData'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with improvement indicator
            Row(
              children: [
                Icon(
                  isImproved ? Icons.trending_up : Icons.trending_down,
                  color: isImproved ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isImproved ? 'Overall Improvement' : 'Overall Decline',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Summary text (if available)
            if (summaryText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.summarize,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        summaryText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Data inconsistency warning
            if (hasInconsistentData) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Some data shows unusual patterns (e.g., much higher volume despite lower weights). This could be due to different workout approaches or data entry differences.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Timeline visualization
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'First Workout',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        firstDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 24,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: Colors.grey.shade300,
                          ),
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Second Workout',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        secondDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Days between indicator
            Center(
              child: Text(
                daysBetween > 0
                    ? '$daysBetween ${daysBetween == 1 ? 'day' : 'days'} between workouts'
                    : 'Same day workouts',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Workout details side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildWorkoutDetailColumn(
                    'First Workout',
                    _firstWorkout!.duration ?? 0,
                    _comparisonData['firstExerciseCount'],
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildWorkoutDetailColumn(
                    'Second Workout',
                    _secondWorkout!.duration ?? 0,
                    _comparisonData['secondExerciseCount'],
                    Colors.green,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Volume explanation
            Row(
              children: [
                Text(
                  'Total Volume Comparison',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Volume = Weight × Reps summed across all sets',
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Volume represents the total weight lifted (weight × reps for all sets)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),

            // Volume comparison
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'First Workout',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${firstVolume.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Second Workout',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${secondVolume.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isImproved
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: isImproved ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${volumeChange.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isImproved ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutDetailColumn(
      String title, int duration, int exerciseCount, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Text(
                  '$duration minutes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.fitness_center,
                    size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Text(
                  '$exerciseCount exercises',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMatchingExercisesCards() {
    final matchingExercises =
        _comparisonData['matchingExercises'] as List<Map<String, dynamic>>;

    return matchingExercises
        .map((exercise) => _buildExerciseComparisonCard(exercise))
        .toList();
  }

  Widget _buildExerciseComparisonCard(Map<String, dynamic> exercise) {
    final name = exercise['name'] as String;
    final muscleGroup = exercise['muscleGroup'] as String;

    final firstMaxWeight = exercise['firstMaxWeight'] as double;
    final secondMaxWeight = exercise['secondMaxWeight'] as double;
    final weightDifference = exercise['weightDifference'] as double;
    final weightPercentChange = exercise['weightPercentChange'] as double;

    final firstTotalVolume = exercise['firstTotalVolume'] as double;
    final secondTotalVolume = exercise['secondTotalVolume'] as double;
    final volumePercentChange = exercise['volumePercentChange'] as double;

    final firstSets = exercise['firstSets'] as int;
    final secondSets = exercise['secondSets'] as int;

    final firstTotalReps = exercise['firstTotalReps'] as int;
    final secondTotalReps = exercise['secondTotalReps'] as int;

    final explanation = exercise['explanation'] as String?;

    final isWeightImproved = weightDifference > 0;
    final isVolumeImproved = volumePercentChange > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header with name and muscle group
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        muscleGroup,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWeightImproved
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWeightImproved
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: isWeightImproved
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${weightPercentChange.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isWeightImproved
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Side by side comparison with divider
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Header row with First/Second workout
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'First Workout',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Second Workout',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Max weight comparison
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Max Weight:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${firstMaxWeight.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward,
                            color: isWeightImproved
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${secondMaxWeight.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: isWeightImproved
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    isWeightImproved
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 10,
                                    color: isWeightImproved
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Total reps comparison
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Total Reps:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '$firstTotalReps',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward,
                            color: secondTotalReps >= firstTotalReps
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$secondTotalReps',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (secondTotalReps != firstTotalReps)
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: secondTotalReps > firstTotalReps
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      secondTotalReps > firstTotalReps
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 10,
                                      color: secondTotalReps > firstTotalReps
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Volume comparison
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Row(
                          children: [
                            Text(
                              'Volume:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Tooltip(
                              message: 'Volume = Weight × Reps across all sets',
                              child: Icon(
                                Icons.info_outline,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${firstTotalVolume.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward,
                            color: isVolumeImproved
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${secondTotalVolume.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: isVolumeImproved
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    isVolumeImproved
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 10,
                                    color: isVolumeImproved
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sets comparison
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Sets:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '$firstSets',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward,
                            color: secondSets >= firstSets
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$secondSets',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (secondSets != firstSets)
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: secondSets > firstSets
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      secondSets > firstSets
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 10,
                                      color: secondSets > firstSets
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Explanation text if needed
            if (explanation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        explanation,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Volume calculation explanation
            if (volumePercentChange.abs() > 30 &&
                weightPercentChange.abs() < 10) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 14,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Volume = Weight × Reps for all sets. ${secondTotalReps > firstTotalReps ? 'More' : 'Fewer'} total reps explains the ${isVolumeImproved ? 'increase' : 'decrease'} in volume.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUniqueExercisesSection() {
    final uniqueToFirst = _comparisonData['uniqueToFirst'] as List;
    final uniqueToSecond = _comparisonData['uniqueToSecond'] as List;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Help text explaining what unique exercises means
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Colors.grey.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These are exercises that appear in only one of the two workouts being compared.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (uniqueToFirst.isNotEmpty) ...[
              Text(
                'Only in First Workout (${uniqueToFirst.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...uniqueToFirst.map((exercise) => _buildUniqueExerciseItem(
                    exercise['name'] as String,
                    exercise['muscle_group'] as String,
                    true,
                  )),
            ],

            if (uniqueToFirst.isNotEmpty && uniqueToSecond.isNotEmpty)
              const Divider(height: 24),

            if (uniqueToSecond.isNotEmpty) ...[
              Text(
                'Only in Second Workout (${uniqueToSecond.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...uniqueToSecond.map((exercise) => _buildUniqueExerciseItem(
                    exercise['name'] as String,
                    exercise['muscle_group'] as String,
                    false,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUniqueExerciseItem(
      String name, String muscleGroup, bool isFirst) {
    final color = isFirst ? Colors.blue : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.fitness_center,
                  size: 16,
                  color: color.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    muscleGroup,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadWorkoutData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
