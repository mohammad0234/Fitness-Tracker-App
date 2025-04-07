import 'package:flutter/material.dart';
import 'package:fitjourney/database_models/notification.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:fitjourney/screens/goal_detail_screen.dart';
import 'package:fitjourney/screens/calendar_streak_screen.dart';
import 'package:fitjourney/screens/progress_page.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _filterType = 'All';
  final List<String> _filterOptions = ['All', 'Goal', 'Streak', 'Milestone'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Load notifications from database
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'notification',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC',
      );
      
      final notifications = result.map((map) => NotificationModel.fromMap(map)).toList();
      
      setState(() {
        _notifications.clear();
        _notifications.addAll(notifications);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final db = await DatabaseHelper.instance.database;
      await db.update(
        'notification',
        {'is_read': 1},
        where: 'user_id = ? AND is_read = 0',
        whereArgs: [userId],
      );
      
      await _loadNotifications();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  List<NotificationModel> _getFilteredNotifications() {
    if (_filterType == 'All') {
      return _notifications;
    }

    return _notifications.where((notification) {
      switch (_filterType) {
        case 'Goal':
          return notification.type == 'GoalProgress';
        case 'Streak':
          return notification.type == 'NewStreak';
        case 'Milestone':
          return notification.type == 'Milestone';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((notification) => !notification.isRead))
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter options
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filterOptions.length,
                itemBuilder: (context, index) {
                  final filter = _filterOptions[index];
                  final isSelected = filter == _filterType;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _filterType = filter;
                          });
                        }
                      },
                      backgroundColor: Colors.grey.shade100,
                      selectedColor: Colors.blue.shade100,
                    ),
                  );
                },
              ),
            ),
          ),

          // Notifications list
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredNotifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      itemCount: filteredNotifications.length,
                      itemBuilder: (context, index) {
                        return NotificationCard(
                          notification: filteredNotifications[index],
                          onTap: () => _handleNotificationTap(filteredNotifications[index]),
                          onDismiss: () => _dismissNotification(filteredNotifications[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) async {
    // Mark the notification as read
    if (!notification.isRead) {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'notification',
        {'is_read': 1},
        where: 'notification_id = ?',
        whereArgs: [notification.notificationId],
      );
    }

    if (!mounted) return;

    // Handle navigation based on notification type and payload
    final payload = notification.message;

    if (notification.type == 'GoalProgress') {
      _navigateToGoalDetails(payload);
    } else if (notification.type == 'NewStreak') {
      _navigateToCalendarStreak();
    } else if (notification.type == 'Milestone') {
      _navigateToProgressPage();
    }

    // Refresh the notifications list
    _loadNotifications();
  }

  void _navigateToGoalDetails(String message) {
    // Extract goal ID from message if possible
    final goalIdRegExp = RegExp(r'goal_(\d+)');
    final match = goalIdRegExp.firstMatch(message);
    
    if (match != null) {
      final goalId = int.parse(match.group(1)!);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GoalDetailScreen(goalId: goalId),
        ),
      );
    }
  }

  void _navigateToCalendarStreak() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CalendarStreakScreen(),
      ),
    );
  }

  void _navigateToProgressPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProgressPage(),
      ),
    );
  }

  Future<void> _dismissNotification(NotificationModel notification) async {
    try {
      if (notification.notificationId == null) return;
      
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'notification',
        where: 'notification_id = ?',
        whereArgs: [notification.notificationId],
      );
      
      // Refresh notifications
      await _loadNotifications();
    } catch (e) {
      print('Error dismissing notification: $e');
    }
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('notification_${notification.notificationId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => onDismiss(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: notification.isRead ? Colors.transparent : Colors.blue.shade200,
            width: 2.0,
          ),
        ),
        elevation: notification.isRead ? 0 : 2,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Notification content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getNotificationTitle(notification.type),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (!notification.isRead)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'GoalProgress':
        return Icons.flag_outlined;
      case 'NewStreak':
        return Icons.local_fire_department;
      case 'Milestone':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'GoalProgress':
        return Colors.green;
      case 'NewStreak':
        return Colors.orange;
      case 'Milestone':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _getNotificationTitle(String type) {
    switch (type) {
      case 'GoalProgress':
        return 'Goal Update';
      case 'NewStreak':
        return 'Streak News';
      case 'Milestone':
        return 'Achievement Unlocked';
      default:
        return 'Notification';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}