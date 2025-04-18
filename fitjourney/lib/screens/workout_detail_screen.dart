/// WorkoutDetailScreen displays detailed information about a specific workout
/// Features include:
/// - Workout date and time display
/// - Exercise list with sets and reps
/// - Total volume calculation
/// - Workout duration tracking
/// - Exercise categorization by muscle groups
/// - Visual exercise cards with progress data
import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/workout.dart';
//import 'package:fitjourney/database_models/workout_set.dart';
import 'package:intl/intl.dart';
import 'edit_workout_screen.dart';

/// Main screen widget for displaying workout details
/// Takes a workout ID to load and display specific workout information
class WorkoutDetailScreen extends StatefulWidget {
  final int workoutId;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

/// State management for WorkoutDetailScreen
/// Handles:
/// - Loading workout data
/// - Calculating workout statistics
/// - Managing UI state
/// - Workout deletion
class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  bool _isLoading = true;
  Workout? _workout;
  List<Map<String, dynamic>> _exercises = [];
  double _totalVolume = 0;

  @override
  void initState() {
    super.initState();
    _loadWorkoutDetails();
  }

  /// Loads detailed workout information including exercises and sets
  /// Calculates total volume and updates UI state
  Future<void> _loadWorkoutDetails() async {
    try {
      final details = await _workoutService.getWorkoutDetails(widget.workoutId);
      final workout = details['workout'] as Workout;
      final exercises = details['exercises'] as List<Map<String, dynamic>>;

      // Calculate total volume
      double totalVolume = 0;
      for (var exercise in exercises) {
        final sets = exercise['sets'] as List;
        for (var set in sets) {
          final weight = set.weight ?? 0.0;
          final reps = set.reps ?? 0;
          totalVolume += weight * reps;
        }
      }

      setState(() {
        _workout = workout;
        _exercises = exercises;
        _totalVolume = totalVolume;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workout details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handles workout deletion with user confirmation
  /// Shows confirmation dialog and manages the deletion process
  Future<void> _deleteWorkout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Workout'),
            content:
                const Text('Are you sure you want to delete this workout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

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
            : 'Workout ${DateFormat('MM/dd').format(_workout!.date)}'),
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditWorkoutScreen(workoutId: widget.workoutId),
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
                        margin: const EdgeInsets.only(bottom: 24),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Colors.blue.shade300.withOpacity(0.5)),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.blue.shade50,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: Colors.blue.shade700,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE, MMMM d, yyyy')
                                              .format(_workout!.date),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('h:mm a')
                                              .format(_workout!.date),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Volume and exercise count
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildWorkoutStat(
                                          Icons.fitness_center,
                                          '${_exercises.length}',
                                          'Exercises',
                                          Colors.green),
                                    ),
                                    Expanded(
                                      child: _buildWorkoutStat(
                                          Icons.monitor_weight_outlined,
                                          '${_totalVolume.toStringAsFixed(1)} kg',
                                          'Total Volume',
                                          Colors.orange),
                                    ),
                                    if (_workout!.duration != null)
                                      Expanded(
                                        child: _buildWorkoutStat(
                                            Icons.timer_outlined,
                                            '${_workout!.duration}',
                                            'Minutes',
                                            Colors.purple),
                                      ),
                                  ],
                                ),

