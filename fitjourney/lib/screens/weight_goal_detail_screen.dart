import 'package:flutter/material.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/screens/edit_goal_screen.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class WeightGoalDetailScreen extends StatefulWidget {
  final int goalId;

  const WeightGoalDetailScreen({
    super.key,
    required this.goalId,
  });

  @override
  State<WeightGoalDetailScreen> createState() => _WeightGoalDetailScreenState();
}

class _WeightGoalDetailScreenState extends State<WeightGoalDetailScreen> {
  final GoalService _goalService = GoalService.instance;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isLoggingWeight = false;
  Map<String, dynamic>? _goalDetails;
  Goal? _goal;
  List<Map<String, dynamic>> _weightHistory = [];
  bool _isLoadingChart = true;

  // Controllers for weight logging dialog
  final TextEditingController _weightController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadGoalDetails();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
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

      // Load weight history
      setState(() {
        _isLoadingChart = true;
      });

      try {
        final history = await _goalService.getWeightProgressHistory(
            goal.userId, goal.startDate);

        setState(() {
          _weightHistory = history;
          _isLoadingChart = false;
        });
      } catch (e) {
        print('Error loading weight history: $e');
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

  Future<void> _deleteGoal() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Goal'),
            content: const Text(
                'Are you sure you want to delete this goal? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

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

  Future<void> _showLogWeightDialog() async {
    // Reset controller and selected date
    _weightController.text = '';
    _selectedDate = DateTime.now();

    // Show dialog to log weight
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log Weight'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Date: '),
                        TextButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null) {
                              setDialogState(() {
                                _selectedDate = pickedDate;
                              });
                            }
                          },
                          child: Text(
                            DateFormat('MMM d, yyyy').format(_selectedDate),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: _isLoggingWeight
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SAVE'),
                  onPressed: _isLoggingWeight
                      ? null
                      : () async {
                          // Validate input
                          if (_weightController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter a weight')),
                            );
                            return;
                          }

                          double? weight =
                              double.tryParse(_weightController.text);
                          if (weight == null || weight <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter a valid weight')),
                            );
                            return;
                          }

                          setDialogState(() {
                            _isLoggingWeight = true;
                          });

