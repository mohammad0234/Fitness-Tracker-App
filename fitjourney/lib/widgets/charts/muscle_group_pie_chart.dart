import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MuscleGroupPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> muscleGroupData;
  final bool isLoading;

  const MuscleGroupPieChart({
    Key? key,
    required this.muscleGroupData,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<MuscleGroupPieChart> createState() => _MuscleGroupPieChartState();
}

class _MuscleGroupPieChartState extends State<MuscleGroupPieChart> {
  int touchedIndex = -1;

  // Define colors for different muscle groups
  final Map<String, Color> muscleGroupColors = {
    'Chest': Colors.red.shade400,
    'Back': Colors.blue.shade400,
    'Legs': Colors.green.shade400,
    'Shoulders': Colors.purple.shade400,
    'Biceps': Colors.orange.shade400,
    'Triceps': Colors.cyan.shade400,
  };

  // Get a color for a muscle group, with a fallback
  Color _getColorForMuscleGroup(String muscleGroup) {
    return muscleGroupColors[muscleGroup] ?? Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.muscleGroupData.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Text(
            'Muscle Group Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            // Pie chart
            SizedBox(
              height: 200,
              width: 200,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _showingSections(),
                ),
              ),
            ),
            // Legend
            Expanded(
              child: SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.muscleGroupData.length,
                        (index) => _buildLegendItem(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Recommendation widget
        _buildMuscleGroupRecommendation(),
      ],
    );
  }

  Widget _buildLegendItem(int index) {
    final data = widget.muscleGroupData[index];
    final isHighlighted = touchedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColorForMuscleGroup(data['muscleGroup']),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data['muscleGroup'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? Colors.black : Colors.black87,
              ),
            ),
          ),
          Text(
            data['formattedPercentage'],
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.black : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _showingSections() {
    return List.generate(
      widget.muscleGroupData.length,
      (i) {
        final data = widget.muscleGroupData[i];
        final isTouched = i == touchedIndex;
        final fontSize = isTouched ? 18.0 : 14.0;
        final radius = isTouched ? 60.0 : 50.0;

        return PieChartSectionData(
          color: _getColorForMuscleGroup(data['muscleGroup']),
          value: data['percentage'],
          title: isTouched ? '${data['formattedPercentage']}' : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart,
              size: 50,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No muscle group data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log workouts to see your distribution',
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

  // New method to build muscle group recommendation
  Widget _buildMuscleGroupRecommendation() {
    // If we have less than 2 muscle groups, don't show a recommendation
    if (widget.muscleGroupData.length < 2) {
      return const SizedBox.shrink();
    }

    // Sort muscle groups by percentage (ascending)
    final sortedData = List<Map<String, dynamic>>.from(widget.muscleGroupData)
      ..sort((a, b) =>
          (a['percentage'] as double).compareTo(b['percentage'] as double));

    // Get the two muscle groups with the lowest percentages
    final muscleGroup1 = sortedData[0]['muscleGroup'] as String;
    final muscleGroup2 = sortedData[1]['muscleGroup'] as String;

    // Create a recommendation message
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommendation:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consider focusing on $muscleGroup1 and $muscleGroup2 in your upcoming workouts to balance your training.',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