                                if (_workout!.notes != null &&
                                    _workout!.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.note_alt_outlined,
                                              size: 16,
                                              color: Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Notes:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _workout!.notes!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Exercises section
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.fitness_center,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Exercises',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List of exercises with sets
                      ..._exercises
                          .map((exercise) => _buildExerciseCard(exercise)),
                    ],
                  ),
                ),
    );
  }

  /// Creates a visual representation of workout statistics
  /// Shows icon, value, and label in a consistent format
  Widget _buildWorkoutStat(
      IconData icon, String value, String label, Color color) {
    // Determine appropriate color shade
    Color iconColor = color;
    if (color == Colors.green) {
      iconColor = Colors.green.shade600;
    } else if (color == Colors.orange) {
      iconColor = Colors.orange.shade600;
    } else if (color == Colors.purple) {
      iconColor = Colors.purple.shade600;
    } else if (color == Colors.blue) {
      iconColor = Colors.blue.shade600;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// Builds a detailed card for each exercise in the workout
  /// Shows exercise name, muscle group, and set information
  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final exerciseName = exercise['name'] as String;
    final muscleGroup = exercise['muscle_group'] as String;
    final sets = exercise['sets'] as List<dynamic>? ?? [];

    // Get color based on muscle group
    final Color muscleColor = _getColorForMuscleGroup(muscleGroup);
    final IconData muscleIcon = _getIconForMuscleGroup(muscleGroup);

    // Determine appropriate darker shades for text
    Color darkMuscleColor = muscleColor;
    Color headerColor = muscleColor;

    // Apply deeper shades based on the color
    if (muscleColor == Colors.blue) {
      darkMuscleColor = Colors.blue.shade700;
      headerColor = Colors.blue.shade700;
    } else if (muscleColor == Colors.green) {
      darkMuscleColor = Colors.green.shade700;
      headerColor = Colors.green.shade700;
    } else if (muscleColor == Colors.cyan) {
      darkMuscleColor = Colors.cyan.shade700;
      headerColor = Colors.cyan.shade700;
    } else if (muscleColor == Colors.teal) {
      darkMuscleColor = Colors.teal.shade700;
      headerColor = Colors.teal.shade700;
    } else if (muscleColor == Colors.indigo) {
      darkMuscleColor = Colors.indigo.shade700;
      headerColor = Colors.indigo.shade700;
    } else if (muscleColor == Colors.orange) {
      darkMuscleColor = Colors.orange.shade700;
      headerColor = Colors.orange.shade700;
    } else if (muscleColor == Colors.amber) {
      darkMuscleColor = Colors.amber.shade800;
      headerColor = Colors.amber.shade800;
    } else if (muscleColor == Colors.deepOrange) {
      darkMuscleColor = Colors.deepOrange.shade700;
      headerColor = Colors.deepOrange.shade700;
    } else if (muscleColor == Colors.purple) {
      darkMuscleColor = Colors.purple.shade700;
      headerColor = Colors.purple.shade700;
    } else {
      darkMuscleColor = Colors.blueGrey.shade700;
      headerColor = Colors.blueGrey.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              muscleColor.withOpacity(0.08),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: muscleColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      muscleIcon,
                      color: darkMuscleColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: muscleColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                muscleGroup,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: darkMuscleColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (sets.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${sets.length} sets',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sets table
              if (sets.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Table(
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 1,
                      borderRadius: BorderRadius.circular(8),
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
                          color: muscleColor.withOpacity(0.1),
                        ),
                        children: [
                          _buildTableCell('SET',
                              isHeader: true, color: headerColor),
                          _buildTableCell('WEIGHT',
                              isHeader: true, color: headerColor),
                          _buildTableCell('REPS',
                              isHeader: true, color: headerColor),
                        ],
                      ),
                      // Data rows
                      ...sets.map((set) => TableRow(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            children: [
                              _buildTableCell('${set.setNumber}'),
                              _buildTableCell(
                                  '${set.weight?.toStringAsFixed(1) ?? "0"} kg'),
                              _buildTableCell('${set.reps ?? "0"}'),
                            ],
                          )),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'No sets recorded for this exercise',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Creates a formatted cell for the sets table
  /// Handles both header and data cells with appropriate styling
  Widget _buildTableCell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
            color: isHeader && color != null
                ? color.withOpacity(0.8)
                : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  /// Maps muscle groups to their corresponding colors
  /// Used for visual categorization of exercises
  Color _getColorForMuscleGroup(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return Colors.blue;
      case 'Back':
        return Colors.green;
      case 'Shoulders':
        return Colors.cyan;
      case 'Biceps':
        return Colors.teal;
      case 'Triceps':
        return Colors.indigo;
      case 'Legs':
        return Colors.orange;
      case 'Calves':
        return Colors.amber;
      case 'Glutes':
        return Colors.deepOrange;
      case 'Core':
      case 'Abs':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  /// Maps muscle groups to their corresponding icons
  /// Provides visual indicators for different exercise types
  IconData _getIconForMuscleGroup(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return Icons.fitness_center; // Dumbbell for chest
      case 'Back':
        return Icons.fitness_center; // Dumbbell for back
      case 'Shoulders':
        return Icons.fitness_center; // Dumbbell for shoulders
      case 'Biceps':
        return Icons.fitness_center; // Dumbbell for biceps
      case 'Triceps':
        return Icons.fitness_center; // Dumbbell for triceps
      case 'Legs':
        return Icons.directions_run; // Running icon for legs
      case 'Calves':
        return Icons.directions_run; // Running icon for calves
      case 'Glutes':
        return Icons.directions_run; // Running icon for glutes
      case 'Core':
      case 'Abs':
        return Icons.fitness_center; // Dumbbell for core/abs
      default:
        return Icons.fitness_center; // Default to dumbbell
    }
  }
}
