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
  State<WorkoutComparisonScreen> createState() => _WorkoutComparisonScreenState();
}

class _WorkoutComparisonScreenState extends State<WorkoutComparisonScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Workout data
  Workout? _firstWorkout;
  Workout? _secondWorkout;
  List<Map<String, dynamic>> _firstWorkoutExercises = [];
  List<Map<String, dynamic>> _secondWorkoutExercises = [];
  
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
      
      final firstWorkoutExercises = firstWorkoutDetails['exercises'] as List<Map<String, dynamic>>;
      final secondWorkoutExercises = secondWorkoutDetails['exercises'] as List<Map<String, dynamic>>;
      
      // Generate comparison data
      final comparisonData = _generateComparisonData(
        firstWorkout, 
        secondWorkout, 
        firstWorkoutExercises, 
        secondWorkoutExercises
      );
      
      setState(() {
        _firstWorkout = firstWorkout;
        _secondWorkout = secondWorkout;
        _firstWorkoutExercises = firstWorkoutExercises;
        _secondWorkoutExercises = secondWorkoutExercises;
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
      for (var set in sets) {
        final reps = set.reps ?? 0;
        final weight = set.weight ?? 0.0;
        firstTotalVolume += reps * weight;
      }
    }
    
    // Calculate total volume for second workout
    for (var exercise in secondWorkoutExercises) {
      final sets = exercise['sets'] as List;
      for (var set in sets) {
        final reps = set.reps ?? 0;
        final weight = set.weight ?? 0.0;
        secondTotalVolume += reps * weight;
      }
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
        final firstSets = firstExercise['sets'] as List;
        
        for (var set in firstSets) {
          final weight = set.weight ?? 0.0;
          final reps = set.reps ?? 0;
          if (weight > firstMaxWeight) {
            firstMaxWeight = weight;
          }
          firstTotalVolume += weight * reps;
        }
        
        // Calculate max weight and volume for second exercise
        double secondMaxWeight = 0;
        double secondTotalVolume = 0;
        final secondSets = secondExercise['sets'] as List;
        
        for (var set in secondSets) {
          final weight = set.weight ?? 0.0;
          final reps = set.reps ?? 0;
          if (weight > secondMaxWeight) {
            secondMaxWeight = weight;
          }
          secondTotalVolume += weight * reps;
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
    
    // Sort matching exercises by biggest improvement
    matchingExercises.sort((a, b) => 
      (b['weightPercentChange'] as double).compareTo(a['weightPercentChange'] as double)
    );
    
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Matching Exercises (${_comparisonData['matchingExercises'].length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._buildMatchingExercisesCards(),
          ],
          
          // Unique exercises section
          if (_comparisonData['uniqueToFirst'].isNotEmpty || 
              _comparisonData['uniqueToSecond'].isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: const Text(
                'Unique Exercises',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildUniqueExercisesSection(),
          ],
          
          const SizedBox(height: 24),
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
    
    //final daysBetween = _secondWorkout!.date.difference(_firstWorkout!.date).inDays;
    
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
            Row(
              children: [
                Icon(
                  isImproved ? Icons.trending_up : Icons.trending_down,
                  color: isImproved ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isImproved 
                      ? 'Overall Improvement' 
                      : 'Overall Decline',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                        ),
                      ),
                      Text(
                        '${_firstWorkout!.duration ?? 0} minutes',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${_comparisonData['firstExerciseCount']} exercises',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          ),
                        ),
                        Text(
                          '${_secondWorkout!.duration ?? 0} minutes',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${_comparisonData['secondExerciseCount']} exercises',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 24),
            const Text(
              'Total Volume Comparison',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
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
                            isImproved ? Icons.arrow_upward : Icons.arrow_downward,
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
  
  List<Widget> _buildMatchingExercisesCards() {
    final matchingExercises = _comparisonData['matchingExercises'] as List<Map<String, dynamic>>;
    
    return matchingExercises.map((exercise) => _buildExerciseComparisonCard(exercise)).toList();
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWeightImproved ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isWeightImproved ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: isWeightImproved ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${weightPercentChange.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isWeightImproved ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Max Weight',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildComparisonRow(
                        'First',
                        '${firstMaxWeight.toStringAsFixed(1)} kg',
                        null,
                      ),
                      const SizedBox(height: 4),
                      _buildComparisonRow(
                        'Second',
                        '${secondMaxWeight.toStringAsFixed(1)} kg',
                        isWeightImproved,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Volume',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildComparisonRow(
                        'First',
                        '${firstTotalVolume.toStringAsFixed(1)} kg',
                        null,
                      ),
                      const SizedBox(height: 4),
                      _buildComparisonRow(
                        'Second',
                        '${secondTotalVolume.toStringAsFixed(1)} kg',
                        isVolumeImproved,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Number of sets: $firstSets → $secondSets',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildComparisonRow(String label, String value, bool? isImproved) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isImproved != null) ...[
          const SizedBox(width: 8),
          Icon(
            isImproved ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: isImproved ? Colors.green : Colors.red,
          ),
        ],
      ],
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
            if (uniqueToFirst.isNotEmpty) ...[
              Text(
                'Only in First Workout (${uniqueToFirst.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
  
  Widget _buildUniqueExerciseItem(String name, String muscleGroup, bool isFirst) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isFirst ? Colors.blue.shade100 : Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.fitness_center,
                size: 16,
                color: isFirst ? Colors.blue.shade700 : Colors.green.shade700,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}