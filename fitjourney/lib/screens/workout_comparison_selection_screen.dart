// lib/screens/workout_comparison_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/screens/workout_comparison_screen.dart';

/// WorkoutComparisonSelectionScreen provides a user interface for selecting two workouts to compare
/// Features include:
/// - Two-step workout selection process
/// - Filtering workouts by type and date range
/// - Visual workout cards with muscle group information
/// - Progress tracking through selection steps
class WorkoutComparisonSelectionScreen extends StatefulWidget {
  const WorkoutComparisonSelectionScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutComparisonSelectionScreen> createState() =>
      _WorkoutComparisonSelectionScreenState();
}

/// State management for WorkoutComparisonSelectionScreen
/// Handles:
/// - Loading and filtering workouts
/// - Selection process tracking
/// - Filter management
/// - UI state updates
class _WorkoutComparisonSelectionScreenState
    extends State<WorkoutComparisonSelectionScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _workoutDetails = [];

  // Filter options
  String _selectedFilter = 'All Workouts';
  final List<String> _filterOptions = [
    'All Workouts',
    'Upper Body',
    'Lower Body'
  ];

  // Date filter
  String _dateFilter = 'All Time';
  final List<String> _dateFilterOptions = [
    'All Time',
    'This Week',
    'This Month',
    'Last 3 Months'
  ];

  // Selection state
  Workout? _firstWorkout;
  Workout? _secondWorkout;
  int _selectionStep =
      1; // 1 = selecting first workout, 2 = selecting second workout

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  /// Loads all user workouts and their details
  /// Includes exercise counts and muscle groups for each workout
  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all workouts for the current user
      final workouts = await _workoutService.getUserWorkouts();

      // Get detailed information for each workout
      final workoutDetails = await Future.wait(
        workouts.map((workout) async {
          try {
            // Get details including exercises
            final details =
                await _workoutService.getWorkoutDetails(workout.workoutId!);

            // Calculate total exercises
            final exerciseCount = (details['exercises'] as List).length;

            // Extract muscle groups for this workout
            final muscleGroups = (details['exercises'] as List)
                .map((e) => e['muscle_group'] as String)
                .toSet()
                .toList();

            return {
              'workout': workout,
              'exerciseCount': exerciseCount,
              'muscleGroups': muscleGroups,
            };
          } catch (e) {
            print('Error loading workout details: $e');
            return {
              'workout': workout,
              'exerciseCount': 0,
              'muscleGroups': <String>[],
            };
          }
        }),
      );

      setState(() {
        _workoutDetails = workoutDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workouts: $e');
      setState(() {
        _workoutDetails = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workouts: $e')),
        );
      }
    }
  }

  /// Handles workout selection process
  /// Manages the two-step selection and navigation to comparison screen
  void _selectWorkout(Workout workout) {
    setState(() {
      if (_selectionStep == 1) {
        _firstWorkout = workout;
        _selectionStep = 2;
      } else {
        _secondWorkout = workout;
        // Once both workouts are selected, we can navigate to the comparison screen
        // But we'll add a brief delay to let the user see the selection
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutComparisonScreen(
                  firstWorkoutId: _firstWorkout!.workoutId!,
                  secondWorkoutId: _secondWorkout!.workoutId!,
                ),
              ),
            ).then((_) {
              // Reset selection when returning from comparison
              setState(() {
                _firstWorkout = null;
                _secondWorkout = null;
                _selectionStep = 1;
              });
            });
          }
        });
      }
    });
  }

  /// Resets the workout selection process
  /// Clears both selected workouts and returns to step 1
  void _resetSelection() {
    setState(() {
      _firstWorkout = null;
      _secondWorkout = null;
      _selectionStep = 1;
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Workouts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date filter
                  const Text(
                    'Date Range',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _dateFilterOptions.map((option) {
                      return ChoiceChip(
                        label: Text(option),
                        selected: _dateFilter == option,
                        onSelected: (selected) {
                          setModalState(() {
                            _dateFilter = option;
                          });
                          setState(() {
                            _dateFilter = option;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Muscle group filter
                  const Text(
                    'Workout Type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _filterOptions.map((option) {
                      return ChoiceChip(
                        label: Text(option),
                        selected: _selectedFilter == option,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedFilter = option;
                          });
                          setState(() {
                            _selectedFilter = option;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter workouts',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkouts,
            tooltip: 'Refresh workouts',
          ),
        ],
      ),
      body: Column(
        children: [
          // Selection status bar
          _buildSelectionStatusBar(),

          // Filter chips/tags display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                if (_selectedFilter != 'All Workouts' ||
                    _dateFilter != 'All Time')
                  const Text(
                    'Active Filters:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(width: 8),
                if (_selectedFilter != 'All Workouts')
                  Chip(
                    label: Text(_selectedFilter),
                    backgroundColor: Colors.blue.shade100,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedFilter = 'All Workouts';
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(width: 4),
                if (_dateFilter != 'All Time')
                  Chip(
                    label: Text(_dateFilter),
                    backgroundColor: Colors.blue.shade100,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _dateFilter = 'All Time';
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),

          // Workout list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filterWorkouts().isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filterWorkouts().length,
                        itemBuilder: (context, index) {
                          final workoutDetail = _filterWorkouts()[index];
                          return _buildWorkoutCard(workoutDetail);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionStatusBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First step button using full width
          _buildSelectionStep(1, 'Select first workout', _firstWorkout != null),

          // Arrow in the center
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: Icon(
                Icons.arrow_downward,
                color: Colors.grey,
                size: 28,
              ),
            ),
          ),

          // Second step button using full width
          _buildSelectionStep(
              2, 'Select second workout', _secondWorkout != null),

          if (_firstWorkout != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSelectedWorkoutChip(_firstWorkout!),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _secondWorkout != null
                      ? _buildSelectedWorkoutChip(_secondWorkout!)
                      : const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_firstWorkout != null && _secondWorkout == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Now select a second workout to compare with (preferably a more recent workout)',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (_firstWorkout == null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: For meaningful comparisons, first select an earlier workout, then a more recent one, and make sure to choose the same exercise in both. Filter workouts if you want to compare specific workout types or time periods.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_firstWorkout != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton.icon(
                onPressed: _resetSelection,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset Selection'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(50, 36),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionStep(int step, String label, bool isCompleted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: _selectionStep == step
            ? Colors.blue
            : isCompleted
                ? Colors.green
                : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.green)
                  : Text(
                      step.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _selectionStep == step
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedWorkoutChip(Workout workout) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Workout ${DateFormat('MM/dd').format(workout.date)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workoutDetail) {
    final workout = workoutDetail['workout'] as Workout;
    final exerciseCount = workoutDetail['exerciseCount'] as int;
    final muscleGroups = workoutDetail['muscleGroups'] as List<String>;

    final bool isFirstWorkout = _firstWorkout?.workoutId == workout.workoutId;
    final bool isSecondWorkout = _secondWorkout?.workoutId == workout.workoutId;
    final bool isSelected = isFirstWorkout || isSecondWorkout;

    // Can't select the same workout twice
    final bool isSelectable =
        !isSelected || (_selectionStep == 2 && isFirstWorkout);

    // Determine a color based on muscle groups
    Color cardColor = _getColorForWorkout(muscleGroups);

    // Determine darker shade for text
    Color darkCardColor = cardColor;
    if (cardColor == Colors.blue) {
      darkCardColor = Colors.blue.shade600;
    } else if (cardColor == Colors.green) {
      darkCardColor = Colors.green.shade600;
    } else if (cardColor == Colors.orange) {
      darkCardColor = Colors.orange.shade600;
    } else if (cardColor == Colors.purple) {
      darkCardColor = Colors.purple.shade600;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isSelectable ? () => _selectWorkout(workout) : null,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    cardColor.withOpacity(0.08),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForWorkout(muscleGroups),
                                color: darkCardColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Workout ${DateFormat('MM/dd').format(workout.date)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          DateFormat('h:mm a').format(workout.date),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 46.0),
                      child: Text(
                        exerciseCount == 1
                            ? '$exerciseCount exercise'
                            : '$exerciseCount exercises',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: muscleGroups.map((muscle) {
                        final color = _getColorForMuscleGroup(muscle);

                        // Determine darker shade for text in the chip
                        Color darkColor = color;
                        if (color == Colors.blue) {
                          darkColor = Colors.blue.shade700;
                        } else if (color == Colors.green) {
                          darkColor = Colors.green.shade700;
                        } else if (color == Colors.cyan) {
                          darkColor = Colors.cyan.shade700;
                        } else if (color == Colors.teal) {
                          darkColor = Colors.teal.shade700;
                        } else if (color == Colors.orange) {
                          darkColor = Colors.orange.shade700;
                        } else if (color == Colors.purple) {
                          darkColor = Colors.purple.shade700;
                        } else {
                          darkColor = Colors.blueGrey.shade700;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          child: Chip(
                            avatar: CircleAvatar(
                              radius: 9,
                              backgroundColor: color.withOpacity(0.15),
                              child: Icon(
                                _getIconForMuscleGroup(muscle),
                                size: 11,
                                color: darkColor,
                              ),
                            ),
                            label: Text(
                              muscle,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            backgroundColor: color.withOpacity(0.08),
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFirstWorkout ? 'First' : 'Second',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to determine card color based on muscle groups
  Color _getColorForWorkout(List<String> muscleGroups) {
    if (muscleGroups.isEmpty) return Colors.blue;

    // Check for muscle group categories
    if (muscleGroups
        .any((group) => ['Chest', 'Shoulders', 'Triceps'].contains(group))) {
      return Colors.blue;
    } else if (muscleGroups
        .any((group) => ['Back', 'Biceps'].contains(group))) {
      return Colors.green;
    } else if (muscleGroups
        .any((group) => ['Legs', 'Glutes', 'Calves'].contains(group))) {
      return Colors.orange;
    } else if (muscleGroups.any((group) => ['Core', 'Abs'].contains(group))) {
      return Colors.purple;
    }

    // Default color
    return Colors.blue;
  }

  // Helper method to get icon for workout
  IconData _getIconForWorkout(List<String> muscleGroups) {
    if (muscleGroups.isEmpty) return Icons.fitness_center;

    if (muscleGroups
        .any((group) => ['Chest', 'Shoulders', 'Triceps'].contains(group))) {
      return Icons.fitness_center; // Dumbbell for upper body push
    } else if (muscleGroups
        .any((group) => ['Back', 'Biceps'].contains(group))) {
      return Icons.fitness_center; // Dumbbell for upper body pull
    } else if (muscleGroups
        .any((group) => ['Legs', 'Glutes', 'Calves'].contains(group))) {
      return Icons.directions_run; // Running for lower body
    } else if (muscleGroups.any((group) => ['Core', 'Abs'].contains(group))) {
      return Icons.fitness_center; // Dumbbell for core
    }

    return Icons.fitness_center; // Default to dumbbell
  }

  // Helper method to get color for specific muscle group
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

  // Helper method to get icon for specific muscle group
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
        return Icons.directions_run; // Running for legs
      case 'Calves':
        return Icons.directions_run; // Running for calves
      case 'Glutes':
        return Icons.directions_run; // Running for glutes
      case 'Core':
      case 'Abs':
        return Icons.fitness_center; // Dumbbell for core/abs
      default:
        return Icons.fitness_center; // Default to dumbbell
    }
  }

  List<Map<String, dynamic>> _filterWorkouts() {
    if (_workoutDetails.isEmpty) return [];

    return _workoutDetails.where((workoutDetail) {
      final workout = workoutDetail['workout'] as Workout;
      final muscleGroups = workoutDetail['muscleGroups'] as List<String>;

      // Apply date filter
      bool passesDateFilter = true;
      if (_dateFilter == 'This Week') {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        passesDateFilter =
            workout.date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
      } else if (_dateFilter == 'This Month') {
        final now = DateTime.now();
        passesDateFilter =
            workout.date.month == now.month && workout.date.year == now.year;
      } else if (_dateFilter == 'Last 3 Months') {
        final threeMonthsAgo =
            DateTime.now().subtract(const Duration(days: 90));
        passesDateFilter = workout.date.isAfter(threeMonthsAgo);
      }

      // Apply type filter
      bool passesTypeFilter = _selectedFilter == 'All Workouts';
      if (_selectedFilter == 'Upper Body') {
        passesTypeFilter = muscleGroups.any((group) => [
              'Chest',
              'Back',
              'Shoulders',
              'Biceps',
              'Triceps'
            ].contains(group));
      } else if (_selectedFilter == 'Lower Body') {
        passesTypeFilter = muscleGroups
            .any((group) => ['Legs', 'Calves', 'Glutes'].contains(group));
      }

      return passesDateFilter && passesTypeFilter;
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No workouts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dateFilter != 'All Time' || _selectedFilter != 'All Workouts'
                ? 'Try adjusting your filters'
                : 'Log workouts to compare them',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
