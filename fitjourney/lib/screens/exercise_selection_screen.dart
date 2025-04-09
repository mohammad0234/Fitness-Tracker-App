// lib/screens/exercise_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/services/progress_service.dart';
import 'package:fitjourney/database_models/exercise.dart';
import 'package:fitjourney/screens/exercise_progress_screen.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  final ProgressService _progressService = ProgressService.instance;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _exercises = [];
  String _searchQuery = '';
  String _selectedMuscleGroup = 'All';
  List<String> _muscleGroups = ['All'];
  
  // For favoriting functionality (to be implemented)
  Set<int> _favoriteExerciseIds = {};

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all muscle groups
      final muscleGroups = await _workoutService.getAllMuscleGroups();
      
      // Get all exercises the user has performed
      final exercises = await _loadUserExercises();
      
      setState(() {
        _exercises = exercises;
        _muscleGroups = ['All', ...muscleGroups];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading exercises: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading exercises: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadUserExercises() async {
    // Get all personal bests to find which exercises the user has performed
    final personalBests = await _progressService.getAllPersonalBests();
    
    // For exercises without personal bests, get all exercises the user has logged
    //final allExercises = await _workoutService.getAllExercises();
    
    // Convert to a unified format with usage info
    List<Map<String, dynamic>> exercisesList = [];
    
    // First add exercises with personal bests
    for (var pb in personalBests) {
      exercisesList.add({
        'exercise': Exercise(
          exerciseId: pb['exerciseId'],
          name: pb['exerciseName'],
          muscleGroup: pb['muscleGroup'],
        ),
        'personalBest': pb['maxWeight'],
        'lastUsed': pb['date'],
        'hasPersonalBest': true,
      });
    }
    
    // Add other exercises the user might have performed but without PBs
    // This would require additional DB query to check usage
    // For now, we'll just use the personal bests list
    
    return exercisesList;
  }

  List<Map<String, dynamic>> _getFilteredExercises() {
    return _exercises.where((exerciseData) {
      final exercise = exerciseData['exercise'] as Exercise;
      
      // Apply search filter
      final matchesSearch = _searchQuery.isEmpty || 
          exercise.name.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Apply muscle group filter
      final matchesMuscleGroup = _selectedMuscleGroup == 'All' || 
          exercise.muscleGroup == _selectedMuscleGroup;
      
      return matchesSearch && matchesMuscleGroup;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredExercises = _getFilteredExercises();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Exercise Progress'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Muscle group filter
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _muscleGroups.length,
              itemBuilder: (context, index) {
                final muscleGroup = _muscleGroups[index];
                final isSelected = muscleGroup == _selectedMuscleGroup;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(muscleGroup),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedMuscleGroup = muscleGroup;
                        });
                      }
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
          
          const SizedBox(height: 8),
          
          // Exercises list
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredExercises.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredExercises.length,
                    itemBuilder: (context, index) {
                      return _buildExerciseCard(filteredExercises[index]);
                    },
                  ),
          ),
        ],
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
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedMuscleGroup != 'All'
              ? 'No exercises match your filters'
              : 'No exercises found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedMuscleGroup != 'All'
              ? 'Try adjusting your search or filters'
              : 'Log workouts to track exercise progress',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildExerciseCard(Map<String, dynamic> exerciseData) {
    final exercise = exerciseData['exercise'] as Exercise;
    final personalBest = exerciseData['personalBest'] as double?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseProgressScreen(exerciseId: exercise.exerciseId!),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Exercise icon with muscle group color
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getColorForMuscleGroup(exercise.muscleGroup ?? ''),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              
              // Exercise details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      exercise.muscleGroup ?? 'Uncategorized',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (personalBest != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Best: ${personalBest.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Arrow icon
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getColorForMuscleGroup(String muscleGroup) {
    // Map muscle groups to colors
    final Map<String, Color> muscleGroupColors = {
      'Chest': Colors.red.shade400,
      'Back': Colors.blue.shade400,
      'Legs': Colors.green.shade400,
      'Shoulders': Colors.purple.shade400,
      'Biceps': Colors.orange.shade400,
      'Triceps': Colors.cyan.shade400,
    };
    
    return muscleGroupColors[muscleGroup] ?? Colors.grey.shade400;
  }
}