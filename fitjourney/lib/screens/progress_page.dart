import 'package:flutter/material.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  // Selected time filter
  String _timeFilter = 'Weekly';
  final List<String> _timeFilters = ['Weekly', 'Monthly', 'All Time'];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // TODO: Show options menu
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Time filter chips
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _timeFilters.length,
                  itemBuilder: (context, index) {
                    final filter = _timeFilters[index];
                    final isSelected = filter == _timeFilter;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _timeFilter = filter;
                          });
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Content area - scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      
                      // Workout Volume Section
                      _buildSectionHeader('Workout Volume', 'Last 7 days'),
                      const SizedBox(height: 16),
                      
                      // Placeholder for volume chart
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Workout Volume Chart',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Muscle Group Focus Section
                      _buildSectionHeader('Muscle Group Focus', ''),
                      const SizedBox(height: 16),
                      
                      // Muscle group distribution
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Placeholder for pie chart
                          Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                'Pie Chart',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          
                          // Legend - expanded to show all muscle groups
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLegendItem('Chest', '18%', Colors.blue),
                                const SizedBox(height: 8),
                                _buildLegendItem('Back', '15%', Colors.green),
                                const SizedBox(height: 8),
                                _buildLegendItem('Legs', '20%', Colors.orange),
                                const SizedBox(height: 8),
                                _buildLegendItem('Shoulders', '12%', Colors.purple),
                                const SizedBox(height: 8),
                                _buildLegendItem('Biceps', '10%', Colors.red),
                                const SizedBox(height: 8),
                                _buildLegendItem('Triceps', '10%', Colors.teal),
                                const SizedBox(height: 8),
                                _buildLegendItem('Abs', '15%', Colors.amber),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Strength Gains Section
                      _buildSectionHeader('Strength Gains', ''),
                      const SizedBox(height: 16),
                      
                      // Strength progress bars with more context
                      _buildEnhancedProgressBar(
                        exercise: 'Bench Press',
                        startWeight: 135,
                        currentWeight: 185,
                        goalWeight: 225,
                        color: Colors.blue,
                        unit: 'lbs',
                      ),
                      const SizedBox(height: 16),
                      
                      _buildEnhancedProgressBar(
                        exercise: 'Deadlift',
                        startWeight: 185,
                        currentWeight: 275,
                        goalWeight: 350,
                        color: Colors.green,
                        unit: 'lbs',
                      ),
                      const SizedBox(height: 16),
                      
                      _buildEnhancedProgressBar(
                        exercise: 'Squat',
                        startWeight: 165,
                        currentWeight: 225,
                        goalWeight: 315,
                        color: Colors.orange,
                        unit: 'lbs',
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }
  
  Widget _buildLegendItem(String label, String percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          percentage,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  Widget _buildEnhancedProgressBar({
    required String exercise,
    required double startWeight,
    required double currentWeight,
    required double goalWeight,
    required Color color,
    required String unit,
  }) {
    // Calculate progress percentage
    final progress = (currentWeight - startWeight) / (goalWeight - startWeight);
    final improvementPercent = ((currentWeight - startWeight) / startWeight * 100).toInt();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise name and improvement percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              exercise,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Text(
              '+$improvementPercent% since starting',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Weight values above bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$startWeight $unit',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '$currentWeight $unit',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$goalWeight $unit',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        
        // Progress bar
        Stack(
          children: [
            // Background bar
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Progress fill
            Container(
              height: 10,
              width: MediaQuery.of(context).size.width * 0.85 * progress, // Account for padding
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Current marker
            Positioned(
              left: MediaQuery.of(context).size.width * 0.85 * progress - 5, // Center marker on progress point
              child: Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}