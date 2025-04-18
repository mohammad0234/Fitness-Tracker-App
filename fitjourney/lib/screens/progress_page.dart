// lib/screens/progress_page.dart
import 'package:fitjourney/screens/exercise_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:fitjourney/services/progress_service.dart';
import 'package:fitjourney/database_models/progress_data.dart';
import 'package:fitjourney/widgets/charts/workout_volume_chart.dart';
import 'package:fitjourney/widgets/charts/muscle_group_pie_chart.dart';
import 'package:fitjourney/screens/calendar_streak_screen.dart';
import 'package:fitjourney/services/workout_service.dart';
import 'package:fitjourney/database_models/exercise.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/widgets/charts/exercise_volume_chart.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        toolbarHeight: 38, // Reduce the toolbar height
        centerTitle: true,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40), // Reduce tab bar height
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                text: 'Insights',
                icon: Icon(Icons.insights, size: 20),
              ),
              Tab(
                text: 'Exercise',
                icon: Icon(Icons.fitness_center, size: 20),
              ),
              Tab(
                text: 'Calendar',
                icon: Icon(Icons.calendar_month, size: 20),
              ),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
            ),
            padding: EdgeInsets.zero, // Remove padding around tabs
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Tab 1: Insights
          InsightsTab(),

          // Tab 2: Exercise Progress
          ExerciseProgressTab(),

          // Tab 3: Calendar View
          CalendarViewTab(),
        ],
      ),
    );
  }
}

// Tab 1: Insights Tab - Contains workout volume chart, muscle group pie chart, and personal bests
class InsightsTab extends StatefulWidget {
  const InsightsTab({Key? key}) : super(key: key);

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  // Selected time filter
  String _timeFilter = 'Weekly';
  final List<String> _timeFilters = [
    'Weekly',
    'Monthly',
    '3 Months',
    'All Time'
  ];

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
        _progressService.getProgressSummary(),
        _progressService.getAllPersonalBests(),
        _progressService.getExerciseVolumeData(
          startDate: dateRange['startDate']!,
          endDate: dateRange['endDate']!,
        ),
      ]);

      return ProgressData(
        volumeData: results[0] as List<Map<String, dynamic>>,
        muscleGroupData: results[1] as List<Map<String, dynamic>>,
        progressSummary: results[2] as Map<String, dynamic>,
        personalBests: results[3] as List<Map<String, dynamic>>,
        exerciseVolumeData: results[4] as List<Map<String, dynamic>>,
      );
    } catch (e) {
      // Forward the error to be handled by the FutureBuilder
      throw 'Error loading progress data: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0),
          child: Text(
            'Time Period: $_timeFilter',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),

        // Time filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          child: SizedBox(
            height: 32, // Reduced height
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
                      fontSize: 12, // Smaller text
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 0), // Smaller padding
                    visualDensity: VisualDensity.compact, // More compact
                  ),
                );
              },
            ),
          ),
        ),

        // Main content area
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
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
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
                              data.muscleGroupData.isEmpty;

                          if (hasNoData) {
                            return _buildEmptyState();
                          }

                          // Return the progress charts
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Add extra spacing at the top
                                const SizedBox(height: 12),

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

                                // Exercise Volume Chart
                                ExerciseVolumeChart(
                                  exerciseVolumeData: data.exerciseVolumeData,
                                ),
                                const SizedBox(height: 24),

                                // Personal Bests Section (if available)
                                if (data.personalBests.isNotEmpty)
                                  _buildPersonalBestsSection(
                                      data.personalBests),

                                const SizedBox(height: 24), // Bottom padding
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              builder: (context) => ExerciseProgressScreen(
                  exerciseId: personalBest['exerciseId']),
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

// Tab 2: Exercise Progress Tab - Contains exercise selection and progress view
class ExerciseProgressTab extends StatefulWidget {
  const ExerciseProgressTab({Key? key}) : super(key: key);

  @override
  State<ExerciseProgressTab> createState() => _ExerciseProgressTabState();
}

class _ExerciseProgressTabState extends State<ExerciseProgressTab> {
  // Track the current view state
  bool _showingExerciseDetails = false;
  int? _currentExerciseId;
  String _exerciseName = '';

  @override
  Widget build(BuildContext context) {
    if (_showingExerciseDetails && _currentExerciseId != null) {
      // Show the exercise progress details screen with a custom header
      return Column(
        children: [
          // Custom header with back button and exercise name
          Container(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _showingExerciseDetails = false;
                      _currentExerciseId = null;
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back,
                          size: 20, color: Colors.black87),
                      const SizedBox(width: 8),
                      const Text(
                        'Back to Exercise List',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Exercise progress screen with custom properties
          Expanded(
            child: _CustomExerciseProgressScreen(
              exerciseId: _currentExerciseId!,
            ),
          ),
        ],
      );
    } else {
      // Show the exercise selection screen with a custom navigation handler
      return _InternalExerciseSelectionScreen(
        onExerciseSelected: (exerciseId, exerciseName) {
          setState(() {
            _showingExerciseDetails = true;
            _currentExerciseId = exerciseId;
            _exerciseName = exerciseName;
          });
        },
      );
    }
  }
}

// Custom version of ExerciseProgressScreen without AppBar
class _CustomExerciseProgressScreen extends StatefulWidget {
  final int exerciseId;

