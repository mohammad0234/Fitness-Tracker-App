// lib/screens/calendar_streak_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:fitjourney/database_models/daily_log.dart';
import 'package:fitjourney/database_models/streak.dart';
import 'package:fitjourney/services/workout_service.dart';

class CalendarStreakScreen extends StatefulWidget {
  const CalendarStreakScreen({Key? key}) : super(key: key);

  @override
  State<CalendarStreakScreen> createState() => _CalendarStreakScreenState();
}

class _CalendarStreakScreenState extends State<CalendarStreakScreen> {
  final StreakService _streakService = StreakService.instance;
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<DailyLog>> _events = {};
  List<DailyLog> _dailyLogs = [];
  Streak? _streak;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Calculate date range for past 6 months
      final today = DateTime.now();
      final sixMonthsAgo = DateTime(today.year, today.month - 6, today.day);
      
      // Load daily logs and streak data
      final logs = await _streakService.getDailyLogHistory(sixMonthsAgo, today);
      final streak = await _streakService.getUserStreak();
      
      // Process logs into a format suitable for the calendar
      final events = <DateTime, List<DailyLog>>{};
      
      for (var log in logs) {
        // Normalize the date to remove time component
        final date = DateTime(log.date.year, log.date.month, log.date.day);
        
        if (events[date] == null) {
          events[date] = [];
        }
        events[date]!.add(log);
      }
      
