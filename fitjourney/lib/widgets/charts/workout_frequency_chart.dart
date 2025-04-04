import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
//import 'package:intl/intl.dart';

class WorkoutFrequencyChart extends StatelessWidget {
  final Map<String, dynamic> frequencyData;
  final bool isLoading;

  const WorkoutFrequencyChart({
    Key? key,
    required this.frequencyData,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (frequencyData.isEmpty || 
        (frequencyData['calendarData'] as List).isEmpty ||
        frequencyData['totalWorkouts'] == 0) {
      return _buildEmptyState();
    }

    // Extract data
    final Map<String, int> workoutsByWeekday = 
        Map<String, int>.from(frequencyData['workoutsByWeekday'] as Map);
    final int totalWorkouts = frequencyData['totalWorkouts'] as int;
    final String formattedFrequency = frequencyData['formattedFrequency'] as String;
    final int currentStreak = frequencyData['currentStreak'] as int;
    final int longestStreak = frequencyData['longestStreak'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Workout Frequency',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  '$totalWorkouts workouts ($formattedFrequency)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Streak information
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _buildStreakCard(
                'Current Streak',
                '$currentStreak days',
                Icons.local_fire_department,
                Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildStreakCard(
                'Longest Streak',
                '$longestStreak days',
                Icons.emoji_events,
                Colors.amber,
              ),
            ],
          ),
        ),
        
        // Weekly distribution bar chart
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: const Text(
            'Workouts by Day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxWorkoutsPerDay() + 1,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.purple.shade700,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final weekday = _getWeekdayForIndex(groupIndex);
                      final count = workoutsByWeekday[weekday] ?? 0;
                      return BarTooltipItem(
                        '$weekday\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: '$count workouts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                      getTitlesWidget: _bottomTitles,
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: _leftTitles,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                barGroups: _getBarGroups(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
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
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups() {
    final Map<String, int> workoutsByWeekday = 
        Map<String, int>.from(frequencyData['workoutsByWeekday'] as Map);
    
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    return List.generate(7, (index) {
      final weekday = weekdays[index];
      final count = workoutsByWeekday[weekday] ?? 0;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade300,
                Colors.purple.shade600,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final style = TextStyle(
      color: Colors.grey.shade700,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text(weekdays[value.toInt()], style: style),
    );
  }

  Widget _leftTitles(double value, TitleMeta meta) {
    if (value == 0) {
      return const SizedBox.shrink();
    }
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 0,
      child: Text(
        value.toInt().toString(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 10,
        ),
      ),
    );
  }

  int _getMaxWorkoutsPerDay() {
    final Map<String, int> workoutsByWeekday = 
        Map<String, int>.from(frequencyData['workoutsByWeekday'] as Map);
    
    int maxWorkouts = 0;
    workoutsByWeekday.forEach((_, count) {
      if (count > maxWorkouts) {
        maxWorkouts = count;
      }
    });
    
    return maxWorkouts == 0 ? 5 : maxWorkouts;
  }

  String _getWeekdayForIndex(int index) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[index];
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 50,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No workout frequency data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log workouts to track your consistency',
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