import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:flutter/foundation.dart';

class AccountService {
  static final AccountService instance = AccountService._internal();

  factory AccountService() {
    return instance;
  }

  AccountService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Deletes a user account and all associated data (both locally and in the cloud)
  /// Returns a success message on completion or throws an error if something fails
  Future<String> deleteAccount() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently logged in');
      }

      final String userId = currentUser.uid;

      // 1. Delete Firestore data
      await _deleteFirestoreData(userId);

      // 2. Delete local data
      await _deleteLocalData(userId);

      // 3. Delete Firebase Authentication account
      await currentUser.delete();

      return 'Account successfully deleted';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign in again before deleting your account');
      } else {
        throw Exception('Authentication error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error deleting account: $e');
    }
  }

  /// Delete all user data from Firestore
  Future<void> _deleteFirestoreData(String userId) async {
    try {
      // Delete user collections
      await _deleteCollection('users/$userId/workout');
      await _deleteCollection('users/$userId/goal');
      await _deleteCollection('users/$userId/user_metrics');
      await _deleteCollection('users/$userId/daily_log');
      await _deleteCollection('users/$userId/streak');
      await _deleteCollection('users/$userId/profile');

      // Delete user document
      await _firestore.collection('users').doc(userId).delete();

      debugPrint('Firestore data deletion complete');
    } catch (e) {
      debugPrint('Error deleting Firestore data: $e');
      throw Exception('Failed to delete cloud data: $e');
    }
  }

  /// Delete all user data from local database
  Future<void> _deleteLocalData(String userId) async {
    try {
      final db = await _dbHelper.database;

      // Delete user data from all tables
      await db.transaction((txn) async {
        // Delete user's workouts and related data
        final workouts = await txn.query(
          'workout',
          columns: ['workout_id'],
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        for (final workout in workouts) {
          final workoutId = workout['workout_id'] as int;

          // Get workout_exercise entries to delete sets
          final exercises = await txn.query(
            'workout_exercise',
            columns: ['workout_exercise_id'],
            where: 'workout_id = ?',
            whereArgs: [workoutId],
          );

          for (final exercise in exercises) {
            final exerciseId = exercise['workout_exercise_id'] as int;

            // Delete sets
            await txn.delete(
              'workout_set',
              where: 'workout_exercise_id = ?',
              whereArgs: [exerciseId],
            );
          }

          // Delete workout exercises
          await txn.delete(
            'workout_exercise',
            where: 'workout_id = ?',
            whereArgs: [workoutId],
          );
        }

        // Delete workouts
        await txn.delete(
          'workout',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        // Delete goals
        await txn.delete(
          'goal',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        // Delete metrics
        await txn.delete(
          'user_metrics',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        // Delete streak
        await txn.delete(
          'streak',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        // Delete daily logs
        await txn.delete(
          'daily_log',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        // Delete user profile
        await txn.delete(
          'users',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        // Clear sync queue items for this user
        await txn.delete(
          'sync_queue',
          where: "table_name = 'users' AND record_id = ?",
          whereArgs: [userId],
        );
      });

      debugPrint('Local data deletion complete');
    } catch (e) {
      debugPrint('Error deleting local data: $e');
      throw Exception('Failed to delete local data: $e');
    }
  }

  /// Helper method to delete a Firestore collection
  Future<void> _deleteCollection(String collectionPath) async {
    final collection = _firestore.collection(collectionPath);
    final batch = _firestore.batch();
    int batchCount = 0;

    // Get documents in batches to avoid memory issues
    final snapshot = await collection.limit(100).get();

    // If collection is empty, return
    if (snapshot.docs.isEmpty) return;

    // Add delete operations to batch
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      batchCount++;

      // Commit batch every 100 operations to avoid hitting limits
      if (batchCount >= 100) {
        await batch.commit();
        return _deleteCollection(
            collectionPath); // Recursive call to continue deletion
      }
    }

    // Commit any remaining operations
    if (batchCount > 0) {
      await batch.commit();
    }

    // Check if we need to continue deleting
    if (snapshot.docs.length >= 100) {
      return _deleteCollection(collectionPath);
    }
  }
}