                          try {
                            // Log the weight
                            await _goalService.logUserWeight(
                                weight, _selectedDate);

                            if (!mounted) return;
                            Navigator.of(context).pop();

                            // Reload goal details to reflect new weight
                            await _loadGoalDetails();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Weight logged successfully')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error logging weight: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setDialogState(() {
                                _isLoggingWeight = false;
                              });
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeightLoss = _goalDetails?['isWeightLoss'] ?? false;
    final isWeightGain = _goalDetails?['isWeightGain'] ?? false;

    // Determine colors based on goal type
    final primaryColor = isWeightLoss ? Colors.green : Colors.blue;
    final secondaryColor =
        isWeightLoss ? Colors.green.shade300 : Colors.blue.shade300;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading
            ? 'Goal Details'
            : _goalDetails?['title'] ?? 'Weight Goal'),
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditGoalScreen(goalId: widget.goalId),
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
                                    backgroundColor:
                                        primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.monitor_weight_outlined,
                                      color: primaryColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isWeightLoss
                                              ? 'Weight Loss Goal'
                                              : isWeightGain
                                                  ? 'Weight Gain Goal'
                                                  : 'Weight Maintenance Goal',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _goalDetails?['formattedChange'] ??
                                              '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: primaryColor,
                                            fontWeight: FontWeight.w500,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Started',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy')
                                            .format(_goal!.startDate),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Target Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy')
                                            .format(_goal!.endDate),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              (_goalDetails?['isExpired'] ??
                                                      false)
                                                  ? FontWeight.normal
                                                  : FontWeight.bold,
                                          color: (_goalDetails?['isExpired'] ??
                                                  false)
                                              ? Colors.red
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Progress
                              const Text(
                                'Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _goalDetails?['progress'] ?? 0.0,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryColor,
                                ),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Starting weight
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Starting',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${_goalDetails?['startingWeight']?.toStringAsFixed(1) ?? '0.0'} kg',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Current weight
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${_goalDetails?['current']?.toStringAsFixed(1) ?? '0.0'} kg',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Target weight
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Target',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${_goalDetails?['target']?.toStringAsFixed(1) ?? '0.0'} kg',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Weight history chart
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weight Progress',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 250,
                                child: _isLoadingChart
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _weightHistory.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.timeline_outlined,
                                                  size: 48,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'No weight data available yet',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : _buildWeightChart(isWeightLoss,
                                            primaryColor, secondaryColor),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Log weight button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showLogWeightDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Log Weight'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      // Weight tracking statistics
                      if (_weightHistory.length > 1)
                        Card(
                          margin: const EdgeInsets.only(top: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isWeightLoss
                                      ? 'Weight Loss Statistics'
                                      : 'Weight Gain Statistics',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Weekly rate of change
                                _buildStatisticRow(
                                  'Weekly rate:',
                                  '${_calculateWeeklyChangeRate().abs().toStringAsFixed(1)} kg/week',
                                  icon: Icons.trending_up,
                                  isPositive: (isWeightLoss &&
                                          _calculateWeeklyChangeRate() < 0) ||
                                      (!isWeightLoss &&
                                          _calculateWeeklyChangeRate() > 0),
                                ),

                                // Total change
                                _buildStatisticRow(
                                  'Total change:',
                                  '${_calculateTotalChange().toStringAsFixed(1)} kg',
                                  icon: Icons.compare_arrows,
                                  isPositive: (isWeightLoss &&
                                          _calculateTotalChange() < 0) ||
                                      (!isWeightLoss &&
                                          _calculateTotalChange() > 0),
                                ),

                                // Projected completion
                                if (_calculateProjectedCompletion() != null)
                                  _buildStatisticRow(
                                    'Projected completion:',
                                    DateFormat('MMM d, yyyy').format(
                                        _calculateProjectedCompletion()!),
                                    icon: Icons.event,
                                    isPositive: true,
                                  ),

                                // Progress percentage
                                _buildStatisticRow(
                                  'Completion:',
                                  '${(_goalDetails?['progress'] * 100).toStringAsFixed(0)}%',
                                  icon: Icons.pie_chart,
                                  isPositive: true,
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

  Widget _buildWeightChart(
      bool isWeightLoss, Color primaryColor, Color secondaryColor) {
    if (_weightHistory.isEmpty) {
      return const Center(child: Text('No weight data available'));
    }

    // Define min and max values for the chart
    double minY = double.infinity;
    double maxY = 0;

    for (var point in _weightHistory) {
      final weight = point['weight'] as double;
      if (weight > maxY) maxY = weight;
      if (weight < minY) minY = weight;
    }

    // Add padding to the min/max
    final yPadding = (maxY - minY) * 0.1;
    minY = (minY - yPadding).clamp(0, double.infinity);
    maxY = maxY + yPadding;

    // Make sure target weight is within the visible range
    final targetValue = _goal?.targetValue ?? 0;
    if ((targetValue < minY) || (targetValue > maxY)) {
      minY = min(minY, targetValue - yPadding);
      maxY = max(maxY, targetValue + yPadding);
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < _weightHistory.length) {
                  final date =
                      _weightHistory[value.toInt()]['date'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: _weightHistory.length - 1.0,
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchSpotThreshold: 20, // Increase touch area for easier selection
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                isWeightLoss ? Colors.green.shade700 : Colors.blue.shade700,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                if (barSpot.x.toInt() < 0 ||
                    barSpot.x.toInt() >= _weightHistory.length) return null;

                final point = _weightHistory[barSpot.x.toInt()];
                final date =
                    DateFormat('MMM d, yyyy').format(point['date'] as DateTime);
                final weight = point['weight'].toStringAsFixed(1);

                return LineTooltipItem(
                  '$date',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: '$weight kg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            fitInsideHorizontally: true,
            fitInsideVertically: true,
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // Starting weight line
            HorizontalLine(
              y: _goalDetails?['startingWeight'] ?? 0,
              color: secondaryColor,
              strokeWidth: 1.5,
              dashArray: [3, 3],
              label: HorizontalLineLabel(
                show: true,
                style: TextStyle(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                labelResolver: (line) =>
                    ' STARTING: ${(_goalDetails?['startingWeight'] ?? 0).toStringAsFixed(1)}kg ',
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            ),
            // Target weight line
            HorizontalLine(
              y: targetValue,
              color: Colors.green,
              strokeWidth: 2.5,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                style: TextStyle(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                labelResolver: (line) =>
                    ' TARGET: ${targetValue.toStringAsFixed(1)}kg ',
                alignment: Alignment.topRight,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              _weightHistory.length,
              (index) => FlSpot(
                index.toDouble(),
                _weightHistory[index]['weight'],
              ),
            ),
            isCurved: _weightHistory.length > 2,
            curveSmoothness: 0.2,
            color: primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // Check if there's a previous point to compare direction
                bool isPositiveChange = false;
                if (index > 0) {
                  final current = _weightHistory[index]['weight'] as double;
                  final previous =
                      _weightHistory[index - 1]['weight'] as double;

                  // For weight loss goals, lower is better
                  if (isWeightLoss) {
                    isPositiveChange = current < previous;
                  } else {
                    // For weight gain goals, higher is better
                    isPositiveChange = current > previous;
                  }
                }

                // Find max weight point
                double maxWeight = 0;
                for (var point in _weightHistory) {
                  if (point['weight'] > maxWeight) {
                    maxWeight = point['weight'];
                  }
                }

                final isLatestPoint = index == _weightHistory.length - 1;

                return FlDotCirclePainter(
                  radius: isLatestPoint ? 6 : 4,
                  color: isLatestPoint
                      ? Colors.purple
                      : (isPositiveChange ? Colors.green : Colors.redAccent),
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticRow(String label, String value,
      {IconData? icon, bool isPositive = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 18,
              color: isPositive ? Colors.green : Colors.red,
            ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // Calculate weekly rate of weight change
  double _calculateWeeklyChangeRate() {
    if (_weightHistory.length < 2) return 0;

    // Get earliest and latest weight entries
    final firstEntry = _weightHistory.first;
    final lastEntry = _weightHistory.last;

    final firstWeight = firstEntry['weight'] as double;
    final lastWeight = lastEntry['weight'] as double;

    // Calculate weight change
    final weightChange = lastWeight - firstWeight;

    // Calculate time difference in weeks
    final firstDate = firstEntry['date'] as DateTime;
    final lastDate = lastEntry['date'] as DateTime;
    final daysDifference = lastDate.difference(firstDate).inDays;

    // Avoid division by zero
    if (daysDifference == 0) return 0;

    // Calculate weekly rate
    final weeklyRate = (weightChange / daysDifference) * 7;

    return weeklyRate;
  }

  // Calculate total weight change
  double _calculateTotalChange() {
    if (_weightHistory.length < 2) return 0;

    final startingWeight = _weightHistory.first['weight'] as double;
    final currentWeight = _weightHistory.last['weight'] as double;

    return currentWeight - startingWeight;
  }

  // Calculate projected completion date
  DateTime? _calculateProjectedCompletion() {
    if (_weightHistory.length < 2 ||
        _goal == null ||
        _goal!.targetValue == null) return null;

    final weeklyRate = _calculateWeeklyChangeRate();

    // If no progress or going in wrong direction
    if (weeklyRate == 0 ||
        ((_goalDetails?['isWeightLoss'] ?? false) && weeklyRate >= 0) ||
        ((_goalDetails?['isWeightGain'] ?? false) && weeklyRate <= 0)) {
      return null;
    }

    final currentWeight = _weightHistory.last['weight'] as double;
    final targetWeight = _goal!.targetValue!;

    // Calculate remaining change needed
    final remainingChange = (targetWeight - currentWeight).abs();

    // Calculate weeks needed
    final weeksNeeded = remainingChange / weeklyRate.abs();

    // Calculate projected completion date
    final lastDate = _weightHistory.last['date'] as DateTime;
    final projectedDate =
        lastDate.add(Duration(days: (weeksNeeded * 7).round()));

    return projectedDate;
  }

  // Helper function to find minimum of two numbers
  double min(double a, double b) => a < b ? a : b;

  // Helper function to find maximum of two numbers
  double max(double a, double b) => a > b ? a : b;
}
