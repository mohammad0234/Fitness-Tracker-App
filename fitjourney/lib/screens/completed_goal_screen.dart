import 'package:flutter/material.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// Screen for viewing detailed information about a completed fitness goal
/// Displays goal achievement data, history, and charts to celebrate success
class CompletedGoalScreen extends StatefulWidget {
  final int goalId;

  const CompletedGoalScreen({
    super.key,
    required this.goalId,
  });

  @override
  State<CompletedGoalScreen> createState() => _CompletedGoalScreenState();
}

class _CompletedGoalScreenState extends State<CompletedGoalScreen> {
  final GoalService _goalService = GoalService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _goalDetails;
  Goal? _goal;
  List<Map<String, dynamic>> _progressHistory = [];
  bool _isLoadingChart = true;

  @override
  void initState() {
    super.initState();
    _loadGoalDetails();
  }

  /// Loads the goal data and formatted display information
  /// For completed goals, also loads relevant progress history for charting
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

      // Load appropriate history data based on goal type
      setState(() {
        _isLoadingChart = true;
      });

      try {
        if (goal.type == 'ExerciseTarget' && goal.exerciseId != null) {
          // For strength goals, load exercise history
          final history = await _goalService.getExerciseProgressHistory(
              goal.exerciseId!, goal.userId);

          // Debug logging to understand data format
          print('Exercise progress history: $history');
          if (history.isNotEmpty) {
            print('First entry date: ${history.first['date']}');
            print('First entry weight: ${history.first['weight']}');
          }

          setState(() {
            _progressHistory = history;
            _isLoadingChart = false;
          });
        } else if (goal.type == 'WeightTarget') {
          // For weight goals, load weight history
          final history = await _goalService.getWeightProgressHistory(
              goal.userId, goal.startDate, goal.achievedDate ?? goal.endDate);

          // Debug logging to understand data format
          print('Weight progress history: $history');
          if (history.isNotEmpty) {
            print('First entry date: ${history.first['date']}');
            print('First entry weight: ${history.first['weight']}');
          }

          setState(() {
            _progressHistory = history;
            _isLoadingChart = false;
          });
        } else {
          // For other goals like frequency goals
          setState(() {
            _isLoadingChart = false;
          });
        }
      } catch (e) {
        print('Error loading progress history: $e');
        setState(() {
          _isLoadingChart = false;
        });
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading
            ? 'Goal Achievement'
            : _goalDetails?['title'] ?? 'Goal Achievement'),
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
                      // Achievement banner
                      _buildAchievementBanner(),

                      const SizedBox(height: 24),

