import 'package:fitjourney/database/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitjourney/database_models/notification.dart';

/// Service for managing in-app notifications including creation, retrieval and management
class InAppNotificationService {
  // Singleton instance
  static final InAppNotificationService instance =
      InAppNotificationService._internal();

  // Private constructor
  InAppNotificationService._internal();

  /// Creates a new in-app notification for the current user
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
}