      if (mounted) {
        setState(() {
          _dailyLogs = logs;
          _events = events;
          _streak = streak;
          _isLoading = false;
          _selectedDay = today; // Default select today
        });
      }
    } catch (e) {
      print('Error loading calendar data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Determine the event color based on activity type
  Color _getEventColor(List<DailyLog>? logs) {
    if (logs == null || logs.isEmpty) {
      return Colors.grey.shade200; // No activity
    }
    
    // Prioritize workout over rest if both exist on the same day
    for (var log in logs) {
      if (log.activityType == 'workout') {
        return Colors.blue; // Workout day
      }
    }
    
    return Colors.green.shade300; // Rest day
  }
  
  // Check if a date is part of a milestone streak
  bool _isStreakMilestone(DateTime day) {
    // Create a normalized date for comparison
    final normalizedDate = DateTime(day.year, day.month, day.day);
    
    // Find this date in the daily logs
    for (var log in _dailyLogs) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      
      // Check if dates match
      if (logDate == normalizedDate) {
        // Get all consecutive days from this date backward
        int consecutiveDays = 0;
        DateTime checkDate = normalizedDate;
        
        while (true) {
          // Check if this date has an activity
          bool hasActivity = false;
          for (var checkLog in _dailyLogs) {
            final checkLogDate = DateTime(checkLog.date.year, checkLog.date.month, checkLog.date.day);
            if (checkLogDate == checkDate) {
              hasActivity = true;
              break;
            }
          }
          
          if (!hasActivity) break;
          
          consecutiveDays++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
        
        // Check if this is a 7-day or 30-day milestone
        return consecutiveDays == 7 || consecutiveDays == 30;
      }
    }
    
    return false;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // Add SafeArea to respect system UI boundaries
              child: SingleChildScrollView(
                // Make the whole screen scrollable
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20), // Add extra bottom padding
                  child: Column(
                    children: [
                      // Calendar header with streak info
                      _buildStreakHeader(),
                      
                      // Month navigation
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16, 
                          right: 16, 
                          top: 8,
                          bottom: 0
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                                });
                              },
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_focusedDay),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                final now = DateTime.now();
                                // Don't allow navigating to future months
                                if (_focusedDay.year < now.year || 
                                    (_focusedDay.year == now.year && _focusedDay.month < now.month)) {
                                  setState(() {
                                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Format selector - with reduced vertical padding
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: SegmentedButton<CalendarFormat>(
                          segments: const [
                            ButtonSegment<CalendarFormat>(
                              value: CalendarFormat.week,
                              label: Text('Week'),
                            ),
                            ButtonSegment<CalendarFormat>(
                              value: CalendarFormat.twoWeeks,
                              label: Text('2 weeks'),
                            ),
                            ButtonSegment<CalendarFormat>(
                              value: CalendarFormat.month,
                              label: Text('Month'),
                            ),
                          ],
                          selected: <CalendarFormat>{_calendarFormat},
                          onSelectionChanged: (Set<CalendarFormat> selection) {
                            setState(() {
                              _calendarFormat = selection.first;
                            });
                          },
                        ),
                      ),
                      
                      // Calendar view - reduce vertical padding to save space
                      TableCalendar(
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.now().add(const Duration(days: 1)),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                        
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                        eventLoader: (day) {
                          // Normalize the date to remove time
                          final normalized = DateTime(day.year, day.month, day.day);
                          return _events[normalized] ?? [];
                        },
                        headerVisible: false, // Hide default header
                        daysOfWeekHeight: 20, // Reduce height of day headers
                        rowHeight: 45, // Adjust row height to save space
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: true,
                          markersMaxCount: 1,
                          markersAnchor: 0.9,
                          markerDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          // Reduce padding to save space
                          cellPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          cellMargin: EdgeInsets.zero,
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return null;
                            
                            final isMilestone = _isStreakMilestone(date);
                            
                            // Return a stack with the date number on top of the activity circle
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Activity circle
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _getEventColor(events as List<DailyLog>?),
                                    shape: BoxShape.circle,
                                    border: isMilestone
                                        ? Border.all(color: Colors.orange, width: 2)
                                        : null,
                                  ),
                                ),
                                // Date number (in white for visibility)
                                Text(
                                  date.day.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                // Milestone star (if applicable)
                                if (isMilestone)
                                  const Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.orange,
                                      size: 12,
                                    ),
                                  ),
                              ],
                            );
                          },
                          // Override the default day cell builder to hide the default day number
                          defaultBuilder: (context, day, focusedDay) {
                            // Only show the default text for days without activity
                            final events = _events[DateTime(day.year, day.month, day.day)] ?? [];
                            if (events.isEmpty) {
                              return Container(
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              );
                            }
                            return Container(); // Return empty container, we'll show the date in our marker
                          },
                        ),
                      ),
                      
                      // Legend with reduced vertical padding
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem('Workout Day', Colors.blue),
                            const SizedBox(width: 16),
                            _buildLegendItem('Rest Day', Colors.green.shade300),
                            const SizedBox(width: 16),
                            _buildLegendItem('No Activity', Colors.grey.shade200),
                          ],
                        ),
                      ),
                      
                      // Selected day details
                      if (_selectedDay != null) 
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, 
                            vertical: 8.0
                          ),
                          child: _buildSelectedDayInfo(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildStreakHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                'Current Streak',
                '${_streak?.currentStreak ?? 0}',
                Icons.local_fire_department,
                Colors.orange,
              ),
              _buildStatCard(
                'Longest Streak',
                '${_streak?.longestStreak ?? 0}',
                Icons.emoji_events,
                Colors.amber,
              ),
              _buildStatCard(
                'This Month',
                _calculateMonthlyActivity(),
                Icons.calendar_today,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Days with a star indicate milestone streaks (7 and 30 days)',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildSelectedDayInfo() {
    // Normalize the selected date to remove time
    final normalizedDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    
    // Get activities for this date
    final activities = _events[normalizedDate] ?? [];
    
    // Determine activity type
    String activityType = 'No Activity';
    if (activities.isNotEmpty) {
      for (var activity in activities) {
        if (activity.activityType == 'workout') {
          activityType = 'Workout';
          break;
        } else if (activity.activityType == 'rest') {
          activityType = 'Rest Day';
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Activity: '),
                    Text(
                      activityType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: activityType == 'Workout'
                            ? Colors.blue
                            : activityType == 'Rest Day'
                                ? Colors.green
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isStreakMilestone(_selectedDay!))
            const Icon(Icons.star, color: Colors.orange, size: 18),
        ],
      ),
    );
  }
  
  String _calculateMonthlyActivity() {
    // Calculate activity for the current month
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    int activeCount = 0;
    final countedDates = <String>{};
    
    for (var log in _dailyLogs) {
      if (log.date.isAfter(firstDayOfMonth.subtract(const Duration(days: 1)))) {
        // Format date as string for comparison
        final dateStr = DateFormat('yyyy-MM-dd').format(log.date);
        
        // Count each date only once
        if (!countedDates.contains(dateStr)) {
          activeCount++;
          countedDates.add(dateStr);
        }
      }
    }
    
    // Calculate days in the month
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsedDays = min(now.day, daysInMonth);
    
    return '$activeCount/$elapsedDays';
  }

  

  
}

// Helper function to get minimum of two integers
int min(int a, int b) {
  return a < b ? a : b;
}