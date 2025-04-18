import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ExerciseVolumeChart extends StatefulWidget {
  final List<Map<String, dynamic>> exerciseVolumeData;
  final bool isLoading;

  const ExerciseVolumeChart({
    Key? key,
    required this.exerciseVolumeData,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ExerciseVolumeChart> createState() => _ExerciseVolumeChartState();
}

class _ExerciseVolumeChartState extends State<ExerciseVolumeChart> {
  int touchedIndex = -1;

  // Define muscle group colors to match the pie chart colors
  final Map<String, Color> muscleGroupColors = {
    'Chest': Colors.red.shade400,
    'Back': Colors.blue.shade400,
    'Legs': Colors.green.shade400,
    'Shoulders': Colors.purple.shade400,
    'Biceps': Colors.orange.shade400,
    'Triceps': Colors.cyan.shade400,
    'Calves': Colors.pink.shade400,
    'Forearms': Colors.teal.shade400,
    'Traps': Colors.indigo.shade400,
    'Cardio': Colors.brown.shade400,
  };

  // Get color for a muscle group
  Color _getColorForMuscleGroup(String muscleGroup) {
    return muscleGroupColors[muscleGroup] ?? Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.exerciseVolumeData.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
          child: Text(
            'Volume by Exercise Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Chart description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Total volume in kg (weight × reps) lifted for each exercise',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Horizontal bar chart - scrollable container
        Container(
          height: 300,
          margin: const EdgeInsets.only(bottom: 16),
          child: widget.exerciseVolumeData.length > 6
              ? _buildScrollableChart()
              : _buildFixedChart(),
        ),
      ],
    );
  }

  Widget _buildFixedChart() {
    // For fewer exercises, show a static chart
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 16.0),
      child: BarChart(
        BarChartData(
          maxY: _getMaxVolume() * 1.1, // Add 10% space at top
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: _calculateChartInterval(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
            drawVerticalLine: false,
          ),
          titlesData: _getChartTitles(),
          barGroups: _generateBarGroups(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 120,
              direction: TooltipDirection.auto,
              getTooltipColor: (value) => Colors.grey.shade800,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final exercise = widget.exerciseVolumeData[group.x.toInt()];
                return BarTooltipItem(
                  '${exercise['name']}\n${exercise['formattedVolume']}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            touchCallback: (FlTouchEvent event, barTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    barTouchResponse == null ||
                    barTouchResponse.spot == null) {
                  touchedIndex = -1;
                  return;
                }
                touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableChart() {
    // For many exercises, make it scrollable
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Column(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Colors.white, Colors.white.withOpacity(0.05)],
                  stops: const [0.95, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  // Make width based on number of bars
                  width: widget.exerciseVolumeData.length * 60.0 + 100,
                  child: BarChart(
                    BarChartData(
                      maxY: _getMaxVolume() * 1.1,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _calculateChartInterval(),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        ),
                        drawVerticalLine: false,
                      ),
                      titlesData: _getScrollableChartTitles(),
                      barGroups: _generateBarGroups(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipMargin: 8,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          maxContentWidth: 120,
                          direction: TooltipDirection.auto,
                          getTooltipColor: (value) => Colors.grey.shade800,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final exercise =
                                widget.exerciseVolumeData[group.x.toInt()];
                            return BarTooltipItem(
                              '${exercise['name']}\n${exercise['formattedVolume']}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        touchCallback: (FlTouchEvent event, barTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                barTouchResponse == null ||
                                barTouchResponse.spot == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex =
                                barTouchResponse.spot!.touchedBarGroupIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  "Scroll to see more",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Generate bar groups for the chart
  List<BarChartGroupData> _generateBarGroups() {
    return List.generate(widget.exerciseVolumeData.length, (index) {
      final exercise = widget.exerciseVolumeData[index];
      final volume = exercise['totalVolume'] as double;
      final muscleGroup = exercise['muscleGroup'] as String;
      final color = _getColorForMuscleGroup(muscleGroup);
      final isSelected = index == touchedIndex;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: volume,
            color: isSelected ? color.withOpacity(0.8) : color,
            width: 22,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxVolume() * 1.1,
              color: Colors.grey.shade100,
            ),
          ),
        ],
      );
    });
  }

  // Titles for the chart axes
  FlTitlesData _getChartTitles() {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value >= widget.exerciseVolumeData.length) {
              return const SizedBox();
            }

            final exerciseName =
                widget.exerciseVolumeData[value.toInt()]['name'] as String;
            // Shorten very long exercise names
            String displayName = exerciseName.length > 10
                ? '${exerciseName.substring(0, 8)}...'
                : exerciseName;

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            if (value == 0) {
              return const SizedBox();
            }

            // Format numbers with units (kg)
            String formatted = '';
            if (value >= 1000) {
              formatted = '${(value / 1000).toStringAsFixed(1)}k';
            } else {
              formatted = '${value.toInt()} kg';
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                formatted,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  // Titles specific for the scrollable chart
  FlTitlesData _getScrollableChartTitles() {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value >= widget.exerciseVolumeData.length) {
              return const SizedBox();
            }

            final exerciseName =
                widget.exerciseVolumeData[value.toInt()]['name'] as String;
            // Keep more of the name in scrollable view
            String displayName = exerciseName.length > 12
                ? '${exerciseName.substring(0, 10)}...'
                : exerciseName;

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            if (value == 0) {
              return const SizedBox();
            }

            // Format numbers with units (kg)
            String formatted = '';
            if (value >= 1000) {
              formatted = '${(value / 1000).toStringAsFixed(1)}k';
            } else {
              formatted = '${value.toInt()} kg';
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                formatted,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  // Calculate interval for the Y-axis based on max volume
  double _calculateChartInterval() {
    final maxVolume = _getMaxVolume();

    // Use fewer intervals for better readability
    // This will show 4-6 divisions on the Y axis
    if (maxVolume < 500) return 100;
    if (maxVolume < 1000) return 250;
    if (maxVolume < 3000) return 500;
    if (maxVolume < 6000) return 1000;
    if (maxVolume < 10000) return 2000;
    return 5000;
  }

  // Get the maximum volume for Y-axis scaling
  double _getMaxVolume() {
    if (widget.exerciseVolumeData.isEmpty) return 1000;

    double max = 0;
    for (var exercise in widget.exerciseVolumeData) {
      final volume = exercise['totalVolume'] as double;
      if (volume > max) max = volume;
    }

    return max == 0 ? 1000 : max;
  }

  // Empty state widget when no data is available
  Widget _buildEmptyState() {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No exercise volume data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Log workouts with weights and reps to see which exercises contribute most to your total volume',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