  const _CustomExerciseProgressScreen({
    Key? key,
    required this.exerciseId,
  }) : super(key: key);

  @override
  State<_CustomExerciseProgressScreen> createState() =>
      _CustomExerciseProgressScreenState();
}

class _CustomExerciseProgressScreenState
    extends State<_CustomExerciseProgressScreen> {
  final ProgressService _progressService = ProgressService.instance;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _exerciseData = {};

  // Sorting and filtering
  String _sortBy = 'Date (newest)';
  final List<String> _sortOptions = [
    'Date (newest)',
    'Date (oldest)',
    'Weight (highest)',
    'Weight (lowest)'
  ];

  @override
  void initState() {
    super.initState();
    _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get exercise progress data
      final exerciseData =
          await _progressService.getExerciseProgressData(widget.exerciseId);

      setState(() {
        _exerciseData = exerciseData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading exercise data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _getSortedProgressPoints() {
    if (_exerciseData.isEmpty || !_exerciseData.containsKey('progressPoints')) {
      return [];
    }

    final progressPoints =
        List<Map<String, dynamic>>.from(_exerciseData['progressPoints']);

    switch (_sortBy) {
      case 'Date (newest)':
        progressPoints.sort(
            (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        break;
      case 'Date (oldest)':
        progressPoints.sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
        break;
      case 'Weight (highest)':
        progressPoints.sort(
            (a, b) => (b['weight'] as double).compareTo(a['weight'] as double));
        break;
      case 'Weight (lowest)':
        progressPoints.sort(
            (a, b) => (a['weight'] as double).compareTo(b['weight'] as double));
        break;
    }

    return progressPoints;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_exerciseData.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise name as page title
            Text(
              _exerciseData['exerciseName'] ?? 'Exercise Progress',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Summary Card
            _buildSummaryCard(),
            const SizedBox(height: 24),

            // Progress Chart
            const Text(
              'Progress Over Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildProgressChart(),
            const SizedBox(height: 24),

            // History Section with Sorting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Exercise History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  items: _sortOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _sortBy = newValue;
                      });
                    }
                  },
                  hint: const Text('Sort by'),
                  underline: Container(
                    height: 1,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // History Table
            _buildHistoryTable(),
          ],
        ),
      ),
    );
  }

  // Use the same helper methods from the original ExerciseProgressScreen
  Widget _buildSummaryCard() {
    final personalBest = _exerciseData['personalBest'] as double?;
    final startingWeight = _exerciseData['startingWeight'] as double?;
    final improvementPercentage =
        _exerciseData['improvementPercentage'] as double?;
    final exerciseName = _exerciseData['exerciseName'] as String;

    return Card(
      elevation: 2,
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
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.fitness_center,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Progress Summary',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  'Personal Best',
                  personalBest != null
                      ? '${personalBest.toStringAsFixed(1)} kg'
                      : 'N/A',
                  Icons.emoji_events,
                  Colors.amber,
                ),
                _buildSummaryStat(
                  'Starting Weight',
                  startingWeight != null
                      ? '${startingWeight.toStringAsFixed(1)} kg'
                      : 'N/A',
                  Icons.history,
                  Colors.teal,
                ),
                _buildSummaryStat(
                  'Improvement',
                  improvementPercentage != null
                      ? '${improvementPercentage.toStringAsFixed(1)}%'
                      : 'N/A',
                  Icons.trending_up,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Other helper methods would be copied from ExerciseProgressScreen...
  // For brevity, assume they are implemented exactly as in the original screen
  Widget _buildProgressChart() {
    if (!_exerciseData.containsKey('progressPoints') ||
        (_exerciseData['progressPoints'] as List).isEmpty) {
      return _buildEmptyChartState();
    }

    final progressPoints =
        List<Map<String, dynamic>>.from(_exerciseData['progressPoints']);

    // Sort by date for the chart
    progressPoints.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Find min and max weight to set chart scale
    double maxWeight = 0;
    for (var point in progressPoints) {
      final weight = point['weight'] as double;
      if (weight > maxWeight) {
        maxWeight = weight;
      }
    }
    maxWeight = maxWeight == 0 ? 100 : maxWeight * 1.1; // Add 10% space at top

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) {
              return const FlLine(
                color: Color(0xffE0E0E0),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return const FlLine(
                color: Color(0xffE0E0E0),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() < 0 ||
                      value.toInt() >= progressPoints.length) {
                    return const SizedBox();
                  }
                  if (progressPoints.length > 8 && value.toInt() % 2 != 0) {
                    // Skip every other label if there are many data points
                    return const SizedBox();
                  }
                  final date =
                      progressPoints[value.toInt()]['date'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == 0) return const SizedBox(); // Don't show 0 label
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
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
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xffE0E0E0)),
          ),
          minX: 0,
          maxX: progressPoints.length - 1.0,
          minY: 0,
          maxY: maxWeight,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(progressPoints.length, (index) {
                return FlSpot(
                  index.toDouble(),
                  progressPoints[index]['weight'] as double,
                );
              }),
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateInterval() {
    final maxWeight = _getMaxWeight();
    if (maxWeight <= 50) return 10;
    if (maxWeight <= 100) return 20;
    if (maxWeight <= 200) return 50;
    if (maxWeight <= 500) return 100;
    return 200;
  }

  double _calculateDateInterval(List<Map<String, dynamic>> progressPoints) {
    // Show fewer date labels when there are many data points
    if (progressPoints.length > 20) {
      return (progressPoints.length / 5).ceil().toDouble();
    } else if (progressPoints.length > 10) {
      return (progressPoints.length / 4).ceil().toDouble();
    }
    return 1; // Show all date labels for few data points
  }

  double _getMaxWeight() {
    if (!_exerciseData.containsKey('progressPoints') ||
        (_exerciseData['progressPoints'] as List).isEmpty) {
      return 100;
    }

    final progressPoints =
        List<Map<String, dynamic>>.from(_exerciseData['progressPoints']);
    double maxWeight = 0;

    for (var point in progressPoints) {
      final weight = point['weight'] as double;
      if (weight > maxWeight) {
        maxWeight = weight;
      }
    }

    return maxWeight == 0 ? 100 : maxWeight;
  }

  Widget _buildHistoryTable() {
    final progressPoints = _getSortedProgressPoints();

    if (progressPoints.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No history data available for this exercise'),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text('DATE',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('WEIGHT',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 1,
                  child: Text(''),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Table rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: progressPoints.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final point = progressPoints[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        DateFormat('MMM d, yyyy').format(point['date']),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${point['weight'].toStringAsFixed(1)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: point['weight'] == _exerciseData['personalBest']
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 4),
                                const Text('PB',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartState() {
    return SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No progress data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log more workouts with this exercise to see your progress',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
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
              Icons.fitness_center_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No data for this exercise',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log workouts with this exercise to track your progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/log_workout');
              },
              icon: const Icon(Icons.add),
              label: const Text('Log a Workout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              onPressed: _loadExerciseData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Internal version of ExerciseSelectionScreen for use within the tab
class _InternalExerciseSelectionScreen extends StatefulWidget {
  final Function(int, String) onExerciseSelected;

  const _InternalExerciseSelectionScreen({
    Key? key,
    required this.onExerciseSelected,
  }) : super(key: key);

  @override
  State<_InternalExerciseSelectionScreen> createState() =>
      _InternalExerciseSelectionScreenState();
}

class _InternalExerciseSelectionScreenState
    extends State<_InternalExerciseSelectionScreen> {
  final WorkoutService _workoutService = WorkoutService.instance;
  final ProgressService _progressService = ProgressService.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _exercises = [];
  String _searchQuery = '';
  String _selectedMuscleGroup = 'All';
  List<String> _muscleGroups = ['All'];

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

    return Column(
      children: [
        // Header with title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Exercise Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              'No exercise data found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete workouts to track your progress for specific exercises.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exerciseData) {
    final exercise = exerciseData['exercise'] as Exercise;
    final hasPersonalBest = exerciseData['hasPersonalBest'] ?? false;
    final personalBest = exerciseData['personalBest'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Call the callback to show this exercise's progress
          if (exercise.exerciseId != null) {
            widget.onExerciseSelected(exercise.exerciseId!, exercise.name);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.muscleGroup ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    if (hasPersonalBest && personalBest != null) ...[
                      const SizedBox(height: 8),
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
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tab 3: Calendar View Tab - Contains calendar streak view
class CalendarViewTab extends StatefulWidget {
  const CalendarViewTab({Key? key}) : super(key: key);

  @override
  State<CalendarViewTab> createState() => _CalendarViewTabState();
}

class _CalendarViewTabState extends State<CalendarViewTab> {
  @override
  Widget build(BuildContext context) {
    // Use a custom calendar streak screen wrapper that removes the back/refresh buttons
    return const _CustomCalendarStreakScreen();
  }
}

// Custom calendar streak screen wrapper that doesn't show the back and refresh buttons
class _CustomCalendarStreakScreen extends StatelessWidget {
  const _CustomCalendarStreakScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Calendar'),
        automaticallyImplyLeading: false, // Don't show back button
        actions: const [], // No refresh button
        toolbarHeight: 40, // Match the progress page header height
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: false, // Align title to the left
      ),
      body: const CalendarStreakScreen(
        showAppBar: false, // Don't show the calendar's own app bar
      ),
    );
  }
}
