// lib/screens/edit_goal_screen.dart

import 'package:flutter/material.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:intl/intl.dart';

class EditGoalScreen extends StatefulWidget {
  final int goalId;

  const EditGoalScreen({
    super.key,
    required this.goalId,
  });

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  final GoalService _goalService = GoalService.instance;
  final WorkoutService _workoutService = WorkoutService.instance;

  // Controllers
  final TextEditingController _targetValueController = TextEditingController();

  // State variables
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  Goal? _goal;
  Map<String, dynamic>? _goalDetails;
  String? _exerciseName;
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _loadGoalDetails();
  }

  @override
  void dispose() {
    _targetValueController.dispose();
    super.dispose();
  }

  Future<void> _loadGoalDetails() async {
    try {
      // Load the goal
      final goal = await _goalService.getGoalById(widget.goalId);
      if (goal == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get formatted display information
      final goalDetails = await _goalService.getGoalDisplayInfo(goal);

      // Load exercise name for strength goals
      String? exerciseName;
      if (goal.type == 'ExerciseTarget' && goal.exerciseId != null) {
        final exercise =
            await _workoutService.getExerciseById(goal.exerciseId!);
        exerciseName = exercise?.name;
      }

      // Initialize controllers
      _targetValueController.text = goal.targetValue?.toString() ?? '';

      setState(() {
        _goal = goal;
        _goalDetails = goalDetails;
        _exerciseName = exerciseName;
        _endDate = goal.endDate;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading goal for editing: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (_goal == null) return;

    // Validate inputs
    if (_targetValueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a target value')),
      );
      return;
    }

    double targetValue;
    try {
      targetValue = double.parse(_targetValueController.text);
      if (targetValue <= 0) {
        throw const FormatException('Target must be greater than zero');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target value')),
      );
      return;
    }

    if (_endDate.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be in the future')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Create updated goal
      final updatedGoal = Goal(
        goalId: _goal!.goalId,
        userId: _goal!.userId,
        type: _goal!.type,
        exerciseId: _goal!.exerciseId,
        targetValue: targetValue,
        startDate: _goal!.startDate,
        endDate: _endDate,
        achieved: _goal!.achieved,
        currentProgress: _goal!.currentProgress,
      );

      // Save to database
      await _goalService.updateGoal(updatedGoal);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal updated successfully')),
      );

      // Return to previous screen
      Navigator.pop(context, true); // Return true to indicate update
    } catch (e) {
      print('Error updating goal: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating goal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
        _hasChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true;
    }

    // Show confirmation dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Goal'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (_hasChanges) {
                _onWillPop().then((canPop) {
                  if (canPop) {
                    Navigator.of(context).pop();
                  }
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: _isLoading || _isSaving ? null : _saveGoal,
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
            : _goal == null
                ? const Center(child: Text('Goal not found'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Goal type header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  _getGoalColor(_goal!.type).withOpacity(0.1),
                              child: Icon(
                                _getGoalIcon(_goal!.type),
                                color: _getGoalColor(_goal!.type),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _goalDetails?['title'] ?? 'Edit Goal',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _goal!.type == 'ExerciseTarget'
                                        ? 'Strength Goal'
                                        : 'Workout Frequency Goal',
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
                        const SizedBox(height: 32),

                        // Goal details - different based on goal type
                        if (_goal!.type == 'ExerciseTarget') ...[
                          // Exercise information (non-editable)
                          Text(
                            'Exercise',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fitness_center,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _exerciseName ?? 'Unknown Exercise',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_goalDetails?['muscleGroup'] != null)
                                        Text(
                                          _goalDetails!['muscleGroup'],
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
                          ),
                          const SizedBox(height: 24),

                          // Current progress (non-editable)
                          Text(
                            'Current Weight',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Current Best'),
                                Text(
                                  '${_goalDetails?['current']?.toStringAsFixed(1) ?? "0"} kg',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_goal!.type == 'WorkoutFrequency') ...[
                          // Frequency goal current progress
                          Text(
                            'Current Progress',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Workouts Completed'),
                                Text(
                                  '${_goalDetails?['current']?.toInt() ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Target value (editable)
                        Text(
                          _goal!.type == 'ExerciseTarget'
                              ? 'Target Weight (kg)'
                              : 'Target Workouts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _targetValueController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: _goal!.type == 'ExerciseTarget'
                                ? 'Enter target weight in kg'
                                : 'Enter target number of workouts',
                            suffixText:
                                _goal!.type == 'ExerciseTarget' ? 'kg' : '',
                          ),
                          onChanged: (value) {
                            setState(() {
                              _hasChanges = true;
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // End date (editable)
                        Text(
                          'Goal End Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectEndDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMMM d, yyyy').format(_endDate),
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

                        const SizedBox(height: 32),

                        // Information card about editing
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'About Editing Goals',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Changing your goal target or date will not affect your current progress. Your progress percentage will be recalculated based on the new target.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  // Helper methods
  Color _getGoalColor(String goalType) {
    switch (goalType) {
      case 'ExerciseTarget':
        return Colors.orange;
      case 'WorkoutFrequency':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getGoalIcon(String goalType) {
    switch (goalType) {
      case 'ExerciseTarget':
        return Icons.fitness_center_outlined;
      case 'WorkoutFrequency':
        return Icons.calendar_today_outlined;
      default:
        return Icons.flag_outlined;
    }
  }
}
