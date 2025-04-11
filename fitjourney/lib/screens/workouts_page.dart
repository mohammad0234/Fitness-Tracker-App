import 'package:fitjourney/screens/workout_comparison_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/screens/workout_detail_screen.dart';
import 'log_workout_flow.dart';
import 'package:intl/intl.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  final WorkoutService _workoutService = WorkoutService.instance;

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

  List<Workout> _workouts = [];
  List<Map<String, dynamic>> _workoutDetails = [];
  bool _isLoading = true;

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
    }
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Workouts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WorkoutComparisonSelectionScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.compare_arrows, size: 18),
                        label: const Text('Compare'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                        ),
                      ),
                      // Filter button
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: _showFilterDialog,
                        tooltip: 'Filter workouts',
                      ),
                      // Refresh button
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadWorkouts,
                        tooltip: 'Refresh workouts',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter chips/tags display
              Row(
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

              // Filter chips
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
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
              const SizedBox(height: 24),

              // Workout history - grouped by date
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filterWorkouts().isEmpty
                        ? _buildEmptyState()
                        : ListView(
                            children: _buildWorkoutGroups(),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogWorkoutFlow()),
          ).then((_) =>
              _loadWorkouts()); // Reload workouts when returning from logging
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
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
            'Tap the + button to log your first workout',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Filter workouts based on selected filters
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

  List<Widget> _buildWorkoutGroups() {
    // Group workouts by date
    Map<String, List<Map<String, dynamic>>> groupedWorkouts = {};

    final filteredWorkouts = _filterWorkouts();

    for (var workoutDetail in filteredWorkouts) {
      final workout = workoutDetail['workout'] as Workout;
      final date = workout.date;

      final String groupKey = _isToday(date)
          ? 'TODAY'
          : _isYesterday(date)
              ? 'YESTERDAY'
              : DateFormat('MMMM d, yyyy').format(date);

      if (!groupedWorkouts.containsKey(groupKey)) {
        groupedWorkouts[groupKey] = [];
      }

      groupedWorkouts[groupKey]!.add(workoutDetail);
    }

    // Build UI for each group
    List<Widget> groups = [];

    // Sort the keys to ensure dates are in order (most recent first)
    final sortedKeys = groupedWorkouts.keys.toList()
      ..sort((a, b) {
        if (a == 'TODAY') return -1;
        if (b == 'TODAY') return 1;
        if (a == 'YESTERDAY') return -1;
        if (b == 'YESTERDAY') return 1;

        // Parse the dates for comparison
        final dateA = a == 'TODAY'
            ? DateTime.now()
            : a == 'YESTERDAY'
                ? DateTime.now().subtract(const Duration(days: 1))
                : DateFormat('MMMM d, yyyy').parse(a);

        final dateB = b == 'TODAY'
            ? DateTime.now()
            : b == 'YESTERDAY'
                ? DateTime.now().subtract(const Duration(days: 1))
                : DateFormat('MMMM d, yyyy').parse(b);

        return dateB.compareTo(dateA); // Most recent first
      });

    for (var dateKey in sortedKeys) {
      final workouts = groupedWorkouts[dateKey]!;

      if (workouts.isNotEmpty) {
        groups.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              dateKey,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        );

        workouts.forEach((workoutDetail) {
          groups.add(_buildWorkoutCard(workoutDetail));
        });

        groups.add(const SizedBox(height: 16));
      }
    }

    return groups;
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workoutDetail) {
    final workout = workoutDetail['workout'] as Workout;
    final exerciseCount = workoutDetail['exerciseCount'] as int;
    final muscleGroups = workoutDetail['muscleGroups'] as List<String>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to workout details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  WorkoutDetailScreen(workoutId: workout.workoutId!),
            ),
          ).then((result) {
            // If workout was deleted, refresh the list
            if (result == true) {
              _loadWorkouts();
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
              Text(
                '$exerciseCount exercises',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
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
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
