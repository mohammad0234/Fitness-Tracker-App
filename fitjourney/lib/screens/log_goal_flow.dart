/// LogGoalFlow manages the process of creating new fitness goals
/// Provides a multi-step flow for users to set weight, strength, or frequency goals
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/exercise.dart';

/// Main entry point for the goal creation flow
/// Manages the navigation between different goal type screens
class LogGoalFlow extends StatefulWidget {
  const LogGoalFlow({super.key});

  @override
  State<LogGoalFlow> createState() => _LogGoalFlowState();
}

/// Initial screen that directs users to the goal type selection
class _LogGoalFlowState extends State<LogGoalFlow> {
  @override
  Widget build(BuildContext context) {
    // Start with the goal type selection
    return const GoalTypeSelectionScreen();
  }
}

/// First screen in the goal creation flow
/// Presents users with different types of goals they can create:
/// - Weight goals for body weight targets
/// - Strength goals for specific exercises
/// - Frequency goals for workout consistency
class GoalTypeSelectionScreen extends StatelessWidget {
  const GoalTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Goal type options
    final List<Map<String, dynamic>> goalTypes = [
      {
        'title': 'Weight Goal',
        'description': 'Track progress towards a target body weight',
        'icon': Icons.monitor_weight_outlined,
        'color': Colors.blue,
      },
      {
        'title': 'Strength Goal',
        'description': 'Set targets for specific exercises',
        'icon': Icons.fitness_center_outlined,
        'color': Colors.orange,
      },
      {
        'title': 'Frequency Goal',
        'description': 'Set a target number of workouts per week',
        'icon': Icons.calendar_today_outlined,
        'color': Colors.green,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Goal'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What type of goal would you like to set?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: goalTypes.length,
                itemBuilder: (context, index) {
                  final goalType = goalTypes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      onTap: () {
                        // Navigate to the appropriate goal details screen
                        if (goalType['title'] == 'Weight Goal') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WeightGoalDetailsScreen(),
                            ),
                          );
                        } else if (goalType['title'] == 'Strength Goal') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const StrengthGoalDetailsScreen(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const FrequencyGoalDetailsScreen(),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  goalType['color'].withOpacity(0.1),
                              child: Icon(
                                goalType['icon'],
                                color: goalType['color'],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goalType['title'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    goalType['description'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen for creating weight-based goals
/// Allows users to set:
/// - Current weight
/// - Target weight
/// - Target date
/// - Weight unit (kg/lbs)
class WeightGoalDetailsScreen extends StatefulWidget {
  const WeightGoalDetailsScreen({super.key});

  @override
  State<WeightGoalDetailsScreen> createState() =>
      _WeightGoalDetailsScreenState();
}

class _WeightGoalDetailsScreenState extends State<WeightGoalDetailsScreen> {
  // Controllers for user input
  final TextEditingController _currentWeightController =
      TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  bool _isMetric = true; // Default to metric system

  @override
  void dispose() {
    // Clean up controllers
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Goal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal icon and title
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight Goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Track progress towards target weight',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Unit selector
            Row(
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
            const SizedBox(height: 24),

            // Current weight
            Text(
              'Current Weight',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentWeightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText:
                    _isMetric ? 'Enter weight in kg' : 'Enter weight in lbs',
                suffixText: _isMetric ? 'kg' : 'lbs',
              ),
            ),
            const SizedBox(height: 24),

            // Target weight
            Text(
              'Target Weight',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetWeightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText:
                    _isMetric ? 'Enter target in kg' : 'Enter target in lbs',
                suffixText: _isMetric ? 'kg' : 'lbs',
              ),
            ),
            const SizedBox(height: 24),

            // Target date
            Text(
              'Target Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && picked != _targetDate) {
                  setState(() {
                    _targetDate = picked;
                  });
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(_targetDate),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Create goal button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Validate inputs
                  if (_currentWeightController.text.isEmpty ||
                      _targetWeightController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Please enter both current and target weights')),
                    );
                    return;
                  }

                  // Navigate to review screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalReviewScreen(
                        goalType: 'Weight Goal',
                        details: {
                          'currentWeight': _currentWeightController.text,
                          'targetWeight': _targetWeightController.text,
                          'targetDate': _targetDate,
                          'unit': _isMetric ? 'kg' : 'lbs',
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen for creating strength-based goals
/// Allows users to:
/// - Select specific exercises
/// - Set current and target weights
/// - Choose target date
/// - Select weight unit
class StrengthGoalDetailsScreen extends StatefulWidget {
  const StrengthGoalDetailsScreen({super.key});

  @override
  State<StrengthGoalDetailsScreen> createState() =>
      _StrengthGoalDetailsScreenState();
}

class _StrengthGoalDetailsScreenState extends State<StrengthGoalDetailsScreen> {
  // State management for exercise selection and weight inputs
  String? _selectedExerciseId;
  String _selectedExerciseName = 'Select an exercise';
  final TextEditingController _currentWeightController =
      TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  bool _isMetric = true;
  bool _isLoading = false;
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  /// Loads available exercises from the database
  /// Populates the exercise selection list
  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final exercises = await WorkoutService.instance.getAllExercises();
      setState(() {
        _exercises = exercises;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading exercises: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Shows bottom sheet for exercise selection
  /// Displays exercises grouped by muscle groups
  void _selectExercise() {
    // Track search and filtering state
    String searchQuery = '';
    String selectedMuscleGroup = 'All';
    List<String> muscleGroups = ['All'];
    List<Exercise> filteredExercises = _exercises;

    // Get unique muscle groups from exercises
    final Set<String> uniqueMuscleGroups = _exercises
        .map((e) => e.muscleGroup ?? 'Other')
        .where((group) => group.isNotEmpty)
        .toSet();
    muscleGroups = ['All', ...uniqueMuscleGroups];

    // Function to filter exercises based on search and muscle group
    void filterExercises(String query, String muscleGroup) {
      filteredExercises = _exercises.where((exercise) {
        // Apply search filter
        final matchesSearch = query.isEmpty ||
            exercise.name.toLowerCase().contains(query.toLowerCase());

        // Apply muscle group filter
        final matchesMuscleGroup =
            muscleGroup == 'All' || exercise.muscleGroup == muscleGroup;

        return matchesSearch && matchesMuscleGroup;
      }).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Exercise',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search exercises...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                          filterExercises(searchQuery, selectedMuscleGroup);
                        });
                      },
                    ),
                  ),

                  // Muscle group filter
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: muscleGroups.length,
                      itemBuilder: (context, index) {
                        final muscleGroup = muscleGroups[index];
                        final isSelected = muscleGroup == selectedMuscleGroup;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(muscleGroup),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  selectedMuscleGroup = muscleGroup;
                                  filterExercises(
                                      searchQuery, selectedMuscleGroup);
                                });
                              }
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Exercise list
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredExercises.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.fitness_center_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No exercises match your filters',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search or filters',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredExercises.length,
                                itemBuilder: (context, index) {
                                  final exercise = filteredExercises[index];
                                  return ListTile(
                                    title: Text(exercise.name),
                                    subtitle: Text(exercise.muscleGroup ?? ''),
                                    leading: CircleAvatar(
                                      backgroundColor: _getMuscleGroupColor(
                                          exercise.muscleGroup ?? 'Other'),
                                      child: const Icon(
                                        Icons.fitness_center,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    onTap: () {
                                      this.setState(() {
                                        _selectedExerciseId =
                                            exercise.exerciseId.toString();
                                        _selectedExerciseName = exercise.name;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  /// Returns a color for the muscle group to make UI more visually engaging
  Color _getMuscleGroupColor(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return Colors.blue;
      case 'Back':
        return Colors.green;
      case 'Shoulders':
        return Colors.purple;
      case 'Biceps':
        return Colors.teal;
      case 'Triceps':
        return Colors.indigo;
      case 'Legs':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strength Goal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal icon and title
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: const Icon(
                    Icons.fitness_center_outlined,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strength Goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Set targets for specific exercises',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Exercise selection
            Text(
              'Select Exercise',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectExercise,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedExerciseName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Unit selector
            Row(
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
            const SizedBox(height: 24),

            // Current weight
            Text(
              'Current Weight',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentWeightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText:
                    _isMetric ? 'Enter weight in kg' : 'Enter weight in lbs',
                suffixText: _isMetric ? 'kg' : 'lbs',
              ),
            ),
            const SizedBox(height: 24),

            // Target weight
            Text(
              'Target Weight',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetWeightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText:
                    _isMetric ? 'Enter target in kg' : 'Enter target in lbs',
                suffixText: _isMetric ? 'kg' : 'lbs',
              ),
            ),
            const SizedBox(height: 24),

            // Target date
            Text(
              'Target Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && picked != _targetDate) {
                  setState(() {
                    _targetDate = picked;
                  });
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(_targetDate),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Create goal button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedExerciseId == null
                    ? null
                    : () {
                        // Validate inputs
                        if (_currentWeightController.text.isEmpty ||
                            _targetWeightController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter both current and target weights')),
                          );
                          return;
                        }

                        // Navigate to review screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GoalReviewScreen(
                              goalType: 'Strength Goal',
                              details: {
                                'exerciseId': _selectedExerciseId,
                                'exerciseName': _selectedExerciseName,
                                'currentWeight': _currentWeightController.text,
                                'targetWeight': _targetWeightController.text,
                                'targetDate': _targetDate,
                                'unit': _isMetric ? 'kg' : 'lbs',
                              },
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen for creating workout frequency goals
/// Allows users to set:
/// - Number of workouts per week
/// - Goal duration in weeks
/// Automatically calculates total workout target
class FrequencyGoalDetailsScreen extends StatefulWidget {
  const FrequencyGoalDetailsScreen({super.key});

  @override
  State<FrequencyGoalDetailsScreen> createState() =>
      _FrequencyGoalDetailsScreenState();
}

class _FrequencyGoalDetailsScreenState
    extends State<FrequencyGoalDetailsScreen> {
  // Default values for frequency goals
  int _workoutsPerWeek = 3;
  int _goalDuration = 4; // weeks

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequency Goal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal icon and title
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frequency Goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Set a target number of workouts',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Workouts per week
            Text(
              'Workouts Per Week',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_workoutsPerWeek workouts',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _workoutsPerWeek > 1
                          ? () {
                              setState(() {
                                _workoutsPerWeek--;
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: _workoutsPerWeek > 1
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ),
                    IconButton(
                      onPressed: _workoutsPerWeek < 7
                          ? () {
                              setState(() {
                                _workoutsPerWeek++;
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: _workoutsPerWeek < 7
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _workoutsPerWeek.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$_workoutsPerWeek',
              onChanged: (double value) {
                setState(() {
                  _workoutsPerWeek = value.toInt();
                });
              },
            ),
            const SizedBox(height: 32),

            // Goal duration
            Text(
              'Goal Duration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_goalDuration weeks',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _goalDuration > 1
                          ? () {
                              setState(() {
                                _goalDuration--;
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: _goalDuration > 1
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ),
                    IconButton(
                      onPressed: _goalDuration < 12
                          ? () {
                              setState(() {
                                _goalDuration++;
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: _goalDuration < 12
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _goalDuration.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '$_goalDuration',
              onChanged: (double value) {
                setState(() {
                  _goalDuration = value.toInt();
                });
              },
            ),
            const SizedBox(height: 40),

            // Create goal button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Calculate end date
                  final endDate =
                      DateTime.now().add(Duration(days: _goalDuration * 7));

                  // Navigate to review screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalReviewScreen(
                        goalType: 'Frequency Goal',
                        details: {
                          'workoutsPerWeek': _workoutsPerWeek,
                          'duration': _goalDuration,
                          'endDate': endDate,
                          'totalWorkouts': _workoutsPerWeek * _goalDuration,
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Final screen in the goal creation flow
/// Shows summary of goal details before saving
/// Handles the actual creation of goals in the database
class GoalReviewScreen extends StatefulWidget {
  final String goalType;
  final Map<String, dynamic> details;

  const GoalReviewScreen({
    super.key,
    required this.goalType,
    required this.details,
  });

  @override
  State<GoalReviewScreen> createState() => _GoalReviewScreenState();
}

class _GoalReviewScreenState extends State<GoalReviewScreen> {
  bool _isSaving = false;

  /// Saves the goal to the database based on its type
  /// Handles different goal types with appropriate service calls
  Future<void> _saveGoal() async {
    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.goalType == 'Weight Goal') {
        // Implement weight goal creation
        final currentWeight = double.parse(widget.details['currentWeight']);
        final targetWeight = double.parse(widget.details['targetWeight']);
        final targetDate = widget.details['targetDate'] as DateTime;

        // Create the weight goal
        await GoalService.instance.createWeightGoal(
          currentWeight: currentWeight,
          targetWeight: targetWeight,
          targetDate: targetDate,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight goal created successfully!')),
        );
      } else if (widget.goalType == 'Strength Goal') {
        final exerciseId = int.parse(widget.details['exerciseId'] as String);
        final currentWeight = double.parse(widget.details['currentWeight']);
        final targetWeight = double.parse(widget.details['targetWeight']);
        final targetDate = widget.details['targetDate'] as DateTime;

        // Create the strength goal
        await GoalService.instance.createStrengthGoal(
          exerciseId: exerciseId,
          currentWeight: currentWeight,
          targetWeight: targetWeight,
          targetDate: targetDate,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Strength goal created successfully!')),
        );
      } else if (widget.goalType == 'Frequency Goal') {
        final totalWorkouts = widget.details['totalWorkouts'] as int;
        final endDate = widget.details['endDate'] as DateTime;

        // Create the frequency goal
        await GoalService.instance.createFrequencyGoal(
          targetWorkouts: totalWorkouts,
          endDate: endDate,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Frequency goal created successfully!')),
        );
      }

      // Navigate back to goals page
      if (!mounted) return;
      Navigator.of(context)
          .pop(); // Pop back to the exercise/frequency selection
      Navigator.of(context).pop(); // Pop back to the goal type selection
      Navigator.of(context).pop(); // Pop back to the Goals page
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating goal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Creates a row displaying a goal detail label and value
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Calculates the number of days between now and the target date
  int _calculateDays(DateTime targetDate) {
    return targetDate.difference(DateTime.now()).inDays;
  }

  /// Returns appropriate color for different goal types
  /// Maintains consistent color coding throughout the app
  Color _getGoalColor(String goalType) {
    switch (goalType) {
      case 'Weight Goal':
        return Colors.blue;
      case 'Strength Goal':
        return Colors.orange;
      case 'Frequency Goal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Returns appropriate icon for different goal types
  /// Maintains consistent visual representation
  IconData _getGoalIcon(String goalType) {
    switch (goalType) {
      case 'Weight Goal':
        return Icons.monitor_weight_outlined;
      case 'Strength Goal':
        return Icons.fitness_center_outlined;
      case 'Frequency Goal':
        return Icons.calendar_today_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Goal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Goal Summary',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your goal details before saving',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),

            // Goal details card
            Card(
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
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              _getGoalColor(widget.goalType).withOpacity(0.1),
                          child: Icon(
                            _getGoalIcon(widget.goalType),
                            color: _getGoalColor(widget.goalType),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.goalType,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32, thickness: 1),

                    // Display different details based on goal type
                    if (widget.goalType == 'Weight Goal') ...[
                      _buildDetailRow('Current Weight',
                          '${widget.details['currentWeight']} ${widget.details['unit']}'),
                      const SizedBox(height: 12),
                      _buildDetailRow('Target Weight',
                          '${widget.details['targetWeight']} ${widget.details['unit']}'),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                          'Target Date',
                          DateFormat('MMMM d, yyyy')
                              .format(widget.details['targetDate'])),
                      const SizedBox(height: 12),
                      _buildDetailRow('Duration',
                          '${_calculateDays(widget.details['targetDate'])} days'),
                    ] else if (widget.goalType == 'Strength Goal') ...[
                      _buildDetailRow(
                          'Exercise', widget.details['exerciseName']),
                      const SizedBox(height: 12),
                      _buildDetailRow('Current Weight',
                          '${widget.details['currentWeight']} ${widget.details['unit']}'),
                      const SizedBox(height: 12),
                      _buildDetailRow('Target Weight',
                          '${widget.details['targetWeight']} ${widget.details['unit']}'),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                          'Target Date',
                          DateFormat('MMMM d, yyyy')
                              .format(widget.details['targetDate'])),
                      const SizedBox(height: 12),
                      _buildDetailRow('Duration',
                          '${_calculateDays(widget.details['targetDate'])} days'),
                    ] else if (widget.goalType == 'Frequency Goal') ...[
                      _buildDetailRow('Workouts Per Week',
                          '${widget.details['workoutsPerWeek']} workouts'),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                          'Duration', '${widget.details['duration']} weeks'),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                          'End Date',
                          DateFormat('MMMM d, yyyy')
                              .format(widget.details['endDate'])),
                      const SizedBox(height: 12),
                      _buildDetailRow('Total Workouts',
                          '${widget.details['totalWorkouts']} workouts'),
                    ],
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Save goal button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Goal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Edit button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Edit Goal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
