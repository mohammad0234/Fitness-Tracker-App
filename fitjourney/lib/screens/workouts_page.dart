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

            // Extract exercise names
            final exerciseNames = (details['exercises'] as List)
                .map((e) => e['name'] as String)
                .toList();

            return {
              'workout': workout,
              'exerciseCount': exerciseCount,
              'muscleGroups': muscleGroups,
              'exerciseNames': exerciseNames,
              'exercises': details['exercises'],
            };
          } catch (e) {
            print('Error loading workout details: $e');
            return {
              'workout': workout,
              'exerciseCount': 0,
              'muscleGroups': <String>[],
              'exerciseNames': <String>[],
              'exercises': [],
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
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
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
                    // Add padding at the bottom to ensure no overflow with keyboard
                    const SizedBox(height: 20),
                  ],
                ),
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
      body: Column(
        children: [
          // Header with filters and Compare button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First row: Filter button and filters
                Row(
                  children: [
                    // Filter icon button
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _showFilterDialog,
                      tooltip: 'Filter',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    // Date filter chip
                    Expanded(
                      flex: 1,
                      child: FilterChip(
                        label: Text(_dateFilter),
                        onSelected: (selected) {
                          _showFilterDialog();
                        },
                        avatar: const Icon(
                          Icons.calendar_today,
                          size: 16,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        checkmarkColor: Colors.blue,
                        visualDensity: VisualDensity.compact,
                        selected: _dateFilter != 'All Time',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Workout type filter chip
                    Expanded(
                      flex: 1,
                      child: FilterChip(
                        label: Text(_selectedFilter),
                        onSelected: (selected) {
                          _showFilterDialog();
                        },
                        avatar: const Icon(
                          Icons.fitness_center,
                          size: 16,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        checkmarkColor: Colors.blue,
                        visualDensity: VisualDensity.compact,
                        selected: _selectedFilter != 'All Workouts',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Second row: Compare button aligned to the left
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          // Workout history - grouped by date
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filterWorkouts().isEmpty
                    ? _buildEmptyState()
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ListView(
                          children: _buildWorkoutGroups(),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogWorkoutFlow()),
          ).then((_) => _loadWorkouts()); // Reload workouts when returning
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
        // Add padding at top of each date group except the first one
        if (groups.isNotEmpty) {
          groups.add(const SizedBox(height: 8));
        }

        groups.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0, left: 4.0),
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
      }
    }

    // Add bottom padding
    if (groups.isNotEmpty) {
      groups.add(const SizedBox(height: 16));
    }

    return groups;
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workoutDetail) {
    final workout = workoutDetail['workout'] as Workout;
    final exerciseCount = workoutDetail['exerciseCount'] as int;
    final muscleGroups = workoutDetail['muscleGroups'] as List<String>;
    final exercises = workoutDetail['exercises'] as List;

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
        child: Container(
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
                const SizedBox(height: 10),

                // Exercise list with chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...exercises.map((exercise) {
                      final exerciseName = exercise['name'] as String;
                      final muscleGroup = exercise['muscle_group'] as String;
                      final exerciseSets = exercise['sets'] as List;

                      // Get the max weight if available
                      double? maxWeight;
                      if (exerciseSets.isNotEmpty) {
                        maxWeight = exerciseSets
                            .map((set) => set.weight ?? 0.0)
                            .reduce(
                                (max, weight) => weight > max ? weight : max);
                      }

                      final color = _getColorForMuscleGroup(muscleGroup);

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
                      } else if (color == Colors.indigo) {
                        darkColor = Colors.indigo.shade700;
                      } else if (color == Colors.orange) {
                        darkColor = Colors.orange.shade700;
                      } else if (color == Colors.amber) {
                        darkColor = Colors.amber.shade800;
                      } else if (color == Colors.deepOrange) {
                        darkColor = Colors.deepOrange.shade700;
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
                              _getIconForMuscleGroup(muscleGroup),
                              size: 11,
                              color: darkColor,
                            ),
                          ),
                          label: Text(
                            maxWeight != null && maxWeight > 0
                                ? '$exerciseName (${maxWeight.toStringAsFixed(1)}kg)'
                                : exerciseName,
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
                  ],
                ),
              ],
            ),
          ),
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
    } else if (muscleGroups.any((group) => ['Legs'].contains(group))) {
      return Colors.orange;
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
    } else if (muscleGroups.any((group) => ['Legs'].contains(group))) {
      return Icons.directions_run; // Running for lower body
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
      default:
        return Icons.fitness_center; // Default to dumbbell
    }
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

  // Apply date filter to workouts

  // Apply muscle group filter to workouts
}
