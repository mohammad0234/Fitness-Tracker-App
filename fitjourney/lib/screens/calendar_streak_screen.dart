// lib/screens/calendar_streak_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/services/streak_service.dart';
import 'package:fitjourney/database_models/daily_log.dart';
import 'package:fitjourney/database_models/streak.dart';

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
      
      setState(() {
        _dailyLogs = logs;
        _events = events;
        _streak = streak;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading calendar data: $e');
      setState(() {
        _isLoading = false;
      });
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
          : Column(
              children: [
                // Calendar header with streak info
                _buildStreakHeader(),
                
                // Calendar view
                TableCalendar(
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.now(),
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
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  eventLoader: (day) {
                    // Normalize the date to remove time
                    final normalized = DateTime(day.year, day.month, day.day);
                    return _events[normalized] ?? [];
                  },
                  calendarStyle: CalendarStyle(
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
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;
                      
                      final isMilestone = _isStreakMilestone(date);
                      
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getEventColor(events as List<DailyLog>?),
                            shape: BoxShape.circle,
                            border: isMilestone
                                ? Border.all(color: Colors.orange, width: 2)
                                : null,
                          ),
                          child: isMilestone
                              ? const Icon(
                                  Icons.star,
                                  color: Colors.orange,
                                  size: 16,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                
                // Legend
                _buildLegend(),
                
                // Selected day details
                if (_selectedDay != null) _buildSelectedDayInfo(),
              ],
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
  
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem('Workout Day', Colors.blue),
          _buildLegendItem('Rest Day', Colors.green.shade300),
          _buildLegendItem('No Activity', Colors.grey.shade200),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
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
          if (_isStreakMilestone(_selectedDay!)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'Streak Milestone!',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  String _calculateMonthlyActivity() {
    // Calculate activity for the current month
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    int activeCount = 0;
    for (var log in _dailyLogs) {
      if (log.date.isAfter(firstDayOfMonth) || 
          (log.date.year == firstDayOfMonth.year && 
           log.date.month == firstDayOfMonth.month && 
           log.date.day == firstDayOfMonth.day)) {
        activeCount++;
        
        // Count only one activity per day
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        for (var i = 0; i < _dailyLogs.length; i++) {
          if (i != _dailyLogs.indexOf(log)) {
            final otherLogDate = DateTime(
              _dailyLogs[i].date.year,
              _dailyLogs[i].date.month,
              _dailyLogs[i].date.day,
            );
            if (logDate == otherLogDate) {
              activeCount--;
              break;
            }
          }
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