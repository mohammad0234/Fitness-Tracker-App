// lib/screens/progress_page.dart
import 'package:fitjourney/screens/exercise_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:fitjourney/services/progress_service.dart';
import 'package:fitjourney/database_models/progress_data.dart';
import 'package:fitjourney/widgets/charts/workout_volume_chart.dart';
import 'package:fitjourney/widgets/charts/muscle_group_pie_chart.dart';
import 'package:fitjourney/widgets/charts/workout_frequency_chart.dart';
import 'package:fitjourney/screens/exercise_selection_screen.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  // Selected time filter
  String _timeFilter = 'Weekly';
  final List<String> _timeFilters = ['Weekly', 'Monthly', '3 Months', 'All Time'];
  
  // Services
  final ProgressService _progressService = ProgressService.instance;
  
  // Data future
  Future<ProgressData>? _dataFuture;
  
  // Loading state
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  // Load all data at once
  void _loadData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    _dataFuture = _fetchAllProgressData();
    
    _dataFuture!.then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
    });
  }
  
  // Fetch all data from the progress service
  Future<ProgressData> _fetchAllProgressData() async {
    final dateRange = _progressService.getDateRangeForPeriod(_timeFilter);
    
    try {
      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        _progressService.getWorkoutVolumeData(
          startDate: dateRange['startDate']!,
          endDate: dateRange['endDate']!,
        ),
        _progressService.getMuscleGroupDistribution(
          startDate: dateRange['startDate']!,
          endDate: dateRange['endDate']!,
        ),
        _progressService.getWorkoutFrequencyData(
          startDate: dateRange['startDate']!,
          endDate: dateRange['endDate']!,
        ),
        _progressService.getProgressSummary(),
        _progressService.getAllPersonalBests(),
      ]);
      
      return ProgressData(
        volumeData: results[0] as List<Map<String, dynamic>>,
        muscleGroupData: results[1] as List<Map<String, dynamic>>,
        frequencyData: results[2] as Map<String, dynamic>,
        progressSummary: results[3] as Map<String, dynamic>,
        personalBests: results[4] as List<Map<String, dynamic>>,
      );
    } catch (e) {
      // Forward the error to be handled by the FutureBuilder
      throw 'Error loading progress data: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with options
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
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
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadData,
                    tooltip: 'Refresh data',
                  ),
                ],
              ),
            ),
            
            // Time filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
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
                        onSelected: _isLoading 
                            ? null 
                            : (selected) {
                                if (selected && filter != _timeFilter) {
                                  setState(() {
                                    _timeFilter = filter;
                                    _loadData(); // Reload data with new filter
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
            ),
            
            // Main content area - uses a single FutureBuilder for all charts
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _hasError 
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        _loadData();
                      },
                      child: FutureBuilder<ProgressData>(
                        future: _dataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading progress data',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      snapshot.error.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          final data = snapshot.data ?? ProgressData.empty();
                          
                          // Check if we have any data to display
                          final bool hasNoData = data.volumeData.isEmpty && 
                                                data.muscleGroupData.isEmpty && 
                                                data.frequencyData.isEmpty;
                          
                          if (hasNoData) {
                            return _buildEmptyState();
                          }
                          
                          // Return the progress charts
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Workout Volume Chart
                                WorkoutVolumeChart(
                                  volumeData: data.volumeData,
                                  timeRange: _timeFilter,
                                ),
                                const SizedBox(height: 24),
                                
                                // Muscle Group Distribution Chart
                                MuscleGroupPieChart(
                                  muscleGroupData: data.muscleGroupData,
                                ),
                                const SizedBox(height: 24),
                                
                                // Workout Frequency Chart
                                WorkoutFrequencyChart(
                                  frequencyData: data.frequencyData,
                                ),
                                const SizedBox(height: 24),
                                
                                // Personal Bests Section (if available)
                                if (data.personalBests.isNotEmpty)
                                  _buildPersonalBestsSection(data.personalBests),
                                
                                const SizedBox(height: 24),
                                
                                // Track Exercise Progress section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Text(
                                        'Track Exercise Progress',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Card(
                                        elevation: 1,
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
                                                  Icon(
                                                    Icons.timeline,
                                                    color: Colors.blue.shade700,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Expanded(
                                                    child: Text(
                                                      'View detailed progress for specific exercises',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Track your strength progression over time for individual exercises. See personal bests, improvement trends, and historical performance.',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => const ExerciseSelectionScreen(),
                                                      ),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                  ),
                                                  child: const Text('Select Exercise to Track'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24), // Bottom padding
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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
              Icons.fitness_center,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No workout data yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging workouts to see your progress visualized here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to log workout flow
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
              onPressed: _loadData,
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
  
  Widget _buildPersonalBestsSection(List<Map<String, dynamic>> personalBests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Personal Bests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: personalBests.length,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemBuilder: (context, index) {
              final personalBest = personalBests[index];
              return _buildPersonalBestCard(personalBest);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPersonalBestCard(Map<String, dynamic> personalBest) {
    return Card(
      margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to exercise progress screen when tapping on a personal best
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseProgressScreen(exerciseId: personalBest['exerciseId']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                personalBest['exerciseName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                personalBest['muscleGroup'],
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${personalBest['maxWeight']} kg',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (personalBest['reps'] != null)
                Text(
                  '${personalBest['reps']} reps',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              Text(
                personalBest['formattedDate'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}