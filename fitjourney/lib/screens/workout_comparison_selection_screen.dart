// lib/screens/workout_comparison_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/screens/workout_comparison_screen.dart';

class WorkoutComparisonSelectionScreen extends StatefulWidget {
  const WorkoutComparisonSelectionScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutComparisonSelectionScreen> createState() =>
      _WorkoutComparisonSelectionScreenState();
}

class _WorkoutComparisonSelectionScreenState
    extends State<WorkoutComparisonSelectionScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;

  bool _isLoading = true;
  List<Workout> _workouts = [];
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
        _workouts = workouts;
        _workoutDetails = workoutDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workouts: $e');
      setState(() {
        _workouts = [];
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
        title: Text(_selectionStep == 1
            ? 'Select First Workout'
            : 'Select Second Workout'),
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

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = filter == _selectedFilter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue : Colors.black,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

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
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compare Workouts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSelectionStep(
                    1, 'Select first workout', _firstWorkout != null),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSelectionStep(
                    2, 'Select second workout', _secondWorkout != null),
              ),
            ],
          ),
          if (_firstWorkout != null) ...[
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            if (_firstWorkout != null && _secondWorkout == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Now select a second workout to compare with (preferably a more recent workout)',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                            fontSize: 12,
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
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: For meaningful comparisons, select an earlier workout first, followed by a more recent one.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_firstWorkout != null)
            TextButton.icon(
              onPressed: _resetSelection,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Selection'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionStep(int step, String label, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _selectionStep == step
            ? Colors.blue
            : isCompleted
                ? Colors.green
                : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.green)
                  : Text(
                      step.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectionStep == step
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
              workout.notes ??
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        workout.notes ??
                            'Workout ${DateFormat('MM/dd').format(workout.date)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue : null,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(workout.date),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${workout.duration ?? 0} minutes',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.fitness_center,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '$exerciseCount exercises',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: muscleGroups.map((muscle) {
                      return Chip(
                        label: Text(
                          muscle,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.grey.shade100,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
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
