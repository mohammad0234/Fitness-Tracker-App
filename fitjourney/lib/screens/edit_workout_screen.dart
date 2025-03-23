import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/database/database_helper.dart';

class EditWorkoutScreen extends StatefulWidget {
  final int workoutId;
  
  const EditWorkoutScreen({
    super.key, 
    required this.workoutId,
  });

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  final TextEditingController _notesController = TextEditingController();
  
  // Add this to track sets that need to be deleted from the database
  final List<int> _setsToDelete = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  Workout? _workout;
  List<Map<String, dynamic>> _exercises = [];

  // For keeping track of sets that were modified
  final Map<int, List<Map<String, dynamic>>> _exerciseSets = {};
  bool _hasChanges = false;
  
  @override
  void initState() {
    super.initState();
    _loadWorkoutDetails();
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    
    // Dispose of all TextEditingControllers for sets
    for (var sets in _exerciseSets.values) {
      for (var set in sets) {
        set['weightController'].dispose();
        set['repsController'].dispose();
      }
    }
    
    super.dispose();
  }
  
  Future<void> _loadWorkoutDetails() async {
    try {
      // Get workout details
      final details = await _workoutService.getWorkoutDetails(widget.workoutId);
      final workout = details['workout'] as Workout;
      final exercises = details['exercises'] as List<Map<String, dynamic>>;
      
      // Initialize notes controller
      _notesController.text = workout.notes ?? '';
      
      // Initialize sets for each exercise
      for (var exercise in exercises) {
        final workoutExerciseId = exercise['workout_exercise_id'] as int;
        final sets = exercise['sets'] as List<dynamic>;
        
        _exerciseSets[workoutExerciseId] = [];
        
        for (var set in sets) {
          _exerciseSets[workoutExerciseId]!.add({
            'setNumber': set.setNumber,
            'weight': set.weight?.toString() ?? '',
            'reps': set.reps?.toString() ?? '',
            'workoutSetId': set.workoutSetId,
            'weightController': TextEditingController(text: set.weight?.toString() ?? ''),
            'repsController': TextEditingController(text: set.reps?.toString() ?? ''),
          });
        }
      }
      
      setState(() {
        _workout = workout;
        _exercises = exercises;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workout: $e');
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  void _addSet(int workoutExerciseId) {
    setState(() {
      // Get previous set values if available
      final sets = _exerciseSets[workoutExerciseId]!;
      final prevWeight = sets.isNotEmpty ? sets.last['weight'] : '';
      final prevReps = sets.isNotEmpty ? sets.last['reps'] : '';
      
      // Add new set with higher set number
      sets.add({
        'setNumber': sets.length + 1,
        'weight': prevWeight,
        'reps': prevReps,
        'workoutSetId': null, // New set, not in DB yet
        'weightController': TextEditingController(text: prevWeight),
        'repsController': TextEditingController(text: prevReps),
      });
      
      _hasChanges = true;
    });
  }
  
  // Updated _removeSet method to track deleted sets
  void _removeSet(int workoutExerciseId, int index) {
    setState(() {
      final sets = _exerciseSets[workoutExerciseId]!;
      
      // If this set exists in the database, mark it for deletion
      final workoutSetId = sets[index]['workoutSetId'];
      if (workoutSetId != null) {
        _setsToDelete.add(workoutSetId);
      }
      
      // Dispose controllers for the removed set
      sets[index]['weightController'].dispose();
      sets[index]['repsController'].dispose();
      
      // Remove the set
      sets.removeAt(index);
      
      // Update set numbers
      for (int i = 0; i < sets.length; i++) {
        sets[i]['setNumber'] = i + 1;
      }
      
      _hasChanges = true;
    });
  }
  
  // Updated _saveWorkout method to handle set deletions
  Future<void> _saveWorkout() async {
    if (_workout == null) return;
    
    // Validate all fields
    bool hasEmptyFields = false;
    String errorMessage = '';
    
    for (var exerciseId in _exerciseSets.keys) {
      final sets = _exerciseSets[exerciseId]!;
      
      for (var set in sets) {
        if (set['weight'].toString().isEmpty || set['reps'].toString().isEmpty) {
          final exerciseName = _exercises.firstWhere(
            (e) => e['workout_exercise_id'] == exerciseId, 
            orElse: () => {'name': 'Unknown'}
          )['name'];
          
          errorMessage = 'Please fill in all weight and rep values for $exerciseName';
          hasEmptyFields = true;
          break;
        }
      }
      
      if (hasEmptyFields) break;
    }
    
    if (hasEmptyFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Get database instance
      final db = await DatabaseHelper.instance.database;
      
      // Use a transaction for all database operations
      await db.transaction((txn) async {
        // 1. Update workout notes
        await txn.update(
          'workout',
          {'notes': _notesController.text.isEmpty ? null : _notesController.text},
          where: 'workout_id = ?',
          whereArgs: [widget.workoutId],
        );
        
        // 2. Delete any sets that were removed
        for (int setId in _setsToDelete) {
          await txn.delete(
            'workout_set',
            where: 'workout_set_id = ?',
            whereArgs: [setId],
          );
        }
        
        // 3. Update all remaining sets
        for (var exerciseId in _exerciseSets.keys) {
          final sets = _exerciseSets[exerciseId]!;
          
          for (var set in sets) {
            final weight = double.tryParse(set['weight'].toString());
            final reps = int.tryParse(set['reps'].toString());
            final setNumber = set['setNumber'] as int;
            final workoutSetId = set['workoutSetId'];
            
            if (workoutSetId != null) {
              // Update existing set
              await txn.update(
                'workout_set',
                {
                  'set_number': setNumber,
                  'weight': weight,
                  'reps': reps,
                },
                where: 'workout_set_id = ?',
                whereArgs: [workoutSetId],
              );
            } else {
              // Insert new set
              await txn.insert(
                'workout_set',
                {
                  'workout_exercise_id': exerciseId,
                  'set_number': setNumber,
                  'weight': weight,
                  'reps': reps,
                },
              );
            }
          }
        }
      });
      
      // Mark for sync
      await DatabaseHelper.instance.markForSync(
        'workout', 
        widget.workoutId.toString(), 
        'UPDATE'
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout updated successfully')),
      );
      
      Navigator.pop(context, true); // Return true to indicate update
    } catch (e) {
      print('Error updating workout: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating workout: $e')),
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
        title: const Text('Edit Workout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_hasChanges) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard Changes?'),
                  content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close edit screen
                      },
                      child: const Text('DISCARD'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _saveWorkout,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SAVE'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workout == null
              ? const Center(child: Text('Workout not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Workout details card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Workout Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('EEEE, MMMM d, yyyy').format(_workout!.date),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('h:mm a').format(_workout!.date),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.timer, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duration: ${_workout!.duration ?? 0} minutes',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Notes field
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Add notes about this workout',
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          _hasChanges = true;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Exercises',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Exercise cards with editable sets
                      ..._exercises.map((exercise) {
                        final exerciseName = exercise['name'] as String;
                        final muscleGroup = exercise['muscle_group'] as String;
                        final workoutExerciseId = exercise['workout_exercise_id'] as int;
                        final sets = _exerciseSets[workoutExerciseId] ?? [];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Exercise header
                                Row(
                                  children: [
                                    Icon(
                                      Icons.fitness_center,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            exerciseName,
                                            style: const TextStyle(
                                              fontSize: 18,
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
                                
                                // Sets header
                                Row(
                                  children: [
                                    const SizedBox(width: 50, child: Text('SET', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 16),
                                    const Expanded(child: Text('WEIGHT (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 16),
                                    const Expanded(child: Text('REPS', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 40), // For delete button
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // Editable sets
                                ...sets.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final set = entry.value;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
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
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            onChanged: (value) {
                                              set['weight'] = value;
                                              _hasChanges = true;
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
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            onChanged: (value) {
                                              set['reps'] = value;
                                              _hasChanges = true;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // Delete button
                                        SizedBox(
                                          width: 40,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: sets.length > 1 
                                                ? () => _removeSet(workoutExerciseId, index)
                                                : null,
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                
                                // Add set button
                                OutlinedButton.icon(
                                  onPressed: () => _addSet(workoutExerciseId),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Set'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
            
    );
  }
}