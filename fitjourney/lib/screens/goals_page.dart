import 'package:flutter/material.dart';
import 'package:fitjourney/services/goal_service.dart';
//import 'package:fitjourney/database_models/goal.dart';
import 'package:intl/intl.dart';
import 'log_goal_flow.dart';
import 'package:fitjourney/screens/goal_detail_screen.dart';
import 'package:fitjourney/screens/weight_goal_detail_screen.dart';

/// Screen for displaying and managing a user's fitness goals
/// Shows active goals, completed goals, and provides options to create new goals
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  // Data holders
  List<Map<String, dynamic>> _activeGoals = [];
  List<Map<String, dynamic>> _completedGoals = [];

  // UI states
  bool _showAllCompletedGoals = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadGoalData();
  }

  /// Loads and formats goal data from the database
  /// Updates all goal progress, retrieves active and completed goals
  Future<void> _loadGoalData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Update all goal progress first
      await GoalService.instance.updateAllGoalsProgress();

      // Get active goals and prepare them for display
      final activeGoals = await GoalService.instance.getActiveGoals();
      final List<Map<String, dynamic>> formattedActiveGoals = [];

      for (final goal in activeGoals) {
        final goalInfo = await GoalService.instance.getGoalDisplayInfo(goal);
        formattedActiveGoals.add(goalInfo);
      }

      // Get completed goals
      final completedGoals = await GoalService.instance.getCompletedGoals();
      final List<Map<String, dynamic>> formattedCompletedGoals = [];

      for (final goal in completedGoals) {
        final goalInfo = await GoalService.instance.getGoalDisplayInfo(goal);
        formattedCompletedGoals.add({
          'title': goalInfo['title'],
          'completedOn': DateFormat('MMM d, yyyy').format(goal.endDate),
        });
      }

      // Update state with the loaded data
      setState(() {
        _activeGoals = formattedActiveGoals;
        _completedGoals = formattedCompletedGoals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      print('Error loading goals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Goals',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadGoalData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Actions bar with "Active Goals" title aligned with the "New Goal" button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Goals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LogGoalFlow()),
                  ).then((_) => _loadGoalData());
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Goal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // Main content - scrollable
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadGoalData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active goals list (without the title that's now in the header)
                    if (_activeGoals.isEmpty)
                      _buildEmptyGoalsMessage()
                    else
                      ..._activeGoals.map((goal) => _buildGoalItem(goal)),

                    const SizedBox(height: 32),

                    // Completed Goals Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Completed Goals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_completedGoals.length > 2)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllCompletedGoals =
                                    !_showAllCompletedGoals;
                              });
                            },
                            child: Text(_showAllCompletedGoals
                                ? 'Show Less'
                                : 'See All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Completed goals list
                    if (_completedGoals.isEmpty)
                      _buildEmptyCompletedGoalsMessage()
                    else
                      ..._completedGoals
                          .take(_showAllCompletedGoals
                              ? _completedGoals.length
                              : 2)
                          .map((goal) => _buildCompletedGoalItem(goal)),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a placeholder message when no active goals exist
  /// Includes a prompt and button to create a first goal
  Widget _buildEmptyGoalsMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No active goals yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set your first goal to track your fitness progress',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogGoalFlow()),
              ).then((_) => _loadGoalData());
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a placeholder message when no completed goals exist
  Widget _buildEmptyCompletedGoalsMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Complete goals to see them here',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  /// Builds a card for displaying active goal information
  /// Shows goal progress, details, and navigates to details screen on tap
  Widget _buildGoalItem(Map<String, dynamic> goalInfo) {
    final Color goalColor = _getGoalColor(goalInfo['type']);
    final Widget goalIcon = _getGoalIcon(goalInfo['type']);
    final int goalId = goalInfo['goalId'];
    final double progress = goalInfo['progress'].clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to the appropriate goal detail screen based on type
          if (goalInfo['type'] == 'ExerciseTarget') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GoalDetailScreen(goalId: goalId),
              ),
            ).then((result) {
              // Refresh if goal was modified or deleted
              if (result == true) {
                _loadGoalData();
              }
            });
          } else if (goalInfo['type'] == 'WeightTarget') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeightGoalDetailScreen(goalId: goalId),
              ),
            ).then((result) {
              // Refresh if goal was modified or deleted
              if (result == true) {
                _loadGoalData();
              }
            });
          } else {
            // For other goal types (frequency, etc.)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GoalDetailScreen(goalId: goalId),
              ),
            ).then((result) {
              if (result == true) {
                _loadGoalData();
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: goalColor.withOpacity(0.1),
                    child: goalIcon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goalInfo['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Display specific goal information based on type
                  _buildGoalDetails(goalInfo),
                  // Remaining days
                  if (goalInfo['daysLeft'] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${goalInfo['daysLeft']} days left',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates detail display for goals of different types
  /// Formats progress information appropriate to the goal type (weight, frequency, etc.)
  Widget _buildGoalDetails(Map<String, dynamic> goalInfo) {
    if (goalInfo['type'] == 'ExerciseTarget') {
      // For strength goals
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${goalInfo['current']?.toStringAsFixed(1) ?? '0'} / ${goalInfo['target']?.toStringAsFixed(1) ?? '0'} kg',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (goalInfo.containsKey('startingWeight'))
            Row(
              children: [
                Text(
                  'From ${goalInfo['startingWeight']?.toStringAsFixed(1) ?? '0'} kg · ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (goalInfo.containsKey('formattedImprovement'))
                  Text(
                    goalInfo['formattedImprovement']
                        .replaceAll('since starting', ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
              ],
            )
          else if (goalInfo.containsKey('formattedImprovement'))
            Text(
              goalInfo['formattedImprovement'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
              ),
            ),
        ],
      );
    } else if (goalInfo['type'] == 'WorkoutFrequency') {
      // For frequency goals
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${goalInfo['current']?.toInt() ?? 0} / ${goalInfo['target']?.toInt() ?? 0} workouts',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Target: ${(goalInfo['weeklyTarget'] ?? 0).round()} workouts per week',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    } else if (goalInfo['type'] == 'WeightTarget') {
      // For weight goals
      final isWeightLoss = goalInfo['isWeightLoss'] ?? false;
      final currentWeight = goalInfo['current']?.toStringAsFixed(1) ?? '0';
      final targetWeight = goalInfo['target']?.toStringAsFixed(1) ?? '0';
      final startingWeight =
          goalInfo['startingWeight']?.toStringAsFixed(1) ?? '0';
      final progressChange = goalInfo['formattedChange'] ?? '';
      final textColor =
          isWeightLoss ? Colors.green.shade700 : Colors.blue.shade700;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$currentWeight / $targetWeight kg',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Text(
                'From $startingWeight kg · ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                progressChange.replaceAll('since starting', ''),
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return const Text('Unknown goal type');
    }
  }

  /// Returns the appropriate color for each goal type
  Color _getGoalColor(String type) {
    switch (type) {
      case 'ExerciseTarget':
        return Colors.orange;
      case 'WorkoutFrequency':
        return Colors.blue;
      case 'WeightTarget':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Returns the appropriate icon for each goal type
  Widget _getGoalIcon(String type) {
    switch (type) {
      case 'ExerciseTarget':
        return Icon(
          Icons.fitness_center,
          color: Colors.orange,
          size: 24,
        );
      case 'WorkoutFrequency':
        return Icon(
          Icons.calendar_today,
          color: Colors.blue,
          size: 24,
        );
      case 'WeightTarget':
        return Icon(
          Icons.monitor_weight_outlined,
          color: Colors.green,
          size: 24,
        );
      default:
        return Icon(
          Icons.help_outline,
          color: Colors.grey,
          size: 24,
        );
    }
  }

  /// Builds a list item for displaying completed goal information
  Widget _buildCompletedGoalItem(Map<String, dynamic> goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                size: 16,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal['title'] ?? 'Completed Goal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Completed on ${goal['completedOn']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
