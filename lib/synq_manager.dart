/// SynqManager - A powerful synchronization manager for Flutter apps
///
/// This library provides secure local storage with real-time state management,
/// background cloud synchronization, and conflict resolution capabilities.
library synq_manager;

export 'package:hive_plus_secure/hive_plus_secure.dart'
    show DocumentSerializable;

export 'src/core/synq_manager.dart';
export 'src/events/event_types.dart';
export 'src/models/conflict_resolution.dart';
export 'src/models/sync_config.dart';
export 'src/models/sync_data.dart';
export 'src/models/sync_event.dart';
export 'src/services/storage_service.dart';
export 'src/services/sync_service.dart';
