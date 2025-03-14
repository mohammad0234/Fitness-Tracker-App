import 'package:flutter/material.dart';

// Main entry point for the workout logging flow
class LogWorkoutFlow extends StatefulWidget {
  const LogWorkoutFlow({super.key});

  @override
  State<LogWorkoutFlow> createState() => _LogWorkoutFlowState();
}

class _LogWorkoutFlowState extends State<LogWorkoutFlow> {
  @override
  Widget build(BuildContext context) {
    // Start with the muscle group selection
    return const MuscleGroupSelectionScreen();
  }
}

// First screen: Muscle Group Selection
class MuscleGroupSelectionScreen extends StatelessWidget {
  const MuscleGroupSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder data for muscle groups
    final List<String> muscleGroups = [
      'Abs',
      'Back',
      'Biceps',
      'Chest',
      'Legs',
      'Shoulders',
      'Triceps',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Muscle Group'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement add custom muscle group
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: muscleGroups.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              muscleGroups[index],
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
                    muscleGroup: muscleGroups[index],
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

// Second screen: Exercise Selection
class ExerciseSelectionScreen extends StatelessWidget {
  final String muscleGroup;
  
  const ExerciseSelectionScreen({
    super.key, 
    required this.muscleGroup,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder data for exercises based on muscle group
    final Map<String, List<Map<String, dynamic>>> exercisesByMuscle = {
      'Chest': [
        {'name': 'Bench Press', 'hasInfo': true},
        {'name': 'Cable Crossovers', 'hasInfo': true},
        {'name': 'Dumbbell Press', 'hasInfo': true},
        {'name': 'Dumbbell Flies', 'hasInfo': true},
        {'name': 'Decline Bench Press', 'hasInfo': true},
        {'name': 'Incline Dumbbell Press', 'hasInfo': true},
      ],
      'Back': [
        {'name': 'Pull-ups', 'hasInfo': true},
        {'name': 'Deadlift', 'hasInfo': true},
        {'name': 'Bent Over Row', 'hasInfo': true},
        {'name': 'Lat Pulldown', 'hasInfo': true},
      ],
      'Legs': [
        {'name': 'Squats', 'hasInfo': true},
        {'name': 'Leg Press', 'hasInfo': true},
        {'name': 'Leg Extensions', 'hasInfo': true},
        {'name': 'Hamstring Curls', 'hasInfo': true},
        {'name': 'Calf Raises', 'hasInfo': true},
      ],
      // Add placeholder data for other muscle groups
      'Abs': [
        {'name': 'Crunches', 'hasInfo': true},
        {'name': 'Leg Raises', 'hasInfo': true},
        {'name': 'Planks', 'hasInfo': true},
      ],
      'Biceps': [
        {'name': 'Bicep Curls', 'hasInfo': true},
        {'name': 'Hammer Curls', 'hasInfo': true},
        {'name': 'Preacher Curls', 'hasInfo': true},
      ],
      'Triceps': [
        {'name': 'Tricep Pushdowns', 'hasInfo': true},
        {'name': 'Skull Crushers', 'hasInfo': true},
        {'name': 'Dips', 'hasInfo': true},
      ],
      'Shoulders': [
        {'name': 'Shoulder Press', 'hasInfo': true},
        {'name': 'Lateral Raises', 'hasInfo': true},
        {'name': 'Front Raises', 'hasInfo': true},
        {'name': 'Shrugs', 'hasInfo': true},
      ],
    };

    // Default to an empty list if the muscle group isn't in our map
    final exercises = exercisesByMuscle[muscleGroup] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(muscleGroup),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement add custom exercise
            },
          ),
        ],
      ),
      body: exercises.isEmpty
          ? const Center(
              child: Text('No exercises found for this muscle group'),
            )
          : ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return ListTile(
                  title: Text(
                    exercise['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  leading: exercise['hasInfo'] == true
                      ? IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            // Show exercise info dialog
                            showDialog(
                              context: context,
                              builder: (context) => ExerciseInfoDialog(
                                exerciseName: exercise['name'] as String,
                              ),
                            );
                          },
                        )
                      : null,
                  trailing: const Icon(Icons.more_vert),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SetEntryScreen(
                          muscleGroup: muscleGroup,
                          exerciseName: exercise['name'] as String,
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

// Exercise info dialog
class ExerciseInfoDialog extends StatelessWidget {
  final String exerciseName;
  
  const ExerciseInfoDialog({super.key, required this.exerciseName});

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
            const Text(
              '1. Start position: Lorem ipsum dolor sit amet\n'
              '2. Movement: Consectetur adipiscing elit\n'
              '3. End position: Sed do eiusmod tempor incididunt\n\n'
              'Tips: Ut labore et dolore magna aliqua.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Target Muscles:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Primary: Pectoralis Major\nSecondary: Anterior Deltoids, Triceps',
              style: TextStyle(fontSize: 14),
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

// Third screen: Set Entry
class SetEntryScreen extends StatefulWidget {
  final String muscleGroup;
  final String exerciseName;
  
  const SetEntryScreen({
    super.key, 
    required this.muscleGroup, 
    required this.exerciseName,
  });

  @override
  State<SetEntryScreen> createState() => _SetEntryScreenState();
}

class _SetEntryScreenState extends State<SetEntryScreen> {
  final List<Map<String, dynamic>> _sets = [];
  bool _isMetric = true; // kg vs lbs
  
  @override
  void initState() {
    super.initState();
    // Add the first set automatically
    _addSet();
  }
  
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
  
  void _removeSet(int index) {
    setState(() {
      _sets.removeAt(index);
      // Update set numbers
      for (int i = 0; i < _sets.length; i++) {
        _sets[i]['setNumber'] = i + 1;
      }
    });
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
                  const SizedBox(width: 50, child: Text('SET', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isMetric ? 'WEIGHT (kg)' : 'WEIGHT (lbs)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('REPS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 48), // For delete button
                ],
              ),
            ),
            
            // Set rows (now directly in ScrollView instead of a nested ListView)
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            onPressed: _sets.length > 1 ? () => _removeSet(index) : null,
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
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 2,
              ),
            ),
            
            // Save button
            Padding(
              padding: const EdgeInsets.all(16).copyWith(top: 0),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Save workout data to database
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exercise added to your workout!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Return to exercise selection
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Save Exercise', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}