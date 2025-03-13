import 'package:flutter/material.dart';
import 'log_workout_flow.dart';
//import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  // Filter options
  String _selectedFilter = 'All Workouts';
  final List<String> _filterOptions = ['All Workouts', 'Upper Body', 'Lower Body'];
  
  // Date filter
  String _dateFilter = 'All Time';
  final List<String> _dateFilterOptions = ['All Time', 'This Week', 'This Month', 'Last 3 Months'];
  
  // Placeholder workout data
  final List<Map<String, dynamic>> _workouts = [
    {
      'name': 'Upper Body Workout',
      'date': DateTime.now(),
      'duration': 45,
      'exercises': 8,
      'time': '9:30 AM',
      'muscles': ['Chest', 'Arms'],
    },
    {
      'name': 'Leg Day',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'duration': 60,
      'exercises': 8,
      'time': '2:15 PM',
      'muscles': ['Legs', 'Core'],
    },
    // Add more placeholder workouts if needed
  ];

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Workouts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Date filter
                  const Text(
                    'Date Range',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _dateFilterOptions.map((option) {
                      return ChoiceChip(
                        label: Text(option),
                        selected: _dateFilter == option,
                        onSelected: (selected) {
                          setModalState(() {
                            _dateFilter = option;
                          });
                          setState(() {
                            _dateFilter = option;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  
                  // Muscle group filter
                  const Text(
                    'Workout Type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _filterOptions.map((option) {
                      return ChoiceChip(
                        label: Text(option),
                        selected: _selectedFilter == option,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedFilter = option;
                          });
                          setState(() {
                            _selectedFilter = option;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Workouts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      // Filter button
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: _showFilterDialog,
                        tooltip: 'Filter workouts',
                      ),
                      // Notification bell
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          // TODO: Handle notifications
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Filter chips/tags display
              Row(
                children: [
                  if (_selectedFilter != 'All Workouts' || _dateFilter != 'All Time')
                    const Text(
                      'Active Filters:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_selectedFilter != 'All Workouts')
                    Chip(
                      label: Text(_selectedFilter),
                      backgroundColor: Colors.blue.shade100,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedFilter = 'All Workouts';
                        });
                      },
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(width: 4),
                  if (_dateFilter != 'All Time')
                    Chip(
                      label: Text(_dateFilter),
                      backgroundColor: Colors.blue.shade100,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _dateFilter = 'All Time';
                        });
                      },
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              
              // Filter chips
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final filter = _filterOptions[index];
                    final isSelected = filter == _selectedFilter;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.blue : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // Workout history - grouped by date
              Expanded(
                child: _workouts.isEmpty 
                  ? _buildEmptyState()
                  : ListView(
                      children: _buildWorkoutGroups(),
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogWorkoutFlow()),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No workouts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to log your first workout',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildWorkoutGroups() {
    // Group workouts by date
    Map<String, List<Map<String, dynamic>>> groupedWorkouts = {};
    
    for (var workout in _workouts) {
      final DateTime date = workout['date'] as DateTime;
      final String groupKey = _isToday(date) 
          ? 'TODAY' 
          : _isYesterday(date) 
              ? 'YESTERDAY' 
              : '${date.month}/${date.day}/${date.year}';
      
      if (!groupedWorkouts.containsKey(groupKey)) {
        groupedWorkouts[groupKey] = [];
      }
      
      // Apply filters
      bool passesTypeFilter = _selectedFilter == 'All Workouts' || 
                             (workout['name'] as String).contains(_selectedFilter);
      
      bool passesDateFilter = true;  // Default
      if (_dateFilter == 'This Week') {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        passesDateFilter = date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
      } else if (_dateFilter == 'This Month') {
        final now = DateTime.now();
        passesDateFilter = date.month == now.month && date.year == now.year;
      } else if (_dateFilter == 'Last 3 Months') {
        final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
        passesDateFilter = date.isAfter(threeMonthsAgo);
      }
      
      if (passesTypeFilter && passesDateFilter) {
        groupedWorkouts[groupKey]!.add(workout);
      }
    }
    
    // Build UI for each group
    List<Widget> groups = [];
    
    groupedWorkouts.forEach((date, workouts) {
      if (workouts.isNotEmpty) {
        groups.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        );
        
        workouts.forEach((workout) {
          groups.add(_buildWorkoutCard(workout));
        });
        
        groups.add(const SizedBox(height: 16));
      }
    });
    
    return groups;
  }
  
  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to workout details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    workout['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    workout['time'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${workout['duration']} minutes',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.fitness_center, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${workout['exercises']} exercises',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (workout['muscles'] as List<String>).map((muscle) {
                  return Chip(
                    label: Text(
                      muscle,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.grey.shade100,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
}