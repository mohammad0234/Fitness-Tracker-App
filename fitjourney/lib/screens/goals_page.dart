import 'package:flutter/material.dart';
import 'package:fitjourney/services/goal_service.dart';
//import 'package:fitjourney/database_models/goal.dart';
import 'package:intl/intl.dart';
import 'log_goal_flow.dart';
import 'package:fitjourney/screens/goal_detail_screen.dart';


class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  // Data holders
  List<Map<String, dynamic>> _activeGoals = [];
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _completedGoals = [];
  
  // UI states
  bool _showAllCompletedGoals = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadGoalData();
  }
  
  Future<void> _loadGoalData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Update all goal progress first
      await GoalService.instance.updateAllGoalsProgress();
      
      // Get active goals and prepare them for display
      final activeGoals = await GoalService.instance.getActiveGoals();
      final List<Map<String, dynamic>> formattedActiveGoals = [];
      
      for (final goal in activeGoals) {
        final goalInfo = await GoalService.instance.getGoalDisplayInfo(goal);
        formattedActiveGoals.add(goalInfo);
      }
      
      // Get completed goals
      final completedGoals = await GoalService.instance.getCompletedGoals();
      final List<Map<String, dynamic>> formattedCompletedGoals = [];
      
      for (final goal in completedGoals) {
        final goalInfo = await GoalService.instance.getGoalDisplayInfo(goal);
        formattedCompletedGoals.add({
          'title': goalInfo['title'],
          'completedOn': DateFormat('MMM d, yyyy').format(goal.endDate),
        });
      }
      
      // Get achievements
      final achievements = await _loadAchievements();
      
      // Update state with the loaded data
      setState(() {
        _activeGoals = formattedActiveGoals;
        _completedGoals = formattedCompletedGoals;
        _achievements = achievements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      print('Error loading goals: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> _loadAchievements() async {
    try {
      // For now, we'll use milestone data to create achievement badges
      // This could be expanded in the future
      
      final milestones = await _fetchRecentMilestones();
      final achievements = <Map<String, dynamic>>[];
      
      // Convert milestones to achievement badge format
      for (final milestone in milestones) {
        final Map<String, dynamic> achievement = {};
        
        switch (milestone['type']) {
          case 'PersonalBest':
            achievement['name'] = 'Strength Master';
            achievement['icon'] = Icons.fitness_center;
            achievement['color'] = Colors.blue;
            break;
          case 'LongestStreak':
            achievement['name'] = '${milestone['value']} Day Streak';
            achievement['icon'] = Icons.local_fire_department;
            achievement['color'] = Colors.orange;
            break;
          case 'GoalAchieved':
            achievement['name'] = 'Goal Crusher';
            achievement['icon'] = Icons.emoji_events;
            achievement['color'] = Colors.green;
            break;
        }
        
        if (achievement.isNotEmpty) {
          achievements.add(achievement);
        }
      }
      
      // If we have no achievements yet, add placeholder achievements
      // This ensures the UI doesn't look empty for new users
      if (achievements.isEmpty) {
        achievements.addAll([
          {
            'name': 'Get Started',
            'icon': Icons.star,
            'color': Colors.amber,
          },
        ]);
      }
      
      return achievements;
    } catch (e) {
      print('Error loading achievements: $e');
      // Return some default achievements in case of error
      return [
        {
          'name': 'Get Started',
          'icon': Icons.star,
          'color': Colors.amber,
        },
      ];
    }
  }
  
  Future<List<Map<String, dynamic>>> _fetchRecentMilestones() async {
    // This would typically be fetched from the database
    // For now, we'll return a simple placeholder list
    return [
      {
        'type': 'PersonalBest',
        'value': 100,
      },
      {
        'type': 'LongestStreak',
        'value': 7,
      },
      {
        'type': 'GoalAchieved',
        'value': null,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    if (_hasError) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error Loading Goals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadGoalData,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
                    'Goals',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      // TODO: Show notifications
                    },
                  ),
                ],
              ),
              
              // Main content - scrollable
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadGoalData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        
                        // Active Goals Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Active Goals',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LogGoalFlow()),
                                ).then((_) => _loadGoalData());
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New Goal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Active goals list
                        if (_activeGoals.isEmpty)
                          _buildEmptyGoalsMessage()
                        else
                          ..._activeGoals.map((goal) => _buildGoalCard(goal)),
                        
                        const SizedBox(height: 32),
                        
                        // Achievements Section
                        const Text(
                          'Achievements',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Achievement badges
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _achievements.length,
                            itemBuilder: (context, index) {
                              final achievement = _achievements[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: achievement['color'].withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        achievement['icon'],
                                        color: achievement['color'],
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      achievement['name'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Completed Goals Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Completed Goals',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_completedGoals.length > 2)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showAllCompletedGoals = !_showAllCompletedGoals;
                                  });
                                },
                                child: Text(_showAllCompletedGoals ? 'Show Less' : 'See All'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Completed goals list
                        if (_completedGoals.isEmpty)
                          _buildEmptyCompletedGoalsMessage()
                        else
                          ..._completedGoals
                              .take(_showAllCompletedGoals ? _completedGoals.length : 2)
                              .map((goal) => _buildCompletedGoalItem(goal)),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyGoalsMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No active goals yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set your first goal to track your fitness progress',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogGoalFlow()),
              ).then((_) => _loadGoalData());
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyCompletedGoalsMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Complete goals to see them here',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
  
  Widget _buildGoalCard(Map<String, dynamic> goal) {
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: InkWell(  // Add InkWell for tap detection
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailScreen(goalId: goal['goalId']),
          ),
        ).then((result) {
          // Refresh the goals list if a goal was deleted or updated
          if (result == true) {
            _loadGoalData();
          }
        });
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
                  goal['title'] ?? 'Goal',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  goal['isExpired'] == true
                    ? 'Expired'
                    : '${goal['daysLeft']} days left',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: goal['isExpired'] == true
                        ? Colors.red.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal['progress'] ?? 0.0,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal['isExpired'] == true ? Colors.grey : Colors.blue,
                ),
                minHeight: 8,
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (goal['type'] == 'ExerciseTarget') ...[
              // Strength goal stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal['exerciseName'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current: ${goal['current']?.toStringAsFixed(1) ?? 0}kg',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Target: ${goal['target']?.toStringAsFixed(1) ?? 0}kg',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (goal['type'] == 'WorkoutFrequency') ...[
              // Frequency goal stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Workouts completed: ${goal['current']?.toInt() ?? 0}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Target: ${goal['target']?.toInt() ?? 0}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
  
  Widget _buildCompletedGoalItem(Map<String, dynamic> goal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                size: 16,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal['title'] ?? 'Completed Goal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Completed on ${goal['completedOn']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  
}