                      // Goal details card
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
                              _buildGoalDetails(),
                            ],
                          ),
                        ),
                      ),

                      // Progress history chart
                      if (_progressHistory.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Progress Journey',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildProgressChart(),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Achievement stats
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Achievement Stats',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildAchievementStats(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  /// Builds a celebration banner displaying the achievement
  Widget _buildAchievementBanner() {
    Color goalColor = _getGoalColor(_goal!.type);
    final achievementDate = DateFormat('MMMM d, yyyy')
        .format(_goal!.achievedDate ?? _goal!.endDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: goalColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goalColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events,
            size: 48,
            color: goalColor,
          ),
          const SizedBox(height: 12),
          Text(
            'Goal Achieved!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: goalColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed on $achievementDate',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds goal details based on the goal type
  Widget _buildGoalDetails() {
    if (_goal!.type == 'ExerciseTarget') {
      // For strength goals
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            '${_goalDetails!['startingWeight']?.toStringAsFixed(1) ?? "0"} kg',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Target Weight',
            '${_goal!.targetValue?.toStringAsFixed(1) ?? "0"} kg',
          ),
        ],
      );
    } else if (_goal!.type == 'WeightTarget') {
      // For weight goals
      final isLoss = _goalDetails?['isWeightLoss'] ?? false;
      final startingWeight =
          _goalDetails?['startingWeight']?.toStringAsFixed(1) ?? "0";
      final targetWeight = _goal!.targetValue?.toStringAsFixed(1) ?? "0";
      final changeText = isLoss ? 'Weight Loss' : 'Weight Gain';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            'Goal Type',
            changeText,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Starting Weight',
            '$startingWeight kg',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Target Weight',
            '$targetWeight kg',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Final Weight',
            '${_goalDetails!['current']?.toStringAsFixed(1) ?? "0"} kg',
          ),
        ],
      );
    } else if (_goal!.type == 'WorkoutFrequency') {
      // For workout frequency goals
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            'Target Workouts',
            '${_goal!.targetValue?.toInt() ?? 0}',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Completed Workouts',
            '${_goal!.currentProgress.toInt()}',
          ),
          if (_goalDetails!.containsKey('weeklyTarget'))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Weekly Target',
                  '${(_goalDetails!['weeklyTarget'] ?? 0).round()} workouts per week',
                ),
              ],
            ),
        ],
      );
    }

    // Default fallback
    return const Text('No details available');
  }

  /// Builds a progress chart based on goal type
  Widget _buildProgressChart() {
    if (_isLoadingChart) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_progressHistory.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No progress data available')),
      );
    }

    // Build chart based on goal type
    if (_goal!.type == 'ExerciseTarget') {
      return _buildStrengthChart();
    } else if (_goal!.type == 'WeightTarget') {
      return _buildWeightChart();
    } else {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No chart available for this goal type')),
      );
    }
  }

  /// Builds a chart for strength goals
  Widget _buildStrengthChart() {
    // Need at least 2 points for a line chart
    if (_progressHistory.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Not enough data to show a chart')),
      );
    }

    // Check if we have only one unique date
    final dateSet = _progressHistory
        .map((p) => DateFormat('yyyy-MM-dd').format(p['date'] as DateTime))
        .toSet();

    print('Unique dates in strength data: $dateSet');

    // If we have only one unique date, we need to artificially create time spacing
    if (dateSet.length == 1) {
      return _buildSingleDateStrengthChart();
    }

    // Sort the history by date
    _progressHistory.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Create line chart data points directly with better x-axis control
    List<FlSpot> spots = [];
    for (int i = 0; i < _progressHistory.length; i++) {
      // Use the index as x value to ensure even spacing when dates are close
      spots
          .add(FlSpot(i.toDouble(), (_progressHistory[i]['weight'] as double)));
    }

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  // Only show labels at integer positions (our indices)
                  if (value != value.roundToDouble() ||
                      value < 0 ||
                      value >= _progressHistory.length) {
                    return const Text('');
                  }

                  final index = value.toInt();
                  final date = _progressHistory[index]['date'] as DateTime;
                  return Text(
                    DateFormat('MM/dd').format(date),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minX: -0.5, // Add padding on left
          maxX: _progressHistory.length - 0.5, // Add padding on right
          minY: _calculateMinYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          maxY: _calculateMaxYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Special handling for chart with only one unique date
  Widget _buildSingleDateStrengthChart() {
    // Sort by weight ascending
    _progressHistory.sort(
        (a, b) => (a['weight'] as double).compareTo(b['weight'] as double));

    // Create spots using weight for both axes to create a diagonal line
    final spots = _progressHistory.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      // Space the points horizontally using their index
      return FlSpot(index.toDouble(), point['weight'] as double);
    }).toList();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  // Show single date
                  if (value == spots.length / 2) {
                    final date = _progressHistory.first['date'] as DateTime;
                    return Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minX: -0.5,
          maxX: spots.length - 0.5,
          minY: _calculateMinYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          maxY: _calculateMaxYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a chart for weight goals
  Widget _buildWeightChart() {
    // Need at least 2 points for a line chart
    if (_progressHistory.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Not enough data to show a chart')),
      );
    }

    // Check if we have only one unique date
    final dateSet = _progressHistory
        .map((p) => DateFormat('yyyy-MM-dd').format(p['date'] as DateTime))
        .toSet();

    print('Unique dates in weight data: $dateSet');

    // If we have only one unique date, we need to artificially create time spacing
    if (dateSet.length == 1) {
      return _buildSingleDateWeightChart();
    }

    // Sort the history by date
    _progressHistory.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Create line chart data points directly with better x-axis control
    List<FlSpot> spots = [];
    for (int i = 0; i < _progressHistory.length; i++) {
      // Use the index as x value to ensure even spacing when dates are close
      spots
          .add(FlSpot(i.toDouble(), (_progressHistory[i]['weight'] as double)));
    }

    // Determine if this is a weight loss or gain goal to set colors
    final isLoss = _goalDetails?['isWeightLoss'] ?? false;
    final chartColor = isLoss ? Colors.blue : Colors.green;

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  // Only show labels at integer positions (our indices)
                  if (value != value.roundToDouble() ||
                      value < 0 ||
                      value >= _progressHistory.length) {
                    return const Text('');
                  }

                  final index = value.toInt();
                  final date = _progressHistory[index]['date'] as DateTime;
                  return Text(
                    DateFormat('MM/dd').format(date),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minX: -0.5, // Add padding on left
          maxX: _progressHistory.length - 0.5, // Add padding on right
          minY: _calculateMinYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          maxY: _calculateMaxYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: chartColor,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: chartColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Special handling for chart with only one unique date
  Widget _buildSingleDateWeightChart() {
    // Sort by weight ascending
    _progressHistory.sort(
        (a, b) => (a['weight'] as double).compareTo(b['weight'] as double));

    // Create spots using weight for both axes to create a diagonal line
    final spots = _progressHistory.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      // Space the points horizontally using their index
      return FlSpot(index.toDouble(), point['weight'] as double);
    }).toList();

    // Determine if this is a weight loss or gain goal to set colors
    final isLoss = _goalDetails?['isWeightLoss'] ?? false;
    final chartColor = isLoss ? Colors.blue : Colors.green;

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  // Show single date
                  if (value == spots.length / 2) {
                    final date = _progressHistory.first['date'] as DateTime;
                    return Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minX: -0.5,
          maxX: spots.length - 0.5,
          minY: _calculateMinYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          maxY: _calculateMaxYValue(
              _progressHistory.map((e) => e['weight'] as double).toList()),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: chartColor,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: chartColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Calculate minimum Y value with padding
  double _calculateMinYValue(List<double> values) {
    if (values.isEmpty) return 0;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    // Add 10% padding below the minimum
    return (min - (range * 0.1)).floorToDouble();
  }

  // Calculate maximum Y value with padding
  double _calculateMaxYValue(List<double> values) {
    if (values.isEmpty) return 100;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    // Add 10% padding above the maximum
    return (max + (range * 0.1)).ceilToDouble();
  }

  /// Builds achievement statistics based on goal type
  Widget _buildAchievementStats() {
    // Create specific stats based on goal type
    if (_goal!.type == 'ExerciseTarget') {
      // For strength goals
      final startingWeight = _goalDetails?['startingWeight'] ?? 0.0;
      final finalWeight = _goal!.currentProgress;
      final improvement = finalWeight - startingWeight;
      final improvementPercent = startingWeight > 0
          ? (improvement / startingWeight * 100).toStringAsFixed(1)
          : "0";

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(
            'Strength Improvement',
            '${improvement.toStringAsFixed(1)} kg (${improvementPercent}%)',
            icon: Icons.fitness_center,
            isPositive: improvement > 0,
          ),
        ],
      );
    } else if (_goal!.type == 'WeightTarget') {
      // For weight goals
      final startingWeight = _goalDetails?['startingWeight'] ?? 0.0;
      final finalWeight = _goal!.currentProgress;
      final change = finalWeight - startingWeight;
      final isLoss = _goalDetails?['isWeightLoss'] ?? false;
      final changeAbs = change.abs();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(
            isLoss ? 'Weight Lost' : 'Weight Gained',
            '${changeAbs.toStringAsFixed(1)} kg',
            icon: Icons.monitor_weight,
            isPositive: (isLoss && change < 0) || (!isLoss && change > 0),
          ),
        ],
      );
    } else if (_goal!.type == 'WorkoutFrequency') {
      // For workout frequency goals
      final targetWorkouts = _goal!.targetValue?.toInt() ?? 0;
      final completedWorkouts = _goal!.currentProgress.toInt();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(
            'Workouts Completed',
            '$completedWorkouts / $targetWorkouts',
            icon: Icons.calendar_today,
            isPositive: completedWorkouts >= targetWorkouts,
          ),
        ],
      );
    } else {
      return const Text('No achievement stats available');
    }
  }

  /// Gets the appropriate color for this goal type
  Color _getGoalColor(String type) {
    switch (type) {
      case 'ExerciseTarget':
        return Colors.orange;
      case 'WeightTarget':
        return Colors.blue;
      case 'WorkoutFrequency':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Builds a detail row with label and value
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Builds a statistic row with label, value and optional icon
  Widget _buildStatRow(String label, String value,
      {IconData? icon, bool isPositive = true}) {
    return Row(
      children: [
        if (icon != null)
          Icon(
            icon,
            size: 20,
            color: isPositive ? Colors.green : Colors.red,
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }
}
