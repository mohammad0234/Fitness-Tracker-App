import 'package:flutter/material.dart';
import 'package:fitjourney/services/sync_service.dart';
import 'package:intl/intl.dart';

class SyncStatusWidget extends StatefulWidget {
  final bool showDetailedStatus;

  const SyncStatusWidget({
    Key? key,
    this.showDetailedStatus = false,
  }) : super(key: key);

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncService.instance.syncStatusStream,
      builder: (context, snapshot) {
        final syncStatus = snapshot.data;

        // Simple status indicator for non-detailed view
        if (!widget.showDetailedStatus) {
          return _buildSimpleStatus(syncStatus);
        }

        // Detailed status panel
        return _buildDetailedStatus(syncStatus);
      },
    );
  }

  Widget _buildSimpleStatus(SyncStatus? syncStatus) {
    if (syncStatus == null) {
      return const SizedBox.shrink();
    }

    if (syncStatus.isInProgress) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    // Show success or error indicator
    final hasError = syncStatus.lastError != null;
    final lastSyncSuccessful = syncStatus.lastSuccess != null;

    return Icon(
      hasError
          ? Icons.cloud_off
          : (lastSyncSuccessful ? Icons.cloud_done : Icons.cloud_queue),
      color: hasError
          ? Colors.red
          : (lastSyncSuccessful ? Colors.green : Colors.grey),
      size: 16,
    );
  }

  Widget _buildDetailedStatus(SyncStatus? syncStatus) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Sync Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (syncStatus?.isInProgress == true)
                  const SizedBox(
                    width: 16,
                    height: 16,
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: syncStatus.isInProgress
                      ? null
                      : () => SyncService.instance.triggerManualSync(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync, size: 16),
                      SizedBox(width: 8),
                      Text('Sync Now'),
                    ],
                  ),
                ),
              ),
            ] else
              const Text('Sync service not initialized'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, [Color? valueColor]) {
    // Limit the length of error messages to prevent overflow
    String displayValue = value;
    if (label == 'Error' && value.length > 50) {
      displayValue = '${value.substring(0, 47)}...';
    }

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
          Flexible(
            child: Text(
              displayValue,
              style: TextStyle(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w500 : null,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
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
