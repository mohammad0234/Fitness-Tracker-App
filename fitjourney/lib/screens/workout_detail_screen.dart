import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/workout.dart';
//import 'package:fitjourney/database_models/workout_set.dart';
import 'package:intl/intl.dart';
import 'edit_workout_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final int workoutId;
  
  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  bool _isLoading = true;
  Workout? _workout;
  List<Map<String, dynamic>> _exercises = [];
  
  @override
  void initState() {
    super.initState();
    _loadWorkoutDetails();
  }
  
  Future<void> _loadWorkoutDetails() async {
    try {
      final details = await _workoutService.getWorkoutDetails(widget.workoutId);
      setState(() {
        _workout = details['workout'] as Workout;
        _exercises = details['exercises'] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workout details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteWorkout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: const Text('Are you sure you want to delete this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    try {
      await _workoutService.deleteWorkout(widget.workoutId);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully')),
      );
      
      Navigator.of(context).pop(true); // Return true to indicate deletion
    } catch (e) {
      print('Error deleting workout: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting workout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading 
          ? 'Workout Details' 
          : _workout?.notes ?? 'Workout ${DateFormat('MM/dd').format(_workout!.date)}'
        ),
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditWorkoutScreen(workoutId: widget.workoutId),
                ),
              ).then((updated) {
                if (updated == true) {
                  _loadWorkoutDetails(); // Reload the workout details
                }
              });
            },
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteWorkout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workout == null
              ? const Center(child: Text('Workout not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Workout info card
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMMM d, yyyy').format(_workout!.date),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('h:mm a').format(_workout!.date),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              if (_workout!.notes != null) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Notes:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(_workout!.notes!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Exercises section
                      const Text(
                        'Exercises',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // List of exercises with sets
                      ..._exercises.map((exercise) => _buildExerciseCard(exercise)),
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final exerciseName = exercise['name'] as String;
    final muscleGroup = exercise['muscle_group'] as String;
    //final workoutExerciseId = exercise['workout_exercise_id'] as int;
    final sets = exercise['sets'] as List<dynamic>? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        exerciseName,
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
              ],
            ),
            const SizedBox(height: 16),
            
            // Sets table
            if (sets.isNotEmpty) ...[
              Table(
                border: TableBorder.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                columnWidths: const {
                  0: FlexColumnWidth(1), // Set #
                  1: FlexColumnWidth(2), // Weight
                  2: FlexColumnWidth(2), // Reps
                },
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                    ),
                    children: [
                      _buildTableCell('SET', isHeader: true),
                      _buildTableCell('WEIGHT', isHeader: true),
                      _buildTableCell('REPS', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...sets.map((set) => TableRow(
                    children: [
                      _buildTableCell('${set.setNumber}'),
                      _buildTableCell('${set.weight} kg'),
                      _buildTableCell('${set.reps}'),
                    ],
                  )),
                ],
              ),
            ] else ...[
              const Center(
                child: Text('No sets recorded for this exercise'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}