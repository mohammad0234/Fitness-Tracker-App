// lib/screens/calendar_streak_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/daily_log.dart';
import 'package:fitjourney/database_models/streak.dart';
import 'package:fitjourney/database_models/workout.dart';
import 'package:fitjourney/screens/workout_detail_screen.dart';
import 'package:fitjourney/services/sync_service.dart';
//import 'package:fitjourney/utils/date_utils.dart';

class CalendarStreakScreen extends StatefulWidget {
  const CalendarStreakScreen({Key? key}) : super(key: key);

  @override
  State<CalendarStreakScreen> createState() => _CalendarStreakScreenState();
}

class _CalendarStreakScreenState extends State<CalendarStreakScreen> {
  final StreakService _streakService = StreakService.instance;
  final WorkoutService _workoutService = WorkoutService.instance;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<DailyLog>> _events = {};
  List<DailyLog> _dailyLogs = [];
  Streak? _streak;
  bool _isLoading = true;

  // For selected day workouts
  List<Workout> _selectedDayWorkouts = [];
  bool _isLoadingWorkouts = false;
  // Add this to store workout details
  List<Map<String, dynamic>> _workoutDetails = [];

  // Stream subscription for sync events
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Add listener for sync events to refresh calendar
    _syncSubscription = SyncService.instance.syncStatusStream.listen((status) {
      if (status.lastSuccess != null && !status.isInProgress && mounted) {
        // Reload data after successful sync
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    // Cancel the sync subscription to prevent memory leaks
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadStreak();
    await _loadActivities();
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await _streakService.getUserStreak();

      if (mounted) {
        setState(() {
          _streak = streak;
        });
      }
    } catch (e) {
      print('Error loading streak data: $e');
    }
  }

  Future<void> _loadActivities() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate date range for past 6 months
      final today = DateTime.now();
      final sixMonthsAgo = DateTime(today.year, today.month - 6, today.day);

      // Load daily logs
      final logs = await _streakService.getDailyLogHistory(sixMonthsAgo, today);

      // Process logs into a format suitable for the calendar
      final events = <DateTime, List<DailyLog>>{};

      for (var log in logs) {
        // Normalize the date to remove time component
        final date = DateTime(log.date.year, log.date.month, log.date.day);

        if (events[date] == null) {
          events[date] = [];
        }
        events[date]!.add(log);
      }

      if (mounted) {
        setState(() {
          _dailyLogs = logs;
          _events = events;
          _isLoading = false;

          // If no day is selected yet, select today
          if (_selectedDay == null) {
            _selectedDay = today;
            // Load workouts for today initially
            _loadWorkoutsForSelectedDay(today);
          }
        });
      }
    } catch (e) {
      print('Error loading calendar data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load workouts for a selected day
  Future<void> _loadWorkoutsForSelectedDay(DateTime date) async {
    if (date == null) return;
    if (!mounted) return;

    setState(() {
      _isLoadingWorkouts = true;
      // Initialize workouts and details as empty to prevent rendering issues
      _selectedDayWorkouts = [];
      _workoutDetails = [];
    });

    try {
      // Get workouts for this specific date
      final workouts = await _getWorkoutsForDate(date);

      // Clear previous workout details
      List<Map<String, dynamic>> workoutDetails = [];

      // If we have workouts, fetch details for each
      if (workouts.isNotEmpty) {
        for (var workout in workouts) {
          try {
            final details =
                await _workoutService.getWorkoutDetails(workout.workoutId!);

            // Extract exercise count and muscle groups
            final exerciseCount = (details['exercises'] as List).length;
            final exercises = details['exercises'] as List;
            final muscleGroups = exercises
                .map((e) => e['muscle_group'] as String)
                .toSet()
                .toList();

            workoutDetails.add({
              'workout': workout,
              'details': details,
              'exerciseCount': exerciseCount,
              'exercises': exercises,
              'muscleGroups': muscleGroups,
            });
          } catch (e) {
            print(
                'Error fetching details for workout ${workout.workoutId}: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _selectedDayWorkouts = workouts;
          _workoutDetails = workoutDetails;
          _isLoadingWorkouts = false;
        });
      }
    } catch (e) {
      print('Error loading workouts for date: $e');
      if (mounted) {
        setState(() {
          _selectedDayWorkouts = [];
          _workoutDetails = [];
          _isLoadingWorkouts = false;
        });
      }
    }
  }

  // Helper method to get workouts for a specific date
  Future<List<Workout>> _getWorkoutsForDate(DateTime date) async {
    // When you need the DateTime object
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Check if the selected day has a workout activity
    final activities = _events[normalizedDate] ?? [];
    bool hasWorkout =
        activities.any((activity) => activity.activityType == 'workout');

    if (!hasWorkout) {
      return []; // No workouts on this day
    }

    // Use WorkoutService to get workouts for this date
    return await _workoutService.getWorkoutsForDate(date);
  }

  // Determine the event color based on activity type
  Color _getEventColor(List<DailyLog>? logs) {
    if (logs == null || logs.isEmpty) {
      return Colors.grey.shade200; // No activity
    }

    // Prioritize workout over rest if both exist on the same day
    for (var log in logs) {
      if (log.activityType == 'workout') {
        return Colors.blue; // Workout day
      }
    }

    return Colors.green.shade300; // Rest day
  }

  // Check if a date is part of a milestone streak
  bool _isStreakMilestone(DateTime day) {
    // Create a normalized date for comparison
    final normalizedDate = DateTime(day.year, day.month, day.day);

    // Find this date in the daily logs
    for (var log in _dailyLogs) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);

      // Check if dates match
      if (logDate == normalizedDate) {
        // Get all consecutive days from this date backward
        int consecutiveDays = 0;
        DateTime checkDate = normalizedDate;

        while (true) {
          // Check if this date has an activity
          bool hasActivity = false;
          for (var checkLog in _dailyLogs) {
            final checkLogDate = DateTime(
                checkLog.date.year, checkLog.date.month, checkLog.date.day);
            if (checkLogDate == checkDate) {
              hasActivity = true;
              break;
            }
          }

          if (!hasActivity) break;

          consecutiveDays++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }

        // Check if this is a 7-day or 30-day milestone
        return consecutiveDays == 7 || consecutiveDays == 30;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // Add SafeArea to respect system UI boundaries
              child: SingleChildScrollView(
                // Make the whole screen scrollable
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: 20), // Add extra bottom padding
                  child: Column(
                    children: [
                      // Calendar header with streak info
                      _buildStreakHeader(),

                      // Month navigation
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 8, bottom: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _focusedDay = DateTime(_focusedDay.year,
                                      _focusedDay.month - 1, 1);
                                });
                              },
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_focusedDay),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                final now = DateTime.now();
                                // Don't allow navigating to future months
                                if (_focusedDay.year < now.year ||
                                    (_focusedDay.year == now.year &&
                                        _focusedDay.month < now.month)) {
                                  setState(() {
                                    _focusedDay = DateTime(_focusedDay.year,
                                        _focusedDay.month + 1, 1);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // Format selector - with reduced vertical padding
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: SegmentedButton<CalendarFormat>(
                          segments: const [
                            ButtonSegment<CalendarFormat>(
                              value: CalendarFormat.week,
                              label: Text('Week'),
                            ),
                            ButtonSegment<CalendarFormat>(
                              value: CalendarFormat.twoWeeks,
                              label: Text('2 weeks'),
                            ),
                            ButtonSegment<CalendarFormat>(
                              value: CalendarFormat.month,
                              label: Text('Month'),
                            ),
                          ],
                          selected: <CalendarFormat>{_calendarFormat},
                          onSelectionChanged: (Set<CalendarFormat> selection) {
                            setState(() {
                              _calendarFormat = selection.first;
                            });
                          },
                        ),
                      ),

                      // Calendar view - reduce vertical padding to save space
                      TableCalendar(
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.now().add(const Duration(days: 1)),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });

                          // Load workouts for the selected day
                          _loadWorkoutsForSelectedDay(selectedDay);
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                        eventLoader: (day) {
                          // Normalize the date to remove time
                          final normalized =
                              DateTime(day.year, day.month, day.day);
                          return _events[normalized] ?? [];
                        },
                        headerVisible: false, // Hide default header
                        daysOfWeekHeight: 20, // Reduce height of day headers
                        rowHeight: 45, // Adjust row height to save space
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: true,
                          markersMaxCount: 1,
                          markersAnchor: 0.9,
                          markerDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          // Reduce padding to save space
                          cellPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          cellMargin: EdgeInsets.zero,
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return null;

                            final isMilestone = _isStreakMilestone(date);

                            // Return a stack with the date number on top of the activity circle
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Activity circle
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _getEventColor(
                                        events as List<DailyLog>?),
                                    shape: BoxShape.circle,
                                    border: isMilestone
                                        ? Border.all(
                                            color: Colors.orange, width: 2)
                                        : null,
                                  ),
                                ),
                                // Date number (in white for visibility)
                                Text(
                                  date.day.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                // Milestone star (if applicable)
                                if (isMilestone)
                                  const Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.orange,
                                      size: 12,
                                    ),
                                  ),
                              ],
                            );
                          },
                          // Override the default day cell builder to hide the default day number
                          defaultBuilder: (context, day, focusedDay) {
                            // Only show the default text for days without activity
                            final events = _events[
                                    DateTime(day.year, day.month, day.day)] ??
                                [];
                            if (events.isEmpty) {
                              return Container(
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              );
                            }
                            return Container(); // Return empty container, we'll show the date in our marker
                          },
                        ),
                      ),

                      // Legend with reduced vertical padding
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem('Workout Day', Colors.blue),
                            const SizedBox(width: 16),
                            _buildLegendItem('Rest Day', Colors.green.shade300),
                            const SizedBox(width: 16),
                            _buildLegendItem(
                                'No Activity', Colors.grey.shade200),
                          ],
                        ),
                      ),

                      // Selected day details
                      if (_selectedDay != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: _buildSelectedDayInfo(),
                        ),

                      // Workout list for selected day (NEW)
                      if (_selectedDayWorkouts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Workouts on ${DateFormat('MMM d').format(_selectedDay!)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._buildWorkoutsList(),
                            ],
                          ),
                        ),

                      // Loading indicator for workouts
                      if (_isLoadingWorkouts)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // NEW: Build workout cards
  List<Widget> _buildWorkoutsList() {
    if (_selectedDayWorkouts.isEmpty || _workoutDetails.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('No workouts found on this day'),
          ),
        )
      ];
    }

    return List.generate(_workoutDetails.length, (index) {
      final workoutData = _workoutDetails[index];
      final workout = workoutData['workout'] as Workout;
      final exerciseCount = workoutData['exerciseCount'] as int;
      final exercises = workoutData['exercises'] as List;
      final muscleGroups = workoutData['muscleGroups'] as List<String>;

      // Determine the primary muscle group for display
      String primaryType = 'Workout';
      if (muscleGroups.isNotEmpty) {
        // Check for common groupings
        if (muscleGroups.any((group) => [
              'Chest',
              'Back',
              'Shoulders',
              'Biceps',
              'Triceps'
            ].contains(group))) {
          primaryType = 'Upper Body';
        } else if (muscleGroups
            .any((group) => ['Legs', 'Calves', 'Glutes'].contains(group))) {
          primaryType = 'Lower Body';
        } else {
          primaryType = muscleGroups.first;
        }
      }

      // Determine a color based on muscle groups
      Color cardColor = _getWorkoutColor(muscleGroups);

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
        margin: const EdgeInsets.only(bottom: 12),
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
            ).then((_) {
              // Refresh data when returning from detail screen
              if (_selectedDay != null) {
                _loadWorkoutsForSelectedDay(_selectedDay!);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity, // Set explicit width
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getWorkoutIcon(muscleGroups),
                                color: darkCardColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                workout.notes ?? primaryType,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                  const SizedBox(height: 12),

                  // Exercise list with chips
                  if (exercises.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...exercises.map((exercise) {
                            final exerciseName = exercise['name'] as String;
                            final muscleGroup =
                                exercise['muscle_group'] as String;
                            final exerciseSets = exercise['sets'] as List;

                            // Get the max weight if available
                            double? maxWeight;
                            if (exerciseSets.isNotEmpty) {
                              try {
                                maxWeight = exerciseSets
                                    .map((set) =>
                                        double.tryParse(
                                            set['weight']?.toString() ?? '0') ??
                                        0.0)
                                    .reduce((max, weight) =>
                                        weight > max ? weight : max);
                              } catch (e) {
                                maxWeight = 0.0;
                              }
                            }

                            final color = _getMuscleGroupColor(muscleGroup);

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

                            // Truncate exercise name if too long
                            String displayName = exerciseName;
                            if (displayName.length > 15) {
                              displayName =
                                  '${displayName.substring(0, 13)}...';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Chip(
                                avatar: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Icon(
                                    _getMuscleGroupIcon(muscleGroup),
                                    size: 12,
                                    color: darkColor,
                                  ),
                                ),
                                label: Text(
                                  maxWeight != null && maxWeight > 0
                                      ? '$displayName (${maxWeight.toStringAsFixed(1)}kg)'
                                      : displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                backgroundColor: color.withOpacity(0.08),
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 0),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  // Helper methods from the home page
  // Helper method to determine card color based on muscle groups
  Color _getWorkoutColor(List<String> muscleGroups) {
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
  IconData _getWorkoutIcon(List<String> muscleGroups) {
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
  Color _getMuscleGroupColor(String muscleGroup) {
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
  IconData _getMuscleGroupIcon(String muscleGroup) {
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

  Widget _buildStreakHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                'Current Streak',
                '${_streak?.currentStreak ?? 0}',
                Icons.local_fire_department,
                Colors.orange,
              ),
              _buildStatCard(
                'Longest Streak',
                '${_streak?.longestStreak ?? 0}',
                Icons.emoji_events,
                Colors.amber,
              ),
              _buildStatCard(
                'This Month',
                _calculateMonthlyActivity(),
                Icons.calendar_today,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Add a Deep Refresh button
          TextButton.icon(
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Force Calendar Refresh'),
            onPressed: _deepRefreshData,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.blue.shade700,
            ),
          ),
          const Text(
            'Days with a star indicate milestone streaks (7 and 30 days)',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSelectedDayInfo() {
    // Normalize the selected date to remove time
    final normalizedDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );

    // Get activities for this date
    final activities = _events[normalizedDate] ?? [];

    // Determine activity type
    String activityType = 'No Activity';
    if (activities.isNotEmpty) {
      for (var activity in activities) {
        if (activity.activityType == 'workout') {
          activityType = 'Workout';
          break;
        } else if (activity.activityType == 'rest') {
          activityType = 'Rest Day';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Activity: '),
                    Text(
                      activityType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: activityType == 'Workout'
                            ? Colors.blue
                            : activityType == 'Rest Day'
                                ? Colors.green
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isStreakMilestone(_selectedDay!))
            const Icon(Icons.star, color: Colors.orange, size: 18),
        ],
      ),
    );
  }

  String _calculateMonthlyActivity() {
    // Calculate activity for the current month
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    int activeCount = 0;
    final countedDates = <String>{};

    for (var log in _dailyLogs) {
      if (log.date.isAfter(firstDayOfMonth.subtract(const Duration(days: 1)))) {
        // Format date as string for comparison
        final dateStr = DateFormat('yyyy-MM-dd').format(log.date);

        // Count each date only once
        if (!countedDates.contains(dateStr)) {
          activeCount++;
          countedDates.add(dateStr);
        }
      }
    }

    // Calculate days in the month
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsedDays = min(now.day, daysInMonth);

    return '$activeCount/$elapsedDays';
  }

  // Method to force a deep refresh of calendar data
  Future<void> _deepRefreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Force a sync first to ensure we have the latest data
      if (SyncService.instance != null) {
        await SyncService.instance.triggerManualSync();
      }

      // Calculate date range for past 6 months
      final today = DateTime.now();
      final sixMonthsAgo = DateTime(today.year, today.month - 6, today.day);

      // Regenerate daily logs from workouts
      await _streakService.regenerateDailyLogs(sixMonthsAgo, today);

      // Now reload data normally
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar data refreshed')),
      );
    } catch (e) {
      print('Error in deep refresh: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Helper function to get minimum of two integers
int min(int a, int b) {
  return a < b ? a : b;
}
