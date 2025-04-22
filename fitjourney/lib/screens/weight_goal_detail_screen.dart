/// WeightGoalDetailScreen provides a detailed view of a user's weight-related goal
/// Features include:
/// - Goal progress tracking and visualization
/// - Weight logging functionality
/// - Progress statistics and projections
/// - Weight history chart
/// - Goal editing and deletion
import 'package:flutter/material.dart';
import 'package:fitjourney/services/goal_service.dart';
import 'package:fitjourney/database_models/goal.dart';
import 'package:fitjourney/screens/edit_goal_screen.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// Main screen widget for displaying weight goal details
/// Takes a goalId parameter to load specific goal information
class WeightGoalDetailScreen extends StatefulWidget {
  final int goalId;

  const WeightGoalDetailScreen({
    super.key,
    required this.goalId,
  });

  @override
  State<WeightGoalDetailScreen> createState() => _WeightGoalDetailScreenState();
}

/// State management for WeightGoalDetailScreen
/// Handles:
/// - Goal data loading and display
/// - Weight logging
/// - Progress tracking
/// - Chart visualization
/// - Goal management (edit/delete)
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

  /// Loads all goal-related data including:
  /// - Basic goal information
  /// - Progress details
  /// - Weight history
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
        // Debug print to track goal info
        print(
            'Loading weight history for userId: ${goal.userId}, from date: ${goal.startDate}');

        // Modify this to load ALL weight history regardless of date
        final history =
            await _goalService.getWeightProgressHistory(goal.userId);

        print('Weight history loaded: ${history.length} entries');
        // Print first few entries if available
        if (history.isNotEmpty) {
          print('First weight entry: ${history[0]}');
        }

        // Update UI with properly converted data
        setState(() {
          // Properly convert to avoid type errors
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

  /// Handles goal deletion with user confirmation
  /// Removes goal from database and returns to previous screen
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

  /// Shows dialog for logging new weight entries
  /// Features:
  /// - Weight input validation
  /// - Date selection
  /// - Immediate progress update
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
                            print('Logging weight: $weight on $_selectedDate');
                            await _goalService.logUserWeight(
                                weight, _selectedDate);

                            if (!mounted) return;
                            Navigator.of(context).pop();

                            print('Weight logged successfully, reloading data');
                            // Reload goal details to reflect new weight
                            await _loadGoalDetails();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Weight logged successfully')),
                            );
                          } catch (e) {
                            print('Error logging weight: $e');
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

  /// Builds the weight progress chart
  /// Features:
  /// - Interactive line chart
  /// - Target and starting weight indicators
  /// - Progress point highlighting
  /// - Touch tooltips with detailed information
  Widget _buildWeightChart(
      bool isWeightLoss, Color primaryColor, Color secondaryColor) {
    // Add more comprehensive debug info
    print('Building weight chart with ${_weightHistory.length} data points');

    if (_weightHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 8),
            Text(
              'Use the "Log Weight" button to add data',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // If we have only one data point, duplicate it to show at least a line
    if (_weightHistory.length == 1) {
      print('Only one weight entry found, duplicating for chart display');
      final entry = _weightHistory.first;
      // Create a second entry one day later with the same weight
      final secondEntry = {
        'date': (entry['date'] as DateTime).add(const Duration(days: 1)),
        'weight': entry['weight'] as double,
        'formattedDate': 'Today',
      };
      _weightHistory.add(secondEntry);
    }

    // Define min and max values for the chart
    double minY = double.infinity;
    double maxY = 0;

    for (var point in _weightHistory) {
      final weight = point['weight'] as double;
      if (weight > maxY) maxY = weight;
      if (weight < minY) minY = weight;
    }

    // Add padding to the min/max and handle edge cases
    if (minY == maxY) {
      // If all weights are the same, create a range
      minY = minY * 0.95;
      maxY = maxY * 1.05;
    } else {
      final yPadding = (maxY - minY) * 0.1;
      minY = (minY - yPadding).clamp(0, double.infinity);
      maxY = maxY + yPadding;
    }

    // Make sure target weight is within the visible range
    final targetValue = _goal?.targetValue ?? 0;
    if ((targetValue < minY) || (targetValue > maxY)) {
      minY = min(minY, targetValue - (maxY - minY) * 0.1);
      maxY = max(maxY, targetValue + (maxY - minY) * 0.1);
    }

    print('Chart Y-axis range: $minY to $maxY');

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
                final weight = (point['weight'] as double).toStringAsFixed(1);

                return LineTooltipItem(
                  '$date',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: '\n$weight kg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // Main data line
          LineChartBarData(
            spots: List.generate(_weightHistory.length, (index) {
              return FlSpot(index.toDouble(),
                  (_weightHistory[index]['weight'] as double));
            }),
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: primaryColor,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: secondaryColor.withOpacity(0.3),
            ),
          ),
          // Target weight line (horizontal)
          if (_goal?.targetValue != null)
            LineChartBarData(
              spots: [
                FlSpot(0, _goal!.targetValue!),
                FlSpot(_weightHistory.length - 1.0, _goal!.targetValue!),
              ],
              isCurved: false,
              color: Colors.red.shade400,
              barWidth: 1,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              dashArray: [5, 5], // Dashed line
            ),
        ],
      ),
    );
  }

  /// Creates a statistics row with label and value
  /// Used for displaying various progress metrics
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

  /// Calculates total weight change from start
  /// Compares first and last weight entries
  double _calculateTotalChange() {
    if (_weightHistory.length < 2) return 0;

    final startingWeight = _weightHistory.first['weight'] as double;
    final currentWeight = _weightHistory.last['weight'] as double;

    return currentWeight - startingWeight;
  }

  /// Projects goal completion date based on current progress
  /// Uses weekly rate to estimate time to target weight
  DateTime? _calculateProjectedCompletion() {
    if (_weightHistory.length < 2 ||
        _goal == null ||
        _goal!.targetValue == null) return null;

    // Since we're removing weekly rate calculation, we need to calculate it directly here
    // Get earliest and latest weight entries
    final firstEntry = _weightHistory.first;
    final lastEntry = _weightHistory.last;

    final firstWeight = firstEntry['weight'] as double;
    final lastWeight = lastEntry['weight'] as double;

    // Calculate weight change
    final weightChange = lastWeight - firstWeight;

    // Calculate time difference in days
    final firstDate = firstEntry['date'] as DateTime;
    final lastDate = lastEntry['date'] as DateTime;
    final daysDifference = lastDate.difference(firstDate).inDays;

    // Avoid division by zero or no change
    if (daysDifference == 0 || weightChange == 0) return null;

    // Calculate daily rate of change
    final dailyRate = weightChange / daysDifference;

    // Check if progress is in the right direction
    if (((_goalDetails?['isWeightLoss'] ?? false) && dailyRate >= 0) ||
        ((_goalDetails?['isWeightGain'] ?? false) && dailyRate <= 0)) {
      return null;
    }

    final currentWeight = lastWeight;
    final targetWeight = _goal!.targetValue!;

    // Calculate remaining change needed
    final remainingChange = (targetWeight - currentWeight).abs();

    // Calculate days needed
    final daysNeeded = remainingChange / dailyRate.abs();

    // Calculate projected completion date
    final projectedDate = lastDate.add(Duration(days: daysNeeded.round()));

    return projectedDate;
  }

  /// Helper function for finding minimum of two numbers
  /// Used in chart scaling calculations
  double min(double a, double b) => a < b ? a : b;

  /// Helper function for finding maximum of two numbers
  /// Used in chart scaling calculations
  double max(double a, double b) => a > b ? a : b;
}
