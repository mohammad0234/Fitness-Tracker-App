// lib/screens/goal_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/screens/edit_goal_screen.dart';
import 'package:intl/intl.dart';

class GoalDetailScreen extends StatefulWidget {
  final int goalId;
  
  const GoalDetailScreen({
    super.key,
    required this.goalId,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final GoalService _goalService = GoalService.instance;
  bool _isLoading = true;
  bool _isDeleting = false;
  Map<String, dynamic>? _goalDetails;
  Goal? _goal;
  
  @override
  void initState() {
    super.initState();
    _loadGoalDetails();
  }
  
  Future<void> _loadGoalDetails() async {
    try {
      // First, get the goal object
      final goal = await _goalService.getGoalById(widget.goalId);
      
      if (goal == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Then get the formatted information for display
      final goalDetails = await _goalService.getGoalDisplayInfo(goal);
      
      setState(() {
        _goal = goal;
        _goalDetails = goalDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading goal details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteGoal() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    setState(() {
      _isDeleting = true;
    });
    
    try {
      await _goalService.deleteGoal(widget.goalId);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal deleted successfully')),
      );
      
      Navigator.of(context).pop(true); // Return true to indicate deletion
    } catch (e) {
      print('Error deleting goal: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting goal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading
          ? 'Goal Details'
          : _goalDetails?['title'] ?? 'Goal Details'
        ),
        actions: [
          // Edit button
IconButton(
  icon: const Icon(Icons.edit),
  onPressed: _isLoading ? null : () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditGoalScreen(goalId: widget.goalId),
      ),
    ).then((result) {
      // Reload the goal details if it was updated
      if (result == true) {
        _loadGoalDetails();
      }
    });
  },
),
          // Delete button
          IconButton(
            icon: _isDeleting 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete),
            onPressed: _isLoading || _isDeleting ? null : _deleteGoal,
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
                      // Goal info card
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: _getGoalColor(_goal!.type).withOpacity(0.1),
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
                                          _goalDetails?['title'] ?? 'Goal',
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
                              const SizedBox(height: 16),
                              
                              // Dates
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(_goal!.startDate),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(_goal!.endDate),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Time remaining
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _goalDetails!['isExpired'] == true
                                      ? Colors.red.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _goalDetails!['isExpired'] == true
                                          ? Icons.timer_off
                                          : Icons.timer,
                                      color: _goalDetails!['isExpired'] == true
                                          ? Colors.red.shade700
                                          : Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _goalDetails!['isExpired'] == true
                                          ? 'Goal Expired'
                                          : '${_goalDetails!['daysLeft']} days remaining',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _goalDetails!['isExpired'] == true
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Progress bar
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Progress',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${(_goalDetails!['progress'] * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _goalDetails!['progress'] >= 1.0
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: _goalDetails!['progress'],
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _goalDetails!['progress'] >= 1.0
                                            ? Colors.green
                                            : _goalDetails!['isExpired'] == true
                                                ? Colors.grey
                                                : Colors.blue,
                                      ),
                                      minHeight: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Goal target details
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Goal Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              if (_goal!.type == 'ExerciseTarget') ...[
                                // Exercise details for strength goals
                                _buildDetailRow(
                                  'Exercise',
                                  _goalDetails!['exerciseName'] ?? 'Unknown',
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Muscle Group',
                                  _goalDetails!['muscleGroup'] ?? 'Unknown',
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Starting Weight',
                                  '${_goal!.currentProgress.toStringAsFixed(1)} kg',
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Current Weight',
                                  '${_goalDetails!['current']?.toStringAsFixed(1) ?? "0"} kg',
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Target Weight',
                                  '${_goal!.targetValue?.toStringAsFixed(1) ?? "0"} kg',
                                ),
                              ] else if (_goal!.type == 'WorkoutFrequency') ...[
                                // Frequency goal details
                                _buildDetailRow(
                                  'Workouts Completed',
                                  '${_goalDetails!['current']?.toInt() ?? 0}',
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Target Workouts',
                                  '${_goal!.targetValue?.toInt() ?? 0}',
                                ),
                                const SizedBox(height: 12),
                                if (_goalDetails!.containsKey('weeklyTarget'))
                                  _buildDetailRow(
                                    'Weekly Target',
                                    '${_goalDetails!['weeklyTarget']?.toStringAsFixed(1) ?? "0"} workouts/week',
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Status card
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_goal!.achieved, _goalDetails!['isExpired']).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getStatusIcon(_goal!.achieved, _goalDetails!['isExpired']),
                                  color: _getStatusColor(_goal!.achieved, _goalDetails!['isExpired']),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getStatusText(_goal!.achieved, _goalDetails!['isExpired']),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getStatusMessage(_goal!.achieved, _goalDetails!['isExpired'], _goalDetails!['progress']),
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
                      ),
                    ],
                  ),
                ),
            );
    
  }
  
  // Helper widgets
  
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
  
  Color _getStatusColor(bool achieved, bool isExpired) {
    if (achieved) return Colors.green;
    if (isExpired) return Colors.red;
    return Colors.blue;
  }
  
  IconData _getStatusIcon(bool achieved, bool isExpired) {
    if (achieved) return Icons.check_circle_outline;
    if (isExpired) return Icons.error_outline;
    return Icons.pending_outlined;
  }
  
  String _getStatusText(bool achieved, bool isExpired) {
    if (achieved) return 'Goal Achieved';
    if (isExpired) return 'Goal Expired';
    return 'In Progress';
  }
  
  String _getStatusMessage(bool achieved, bool isExpired, double progress) {
    if (achieved) {
      return 'Congratulations! You\'ve successfully achieved this goal.';
    }
    if (isExpired) {
      return 'This goal has expired. Consider creating a new one.';
    }
    
    final percentage = (progress * 100).toInt();
    if (percentage > 75) {
      return 'You\'re almost there! Keep pushing to reach your goal.';
    } else if (percentage > 50) {
      return 'You\'re making great progress on this goal!';
    } else if (percentage > 25) {
      return 'You\'re on the right track with this goal.';
    } else {
      return 'You\'ve just started on this goal. Keep it up!';
    }
  }
}