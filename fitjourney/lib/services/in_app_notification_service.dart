import 'package:fitjourney/database/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitjourney/database_models/notification.dart';

class InAppNotificationService {
  // Singleton instance
  static final InAppNotificationService instance = InAppNotificationService._internal();
  
  // Private constructor
  InAppNotificationService._internal();
  
  // Create an in-app notification
  Future<int?> createNotification({
    required String type,
    required String message,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final db = await DatabaseHelper.instance.database;
      
      // Create notification model
      final notification = NotificationModel(
        userId: userId,
        type: type,
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
      );
      
      // Insert into database
      return await db.insert('notification', notification.toMap());
    } catch (e) {
      print('Error creating in-app notification: $e');
      return null;
    }
  }
  
  // Get all notifications for current user
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'notification',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC',
      );
      
      return result.map((map) => NotificationModel.fromMap(map)).toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }
  
  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return 0;
      
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notification WHERE user_id = ? AND is_read = 0',
        [userId],
      );
      
      return result.isNotEmpty ? result.first['count'] as int : 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
  
  // Mark a notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'notification',
        {'is_read': 1},
        where: 'notification_id = ?',
        whereArgs: [notificationId],
      );
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
  
  // Mark all notifications as read
  Future<void> markAllAsRead() async {
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
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
  
  // Delete a notification
  Future<void> deleteNotification(int notificationId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'notification',
        where: 'notification_id = ?',
        whereArgs: [notificationId],
      );
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }
  
  // Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'notification',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }
}