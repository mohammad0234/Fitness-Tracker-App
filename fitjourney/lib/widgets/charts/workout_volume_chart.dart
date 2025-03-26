import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class WorkoutVolumeChart extends StatelessWidget {
  final List<Map<String, dynamic>> volumeData;
  final bool isLoading;
  final String timeRange;

  const WorkoutVolumeChart({
    Key? key,
    required this.volumeData,
    this.isLoading = false,
    this.timeRange = 'Weekly',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (volumeData.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Improved title with information icon
        // Replace the title row with this more flexible layout
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 16.0),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Workout Volume (Weight × Reps) - $timeRange',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Volume is calculated by multiplying weight by reps for each set, then adding all sets together. Higher volume indicates more work performed.',
            child: const Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ],
  ),
),
        SizedBox(
          height: 220,
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
                      reservedSize: 50, // Increased for larger labels
                      getTitlesWidget: _leftTitleWidgets,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                minX: 0,
                maxX: volumeData.length - 1.0,
                minY: 0,
                maxY: _getMaxVolume() * 1.1, // Add 10% space at the top
                lineBarsData: [
                  LineChartBarData(
                    spots: _createSpots(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade300,
                        Colors.blue.shade600,
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue.shade700,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade200.withOpacity(0.3),
                          Colors.blue.shade400.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Colors.blue.shade700,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final index = barSpot.x.toInt();
                        final volume = volumeData[index]['volume'];
                        final date = volumeData[index]['formattedDate'];
                        return LineTooltipItem(
                          '$date\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: 'Volume: ${volume.toStringAsFixed(1)} kg',
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
        
        // Added explanation text for better user understanding
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Volume represents total work performed in your workouts. Higher numbers indicate more intense training sessions.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= volumeData.length) {
      return const SizedBox.shrink();
    }

    // Determine how many labels to show based on data length
    final int interval = (volumeData.length / 5).ceil();
    if (index % interval != 0 && index != volumeData.length - 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        volumeData[index]['formattedDate'],
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    // Format numbers with units (kg)
    String formatted = '';
    if (value >= 1000) {
      formatted = '${(value / 1000).toStringAsFixed(1)}k kg';
    } else {
      formatted = '${value.toInt()} kg';
    }
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(
        formatted,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  List<FlSpot> _createSpots() {
    return List.generate(volumeData.length, (index) {
      return FlSpot(
        index.toDouble(),
        volumeData[index]['volume'],
      );
    });
  }

  double _getMaxVolume() {
    if (volumeData.isEmpty) return 100;
    double maxVolume = 0;
    for (var data in volumeData) {
      if (data['volume'] > maxVolume) {
        maxVolume = data['volume'];
      }
    }
    return maxVolume == 0 ? 100 : maxVolume;
  }

  double _calculateInterval() {
    final maxVolume = _getMaxVolume();
    if (maxVolume <= 100) return 20;
    if (maxVolume <= 500) return 100;
    if (maxVolume <= 1000) return 200;
    if (maxVolume <= 5000) return 1000;
    return 2000;
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 50,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No workout data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log workouts to see your progress',
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