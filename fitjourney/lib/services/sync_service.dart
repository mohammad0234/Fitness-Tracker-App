import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart';
// import 'package:fitjourney/database_models/workout.dart';
// import 'package:fitjourney/database_models/goal.dart';
// import 'package:fitjourney/database_models/streak.dart';
// import 'package:fitjourney/database_models/user_metrics.dart';
import 'package:sqflite/sqflite.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  
  factory SyncService() {
    return _instance;
  }
  
  SyncService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  StreamSubscription? _connectivitySubscription;
  Timer? _syncTimer;
  
  // Initialize sync service and set up listeners
  Future<void> initialize() async {
    // Set up connectivity listener
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncAll();
      }
    });
    
    // Set up periodic sync (every 15 minutes)
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        syncAll();
      }
    });
    
    // Initial sync attempt
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      syncAll();
    }
  }
  
  // Clean up resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }
  
  // Add an item to the sync queue
  Future<void> queueForSync(String tableName, String recordId, String operation) async {
    final db = await _dbHelper.database;
    
    await db.insert(
      'sync_queue',
      {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Sync all data
  Future<void> syncAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Process sync queue (upload changes to Firestore)
      await _processOutgoingSync(user.uid);
      
      // Download any changes from Firestore
      await _processIncomingSync(user.uid);
    } catch (e) {
      print('Sync error: $e');
    }
  }
  
  // Process local changes and upload to Firestore
  Future<void> _processOutgoingSync(String userId) async {
    final db = await _dbHelper.database;
    
    // Get all items in the sync queue
    final List<Map<String, dynamic>> queueItems = await db.query(
      'sync_queue',
      where: 'synced = ?',
      whereArgs: [0],
    );
    
    for (var item in queueItems) {
      final String tableName = item['table_name'];
      final String recordId = item['record_id'];
      final String operation = item['operation'];
      
      try {
        if (operation == 'INSERT' || operation == 'UPDATE') {
          // Get the actual data to sync
          dynamic dataToSync;
          
          switch (tableName) {
            case 'users':
              final user = await _dbHelper.getUserById(recordId);
              if (user != null) {
                dataToSync = user.toMap();
              }
              break;
            case 'workout':
              // Implement workout retrieval
              // dataToSync = await _dbHelper.getWorkoutById(int.parse(recordId));
              break;
            case 'goal':
              // Implement goal retrieval
              // dataToSync = await _dbHelper.getGoalById(int.parse(recordId));
              break;
            // Add cases for other tables
          }
          
          if (dataToSync != null) {
            // Upload to Firestore
            await _firestore
                .collection('users')
                .doc(userId)
                .collection(tableName)
                .doc(recordId)
                .set(dataToSync, SetOptions(merge: true));
          }
        } else if (operation == 'DELETE') {
          // Delete from Firestore
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(tableName)
              .doc(recordId)
              .delete();
        }
        
        // Mark as synced
        await db.update(
          'sync_queue',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      } catch (e) {
        print('Error syncing item ${item['id']}: $e');
      }
    }
  }
  
  // Download changes from Firestore
  Future<void> _processIncomingSync(String userId) async {
    // Sync user profile
    await _syncUserProfile(userId);
    
    // Sync workouts
    await _syncWorkouts(userId);
    
    // Sync goals
    await _syncGoals(userId);
    
    // Sync metrics
    await _syncMetrics(userId);
    
    // Sync streak
    await _syncStreak(userId);
  }
  
  // Sync user profile from Firestore to SQLite
  Future<void> _syncUserProfile(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc(userId)
          .get();
      
      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        if (userData != null) {
          final appUser = AppUser(
            userId: userId,
            firstName: userData['first_name'],
            lastName: userData['last_name'],
            heightCm: userData['height_cm'],
            registrationDate: userData['registration_date'] != null 
                ? DateTime.parse(userData['registration_date']) 
                : null,
            lastLogin: userData['last_login'] != null 
                ? DateTime.parse(userData['last_login']) 
                : null,
          );
          
          await _dbHelper.insertUser(appUser);
        }
      }
    } catch (e) {
      print('Error syncing user profile: $e');
    }
  }
  
  // Sync workouts from Firestore to SQLite
  Future<void> _syncWorkouts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workout')
          .get();
      
      // Implement workout syncing logic here
      // Loop through querySnapshot.docs
      // For each document, create a Workout object and insert/update in SQLite
    } catch (e) {
      print('Error syncing workouts: $e');
    }
  }
  
  // Sync goals from Firestore to SQLite
  Future<void> _syncGoals(String userId) async {
    // Similar to _syncWorkouts
  }
  
  // Sync metrics from Firestore to SQLite
  Future<void> _syncMetrics(String userId) async {
    // Similar to _syncWorkouts
  }
  
  // Sync streak from Firestore to SQLite
  Future<void> _syncStreak(String userId) async {
    // Similar to _syncWorkouts
  }
}