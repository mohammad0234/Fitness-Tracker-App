import 'package:flutter/material.dart';
import 'package:fitjourney/services/sync_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitjourney/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class SyncManagementScreen extends StatefulWidget {
  const SyncManagementScreen({Key? key}) : super(key: key);

  @override
  State<SyncManagementScreen> createState() => _SyncManagementScreenState();
}

class _SyncManagementScreenState extends State<SyncManagementScreen> {
  bool _isLoadingStats = true;
  Map<String, int> _localStats = {};
  Map<String, int> _cloudStats = {};
  int _queueCount = 0;
  bool _isSyncing = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      await _loadLocalStats();
      await _loadCloudStats();
      await _loadQueueCount();
    } catch (e) {
      print('Error loading sync stats: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadLocalStats() async {
    final db = await DatabaseHelper.instance.database;

    // Count local items
    final stats = <String, int>{};

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Workouts
    final workoutCount = Sqflite.firstIntValue(await db
        .rawQuery('SELECT COUNT(*) FROM workout WHERE user_id = ?', [userId]));
    stats['Workouts'] = workoutCount ?? 0;

    // Goals
    final goalCount = Sqflite.firstIntValue(await db
        .rawQuery('SELECT COUNT(*) FROM goal WHERE user_id = ?', [userId]));
    stats['Goals'] = goalCount ?? 0;

    // Metrics
    final metricCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM user_metrics WHERE user_id = ?', [userId]));
    stats['Metrics'] = metricCount ?? 0;

    // Daily logs
    final logCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM daily_log WHERE user_id = ?', [userId]));
    stats['Activity Logs'] = logCount ?? 0;

    setState(() {
      _localStats = stats;
    });
  }

  Future<void> _loadCloudStats() async {
    final stats = <String, int>{};

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final firestore = FirebaseFirestore.instance;

    // Workouts
    final workoutCount = (await firestore
            .collection('users')
            .doc(userId)
            .collection('workout')
            .count()
            .get())
        .count;
    stats['Workouts'] = workoutCount ?? 0;

    // Goals
    final goalCount = (await firestore
            .collection('users')
            .doc(userId)
            .collection('goal')
            .count()
            .get())
        .count;
    stats['Goals'] = goalCount ?? 0;

    // Metrics
    final metricCount = (await firestore
            .collection('users')
            .doc(userId)
            .collection('user_metrics')
            .count()
            .get())
        .count;
    stats['Metrics'] = metricCount ?? 0;

    // Daily logs
    final logCount = (await firestore
            .collection('users')
            .doc(userId)
            .collection('daily_log')
            .count()
            .get())
        .count;
    stats['Activity Logs'] = logCount ?? 0;

    setState(() {
      _cloudStats = stats;
    });
  }

  Future<void> _loadQueueCount() async {
    final db = await DatabaseHelper.instance.database;

    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE synced = 0'));

    setState(() {
      _queueCount = count ?? 0;
    });
  }

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await SyncService.instance.triggerManualSync();

      // Add a small delay to ensure the sync queue is updated
      await Future.delayed(const Duration(milliseconds: 500));

      // Reload all stats to reflect the new state
      await _loadStats();

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed successfully')),
      );
    } catch (e) {
      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _resetCloudData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset Cloud Data'),
            content: const Text(
                'This will delete all your cloud data and re-upload your local data. '
                'This operation cannot be undone. Are you sure you want to proceed?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('RESET', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _isResetting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');

      final firestore = FirebaseFirestore.instance;

      // Delete all collections
      await _deleteCollection(firestore, 'users/$userId/workout');
      await _deleteCollection(firestore, 'users/$userId/goal');
      await _deleteCollection(firestore, 'users/$userId/user_metrics');
      await _deleteCollection(firestore, 'users/$userId/daily_log');
      await _deleteCollection(firestore, 'users/$userId/streak');

      // Clear sync queue
      final db = await DatabaseHelper.instance.database;
      await db.delete('sync_queue');

      // Mark all data for re-sync
      await _markAllForSync();

      // Trigger sync
      await SyncService.instance.triggerManualSync();

      // Reload stats
      await _loadStats();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud data reset complete')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset error: $e')),
      );
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }

  Future<void> _deleteCollection(
      FirebaseFirestore firestore, String path) async {
    final collection = firestore.collection(path);
    final docs = await collection.limit(100).get();

    for (final doc in docs.docs) {
      await doc.reference.delete();
    }

    if (docs.docs.length >= 100) {
      await _deleteCollection(firestore, path);
    }
  }

  Future<void> _markAllForSync() async {
    final db = await DatabaseHelper.instance.database;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Mark all workouts for sync
    final workouts = await db.query(
      'workout',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    for (final workout in workouts) {
      final workoutId = workout['workout_id'] as int;
      await SyncService.instance
          .queueForSync('workout', workoutId.toString(), 'INSERT');
    }

    // Mark all goals for sync
    final goals = await db.query(
      'goal',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    for (final goal in goals) {
      final goalId = goal['goal_id'] as int;
      await SyncService.instance
          .queueForSync('goal', goalId.toString(), 'INSERT');
    }

    // Mark all metrics for sync
    final metrics = await db.query(
      'user_metrics',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    for (final metric in metrics) {
      final metricId = metric['metric_id'] as int;
      await SyncService.instance
          .queueForSync('user_metrics', metricId.toString(), 'INSERT');
    }

    // Mark all daily logs for sync
    final logs = await db.query(
      'daily_log',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    for (final log in logs) {
      final logId = log['daily_log_id'] as int;
      await SyncService.instance
          .queueForSync('daily_log', logId.toString(), 'INSERT');
    }

    // Mark streak for sync - explicitly add streak to ensure it's synced
    await SyncService.instance.forceAddStreakToSyncQueue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Synchronization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingStats ? null : _loadStats,
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: _isLoadingStats
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sync status card
                  _buildSyncStatusCard(),

                  const SizedBox(height: 16),

                  // Data statistics
                  _buildDataStatsCard(),

                  const SizedBox(height: 16),

                  // Queue information
                  _buildQueueInfoCard(),

                  const SizedBox(height: 24),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildSyncStatusCard() {
    return StreamBuilder<SyncStatus>(
      stream: SyncService.instance.syncStatusStream,
      builder: (context, snapshot) {
        final syncStatus = snapshot.data;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Sync Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (syncStatus?.isInProgress == true)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const Divider(),
                if (syncStatus != null) ...[
                  _buildStatusRow(
                    'Status',
                    syncStatus.isInProgress
                        ? 'Syncing...'
                        : (syncStatus.lastError != null
                            ? 'Error'
                            : (syncStatus.lastSuccess != null
                                ? 'Synced'
                                : 'Not synced')),
                    syncStatus.isInProgress
                        ? Colors.blue
                        : (syncStatus.lastError != null
                            ? Colors.red
                            : (syncStatus.lastSuccess != null
                                ? Colors.green
                                : Colors.grey)),
                  ),
                  if (syncStatus.lastAttempt != null)
                    _buildStatusRow(
                      'Last attempt',
                      _formatDateTime(syncStatus.lastAttempt!),
                    ),
                  if (syncStatus.lastSuccess != null)
                    _buildStatusRow(
                      'Last successful sync',
                      _formatDateTime(syncStatus.lastSuccess!),
                      Colors.green,
                    ),
                  if (syncStatus.lastError != null)
                    _buildStatusRow(
                      'Error',
                      syncStatus.lastError!,
                      Colors.red,
                    ),
                ] else
                  const Text('Sync service not initialized'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, size: 20),
                SizedBox(width: 8),
                Text(
                  'Data Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // Headers
            Row(
              children: [
                const SizedBox(width: 120),
                Expanded(
                  child: Text(
                    'Local',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cloud',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Data rows
            ..._localStats.keys.map((key) => _buildDataRow(
                  key,
                  _localStats[key] ?? 0,
                  _cloudStats[key] ?? 0,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pending_actions, size: 20),
                SizedBox(width: 8),
                Text(
                  'Sync Queue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildStatusRow(
              'Items in queue',
              _queueCount.toString(),
              _queueCount > 0 ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              _queueCount > 0
                  ? 'There are $_queueCount items waiting to be synced to the cloud.'
                  : 'All items have been synced to the cloud.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.sync),
          label: const Text('Sync Now'),
          onPressed: _isSyncing ? null : _triggerSync,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.warning, color: Colors.red),
          label: const Text(
            'Reset Cloud Data',
            style: TextStyle(color: Colors.red),
          ),
          onPressed: _isResetting ? null : _resetCloudData,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.w500 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, int localCount, int cloudCount) {
    final isInSync = localCount == cloudCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              localCount.toString(),
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cloudCount.toString(),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                if (isInSync)
                  Icon(Icons.check_circle,
                      size: 16, color: Colors.green.shade700)
                else
                  Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
  }
}
