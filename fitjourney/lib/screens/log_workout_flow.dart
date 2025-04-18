/// LogWorkoutFlow manages the process of recording workouts
/// Provides a multi-step flow for selecting exercises and logging sets
import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/exercise.dart';

import 'dart:async';

/// Main entry point for the workout logging flow
/// Tracks workout duration and manages navigation between screens
class LogWorkoutFlow extends StatefulWidget {
  const LogWorkoutFlow({super.key});

  @override
  State<LogWorkoutFlow> createState() => _LogWorkoutFlowState();
}

class _LogWorkoutFlowState extends State<LogWorkoutFlow> {
  // Track workout start time and duration
  DateTime _startTime = DateTime.now();
  Timer? _workoutTimer;

  @override
  void initState() {
    super.initState();
    // Initialize timer for workout duration tracking
    _workoutTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      // Empty - duration will be calculated when saving
    });
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Start with the muscle group selection
    return MuscleGroupSelectionScreen(
      startTime: _startTime,
    );
  }
}

/// First screen in the workout logging flow
/// Displays available muscle groups for exercise selection
class MuscleGroupSelectionScreen extends StatefulWidget {
  final DateTime startTime;

  const MuscleGroupSelectionScreen({
    super.key,
    required this.startTime,
  });

  @override
  State<MuscleGroupSelectionScreen> createState() =>
      _MuscleGroupSelectionScreenState();
}

