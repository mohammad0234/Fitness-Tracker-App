// lib/screens/exercise_progress_screen.dart
import 'package:flutter/material.dart';
import 'package:fitjourney/services/progress_service.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ExerciseProgressScreen extends StatefulWidget {
  final int exerciseId;
  
  const ExerciseProgressScreen({
    Key? key, 
    required this.exerciseId,
  }) : super(key: key);

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  final ProgressService _progressService = ProgressService.instance;
  final WorkoutService _workoutService = WorkoutService.instance;
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _exerciseData = {};
  
  // Sorting and filtering
  String _sortBy = 'Date (newest)';
  final List<String> _sortOptions = ['Date (newest)', 'Date (oldest)', 'Weight (highest)', 'Weight (lowest)'];
  
  @override
  void initState() {
    super.initState();
    _loadExerciseData();
  }
  
  Future<void> _loadExerciseData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Get exercise progress data
      final exerciseData = await _progressService.getExerciseProgressData(widget.exerciseId);
      
      setState(() {
        _exerciseData = exerciseData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading exercise data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }
  
  List<Map<String, dynamic>> _getSortedProgressPoints() {
    if (_exerciseData.isEmpty || !_exerciseData.containsKey('progressPoints')) {
      return [];
    }
    
    final progressPoints = List<Map<String, dynamic>>.from(_exerciseData['progressPoints']);
    
    switch (_sortBy) {
      case 'Date (newest)':
        progressPoints.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        break;
      case 'Date (oldest)':
        progressPoints.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
        break;
      case 'Weight (highest)':
        progressPoints.sort((a, b) => (b['weight'] as double).compareTo(a['weight'] as double));
        break;
      case 'Weight (lowest)':
        progressPoints.sort((a, b) => (a['weight'] as double).compareTo(b['weight'] as double));
        break;
    }
    
    return progressPoints;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading 
          ? 'Exercise Progress' 
          : _exerciseData['exerciseName'] ?? 'Exercise Progress'
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExerciseData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _hasError
          ? _buildErrorState()
          : _exerciseData.isEmpty
            ? _buildEmptyState()
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      
                      // Progress Chart
                      const Text(
                        'Progress Over Time',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProgressChart(),
                      const SizedBox(height: 24),
                      
                      // History Section with Sorting
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Exercise History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          DropdownButton<String>(
                            value: _sortBy,
                            items: _sortOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _sortBy = newValue;
                                });
                              }
                            },
                            hint: const Text('Sort by'),
                            underline: Container(
                              height: 1,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // History Table
                      _buildHistoryTable(),
                    ],
                  ),
                ),
              ),
    );
  }
  
  Widget _buildSummaryCard() {
    final personalBest = _exerciseData['personalBest'] as double?;
    final startingWeight = _exerciseData['startingWeight'] as double?;
    final improvementPercentage = _exerciseData['improvementPercentage'] as double?;
    final exerciseName = _exerciseData['exerciseName'] as String;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.fitness_center,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Progress Summary',
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
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  'Personal Best',
                  personalBest != null ? '${personalBest.toStringAsFixed(1)} kg' : 'N/A',
                  Icons.emoji_events,
                  Colors.amber,
                ),
                _buildSummaryStat(
                  'Starting Weight',
                  startingWeight != null ? '${startingWeight.toStringAsFixed(1)} kg' : 'N/A',
                  Icons.history,
                  Colors.teal,
                ),
                _buildSummaryStat(
                  'Improvement',
                  improvementPercentage != null ? '${improvementPercentage.toStringAsFixed(1)}%' : 'N/A',
                  Icons.trending_up,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildProgressChart() {
    if (!_exerciseData.containsKey('progressPoints') || 
        (_exerciseData['progressPoints'] as List).isEmpty) {
      return _buildEmptyChartState();
    }
    
    final progressPoints = List<Map<String, dynamic>>.from(_exerciseData['progressPoints']);
    
    // Sort by date for the chart
    progressPoints.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: _calculateInterval(),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade300,
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.shade300,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
  show: true,
  rightTitles: AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  ),
  topTitles: AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  ),
  bottomTitles: AxisTitles(
    axisNameWidget: const Padding(
      padding: EdgeInsets.only(top: 8.0),
      child: Text(
        'Date',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    ),
    axisNameSize: 24,
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: _calculateDateInterval(progressPoints),
      getTitlesWidget: (double value, TitleMeta meta) {
        if (value.toInt() < 0 || value.toInt() >= progressPoints.length) {
          return const SizedBox();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            progressPoints[value.toInt()]['formattedDate'],
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    ),
  ),
  leftTitles: AxisTitles(
    axisNameWidget: const RotatedBox(
      quarterTurns: -1,
      child: Text(
        'Weight',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    ),
    axisNameSize: 28,
    sideTitles: SideTitles(
      showTitles: true,
      interval: _calculateInterval(),
      reservedSize: 40,
      getTitlesWidget: (double value, TitleMeta meta) {
        return Text(
          value.toInt().toString(),
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
        );
      },
    ),
  ),
),

          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade300),
          ),
          minX: 0,
          maxX: progressPoints.length - 1.0,
          minY: 0,
          maxY: _getMaxWeight() * 1.1, // Add 10% space at the top
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(progressPoints.length, (index) {
                return FlSpot(
                  index.toDouble(),
                  progressPoints[index]['weight'],
                );
              }),
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade300,
                  Colors.green.shade600,
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.green.shade700,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade200.withValues(alpha: 0.3),
                    Colors.green.shade400.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.green.shade700,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final index = barSpot.x.toInt();
                  final weight = progressPoints[index]['weight'];
                  final date = progressPoints[index]['formattedDate'];
                  return LineTooltipItem(
                    '$date\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: 'Weight: ${weight.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
  
  double _calculateInterval() {
    final maxWeight = _getMaxWeight();
    if (maxWeight <= 50) return 10;
    if (maxWeight <= 100) return 20;
    if (maxWeight <= 200) return 50;
    if (maxWeight <= 500) return 100;
    return 200;
  }
  
  double _calculateDateInterval(List<Map<String, dynamic>> progressPoints) {
    // Show fewer date labels when there are many data points
    if (progressPoints.length > 20) {
      return (progressPoints.length / 5).ceil().toDouble();
    } else if (progressPoints.length > 10) {
      return (progressPoints.length / 4).ceil().toDouble();
    }
    return 1; // Show all date labels for few data points
  }
  
  double _getMaxWeight() {
    if (!_exerciseData.containsKey('progressPoints') || 
        (_exerciseData['progressPoints'] as List).isEmpty) {
      return 100;
    }
    
    final progressPoints = List<Map<String, dynamic>>.from(_exerciseData['progressPoints']);
    double maxWeight = 0;
    
    for (var point in progressPoints) {
      final weight = point['weight'] as double;
      if (weight > maxWeight) {
        maxWeight = weight;
      }
    }
    
    return maxWeight == 0 ? 100 : maxWeight;
  }
  
  Widget _buildHistoryTable() {
    final progressPoints = _getSortedProgressPoints();
    
    if (progressPoints.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No history data available for this exercise'),
        ),
      );
    }
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('WEIGHT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 1,
                  child: Text(''),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          
          // Table rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: progressPoints.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final point = progressPoints[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        DateFormat('MMM d, yyyy').format(point['date']),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${point['weight'].toStringAsFixed(1)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: point['weight'] == _exerciseData['personalBest']
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 4),
                                const Text('PB', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyChartState() {
    return SizedBox(
      height: 250,
      child: Center(
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
              'No progress data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log more workouts with this exercise to see your progress',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No data for this exercise',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log workouts with this exercise to track your progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/log_workout');
              },
              icon: const Icon(Icons.add),
              label: const Text('Log a Workout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadExerciseData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}