import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ExerciseProgressChart extends StatelessWidget {
  final Map<String, dynamic> exerciseData;
  final bool isLoading;

  const ExerciseProgressChart({
    Key? key,
    required this.exerciseData,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exerciseData.isEmpty || (exerciseData['progressPoints'] as List).isEmpty) {
      return _buildEmptyState();
    }

    final List<Map<String, dynamic>> progressPoints = 
        exerciseData['progressPoints'] as List<Map<String, dynamic>>;
    final String exerciseName = exerciseData['exerciseName'] as String;
    final double? personalBest = exerciseData['personalBest'] as double?;
    final String improvementText = exerciseData['formattedImprovement'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exerciseName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Personal Best: ${personalBest?.toStringAsFixed(1) ?? "N/A"} kg',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '↑ $improvementText',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: _bottomTitleWidgets,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _calculateInterval(),
                      reservedSize: 42,
                      getTitlesWidget: _leftTitleWidgets,
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
                    spots: _createSpots(),
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
                          Colors.green.shade200.withOpacity(0.3),
                          Colors.green.shade400.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (LineBarSpot spot) => Colors.green.shade700,
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
          ),
        ),
      ],
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final progressPoints = exerciseData['progressPoints'] as List<Map<String, dynamic>>;
    final index = value.toInt();
    if (index < 0 || index >= progressPoints.length) {
      return const SizedBox.shrink();
    }

    // Determine how many labels to show based on data length
    final int interval = (progressPoints.length / 5).ceil();
    if (index % interval != 0 && index != progressPoints.length - 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        progressPoints[index]['formattedDate'],
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: const TextStyle(
        color: Colors.black54,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.left,
    );
  }

  List<FlSpot> _createSpots() {
    final progressPoints = exerciseData['progressPoints'] as List<Map<String, dynamic>>;
    return List.generate(progressPoints.length, (index) {
      return FlSpot(
        index.toDouble(),
        progressPoints[index]['weight'],
      );
    });
  }

  double _getMaxWeight() {
    final progressPoints = exerciseData['progressPoints'] as List<Map<String, dynamic>>;
    if (progressPoints.isEmpty) return 100;
    double maxWeight = 0;
    for (var data in progressPoints) {
      if (data['weight'] > maxWeight) {
        maxWeight = data['weight'];
      }
    }
    return maxWeight == 0 ? 100 : maxWeight;
  }

  double _calculateInterval() {
    final maxWeight = _getMaxWeight();
    if (maxWeight <= 50) return 10;
    if (maxWeight <= 100) return 20;
    if (maxWeight <= 200) return 50;
    if (maxWeight <= 500) return 100;
    return 200;
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 50,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No exercise progress data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log workouts with this exercise to track progress',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}