class _MuscleGroupSelectionScreenState
    extends State<MuscleGroupSelectionScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  List<String> _muscleGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMuscleGroups();
  }

  /// Retrieves all available muscle groups from the database
  /// Used to populate the selection list
  Future<void> _loadMuscleGroups() async {
    try {
      final muscleGroups = await _workoutService.getAllMuscleGroups();
      setState(() {
        _muscleGroups = muscleGroups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading muscle groups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Muscle Group'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _muscleGroups.isEmpty
              ? const Center(child: Text('No muscle groups found'))
              : ListView.builder(
                  itemCount: _muscleGroups.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        _muscleGroups[index],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExerciseSelectionScreen(
                              muscleGroup: _muscleGroups[index],
                              startTime: widget.startTime,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

/// Second screen in the workout logging flow
/// Shows exercises available for the selected muscle group
class ExerciseSelectionScreen extends StatefulWidget {
  final String muscleGroup;
  final DateTime startTime;

  const ExerciseSelectionScreen({
    super.key,
    required this.muscleGroup,
    required this.startTime,
  });

  @override
  State<ExerciseSelectionScreen> createState() =>
      _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  List<Exercise> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  /// Loads exercises specific to the selected muscle group
  /// Includes exercise details like name and description
  Future<void> _loadExercises() async {
    try {
      final exercises =
          await _workoutService.getExercisesByMuscleGroup(widget.muscleGroup);
      setState(() {
        _exercises = exercises;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading exercises: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.muscleGroup),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exercises.isEmpty
              ? const Center(
                  child: Text('No exercises found for this muscle group'))
              : ListView.builder(
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _exercises[index];
                    return ListTile(
                      title: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      leading: exercise.description != null
                          ? IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () {
                                // Show exercise info dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => ExerciseInfoDialog(
                                    exerciseName: exercise.name,
                                    description: exercise.description ?? '',
                                  ),
                                );
                              },
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SetEntryScreen(
                              exerciseId: exercise.exerciseId!,
                              muscleGroup: widget.muscleGroup,
                              exerciseName: exercise.name,
                              startTime: widget.startTime,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

/// Dialog showing detailed exercise information
/// Displays exercise description
class ExerciseInfoDialog extends StatelessWidget {
  final String exerciseName;
  final String description;

  const ExerciseInfoDialog({
    super.key,
    required this.exerciseName,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(exerciseName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 180,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.image, size: 50, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How to perform:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Final screen in the workout logging flow
/// Allows users to log sets with weight and reps
/// Handles saving the workout to the database
class SetEntryScreen extends StatefulWidget {
  final int exerciseId;
  final String muscleGroup;
  final String exerciseName;
  final DateTime startTime;

  const SetEntryScreen({
    super.key,
    required this.exerciseId,
    required this.muscleGroup,
    required this.exerciseName,
    required this.startTime,
  });

  @override
  State<SetEntryScreen> createState() => _SetEntryScreenState();
}

class _SetEntryScreenState extends State<SetEntryScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  final List<Map<String, dynamic>> _sets = [];
  bool _isMetric = true; // Weight unit selection
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with one empty set
    _addSet();
  }

  @override
  void dispose() {
    // Clean up controllers
    _notesController.dispose();
    for (var set in _sets) {
      set['weightController'].dispose();
      set['repsController'].dispose();
    }
    super.dispose();
  }

  /// Adds a new set to the exercise
  /// Pre-fills with values from the previous set if available
  void _addSet() {
    setState(() {
      // Get previous set values if available
      final prevWeight = _sets.isNotEmpty ? _sets.last['weight'] : '';
      final prevReps = _sets.isNotEmpty ? _sets.last['reps'] : '';

      _sets.add({
        'setNumber': _sets.length + 1,
        'weight': prevWeight,
        'reps': prevReps,
        'weightController': TextEditingController(text: prevWeight),
        'repsController': TextEditingController(text: prevReps),
      });
    });
  }

  /// Removes a set from the exercise
  /// Updates set numbers to maintain sequence
  void _removeSet(int index) {
    setState(() {
      // Dispose controllers for the removed set
      _sets[index]['weightController'].dispose();
      _sets[index]['repsController'].dispose();

      _sets.removeAt(index);
      // Update set numbers
      for (int i = 0; i < _sets.length; i++) {
        _sets[i]['setNumber'] = i + 1;
      }
    });
  }

  /// Saves the exercise and its sets to the database
  /// Creates a new workout if this is the first exercise
  Future<void> _saveExercise() async {
    // Validate inputs
    bool hasEmptyFields = false;
    for (var set in _sets) {
      if (set['weight'].toString().isEmpty || set['reps'].toString().isEmpty) {
        hasEmptyFields = true;
        break;
      }
    }

    if (hasEmptyFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all weight and rep values')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Create the workout only now when user is saving
      final durationInMinutes =
          DateTime.now().difference(widget.startTime).inMinutes;

      // Create a new workout
      final workoutId = await _workoutService.createWorkout(
        date: widget.startTime,
        duration: durationInMinutes,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // 2. Add the exercise to the workout
      final workoutExerciseId = await _workoutService.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: widget.exerciseId,
      );

      // 3. Save each set to the database
      for (var set in _sets) {
        await _workoutService.addSetToWorkoutExercise(
          workoutExerciseId: workoutExerciseId,
          setNumber: set['setNumber'],
          reps: int.tryParse(set['reps'].toString()) ?? 0,
          weight: double.tryParse(set['weight'].toString()) ?? 0.0,
        );
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise added to your workout!'),
          backgroundColor: Colors.green,
        ),
      );

      // Pop back to exercise selection
      Navigator.pop(context);
    } catch (e) {
      print('Error saving workout: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving exercise: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Updated to use SingleChildScrollView with keyboard inset padding
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            // Exercise info card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: Colors.blue.shade700,
                    size: 30,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exerciseName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Muscle Group: ${widget.muscleGroup}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Weight unit selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Unit:'),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('kg'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('lbs'),
                      ),
                    ],
                    selected: {_isMetric},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isMetric = newSelection.first;
                      });
                    },
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16).copyWith(bottom: 0),
              child: Row(
                children: [
                  const SizedBox(
                      width: 50,
                      child: Text('SET',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isMetric ? 'WEIGHT (kg)' : 'WEIGHT (lbs)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('REPS',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 48), // For delete button
                ],
              ),
            ),

            // Set rows
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _sets.map((set) {
                  final index = _sets.indexOf(set);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        // Set number
                        SizedBox(
                          width: 50,
                          child: Text(
                            set['setNumber'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Weight input
                        Expanded(
                          child: TextField(
                            controller: set['weightController'],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              set['weight'] = value;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Reps input
                        Expanded(
                          child: TextField(
                            controller: set['repsController'],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              set['reps'] = value;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Delete button
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _sets.length > 1
                                ? () => _removeSet(index)
                                : null,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Add set button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add),
                label: const Text('Add Set'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),

            // Notes
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 2,
              ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.all(16).copyWith(top: 0),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Exercise',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
