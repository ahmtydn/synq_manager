import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

/// Global callback for sync operations
Future<void> Function()? _globalOnSyncRequested;

/// Background sync task manager using WorkManager
class SyncBackgroundTask {
  static const String _syncTaskName = 'synq_manager_periodic_sync';
  static const String _syncTaskTag = 'sync_periodic';

  /// Initialize the background task system
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  /// Register periodic sync task
  static Future<void> registerPeriodicSync(
    Duration frequency, {
    required Future<void> Function() onSyncRequested,
  }) async {
    _globalOnSyncRequested = onSyncRequested;

    await Workmanager().registerPeriodicTask(
      _syncTaskName,
      _syncTaskName,
      frequency: frequency,
      tag: _syncTaskTag,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  /// Cancel periodic sync
  static Future<void> cancelPeriodicSync() async {
    await Workmanager().cancelByTag(_syncTaskTag);
  }

  /// Cancel all sync tasks
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }

  /// Check if background tasks are enabled
  static bool get isBackgroundTaskSupported => !kIsWeb;
}

/// Background task callback dispatcher
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (_globalOnSyncRequested != null) {
        await _globalOnSyncRequested!();
      }
      return Future.value(true);
    } catch (e) {
      debugPrint('Background sync failed: $e');
      return Future.value(false);
    }
  });
}
