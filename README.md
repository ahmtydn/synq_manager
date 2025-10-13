# 🔄 SynqManager

[![pub package](https://img.shields.io/pub/v/synq_manager.svg)](https://pub.dev/packages/synq_manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/ahmtydn/synq_manager.svg?style=social&label=Star)](https://github.com/ahmtydn/synq_manager)

A powerful **offline-first data synchronization engine** for Flutter and Dart applications. Build production-ready apps with **intelligent conflict resolution**, **real-time sync**, **multi-user support**, and **enterprise-grade reliability** - all with a simple, intuitive API.

---

## 📚 Table of Contents
ud
- [✨ Features](#-features)
- [🚀 Quick Start](#-quick-start)
- [📖 Core Concepts](#-core-concepts)
- [🔧 Configuration](#-configuration)
- [🗄️ Adapters](#️-adapters)
- [⚔️ Conflict Resolution](#️-conflict-resolution)
- [📊 Event Streams](#-event-streams)
- [🎯 Advanced Features](#-advanced-features)
- [🧪 Testing](#-testing)
- [📝 Best Practices](#-best-practices)
- [🛠️ Development](#️-development)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## ✨ Features

### 🔄 **Offline-First Architecture**
- **Seamless Offline Operation** - Full CRUD functionality without network
- **Automatic Queue Management** - Operations queued and synced when online
- **Smart Retry Logic** - Configurable retry strategies with exponential backoff
- **Per-Operation Resiliency** - Transient errors on one item don't block the entire sync queue.

### ⚡ **Intelligent Conflict Resolution**
- **Multiple Built-in Strategies** - Last-write-wins, local/remote priority, merge
- **Custom Resolvers** - Implement your own conflict resolution logic
- **Field-Level Merging** - Granular control over conflict handling

### 📊 **Real-Time Synchronization**
- **Reactive Event Streams** - Listen to data changes, sync progress, conflicts
- **Automatic Sync** - Background synchronization with configurable intervals
- **Reactive Queries** - Watch live-updating lists, paginated data, or filtered subsets.
- **Manual Sync Control** - Trigger sync on-demand or pause when needed

### 👥 **Multi-User Support**
- **User Switching** - Seamless switching between user accounts
- **Configurable Strategies** - Clear-and-fetch, sync-then-switch, keep-local
- **Per-User Data Isolation** - Complete data separation by user

### 🎯 **Partial Synchronization**
- **Sync Scopes** - Fetch only a subset of data from the remote source (e.g., by date range).
- **Efficient Data Transfer** - Reduce network usage and sync time for large datasets.

### 🔌 **Pluggable Architecture**
- **Adapter System** - Support for Hive, SQLite, Firestore, or custom backends
- **Middleware Pipeline** - Transform, validate, and log at every stage
- **Extensible Design** - Easy to extend and customize

### 📈 **Enterprise Features**
- **Metrics & Analytics** - Track sync performance and system health
- **Comprehensive Logging** - Debug-friendly logging with configurable levels
- **Health Checks** - Monitor system status and connectivity
- **Batch Operations** - Efficient bulk sync with configurable batch sizes

---

## 🚀 Quick Start

### 1️⃣ Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  synq_manager: ^0.1.0
```

Run:

```bash
flutter pub get
```

### 2️⃣ Define Your Entity

```dart
import 'package:synq_manager/synq_manager.dart';

class Task implements SyncableEntity {
  @override
  final String id;

  @override
  final String userId;

  final String title;
  final bool completed;

  @override
  final DateTime modifiedAt;

  @override
  final DateTime createdAt;

  @override
  final String version;

  @override
  final bool isDeleted;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.completed = false,
    required this.modifiedAt,
    required this.createdAt,
    required this.version,
    this.isDeleted = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'completed': completed,
    'modifiedAt': modifiedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'version': version,
    'isDeleted': isDeleted,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    userId: json['userId'],
    title: json['title'],
    completed: json['completed'] ?? false,
    modifiedAt: DateTime.parse(json['modifiedAt']),
    createdAt: DateTime.parse(json['createdAt']),
    version: json['version'],
    isDeleted: json['isDeleted'] ?? false,
  );

  @override
  Task copyWith({
    String? userId,
    DateTime? modifiedAt,
    String? version,
    bool? isDeleted,
    String? title,
    bool? completed,
  }) =>
      Task(
        id: id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        createdAt: createdAt,
        version: version ?? this.version,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
```

### 3️⃣ Initialize SynqManager

```dart
// Create adapters
final localAdapter = HiveAdapter<Task>(
  boxName: 'tasks',
  fromJson: Task.fromJson,
);

final remoteAdapter = FirebaseAdapter<Task>(
  collection: 'tasks',
  fromJson: Task.fromJson,
);

// Initialize manager
final manager = SynqManager<Task>(
  localAdapter: localAdapter,
  remoteAdapter: remoteAdapter,
  synqConfig: SynqConfig(
    autoSyncInterval: Duration(minutes: 5),
    enableLogging: true,
    maxRetries: 3,
    defaultConflictResolver: LastWriteWinsResolver<Task>(),
  ),
);

await manager.initialize();
```

### 4️⃣ CRUD Operations

```dart
// 📝 Create
final task = Task(
  id: Uuid().v4(),
  userId: 'user123',
  title: 'Buy groceries',
  modifiedAt: DateTime.now(),
  createdAt: DateTime.now(),
  version: 'v1',
);
await manager.save(task, 'user123');

// 📖 Read (one-time fetch)
final allTasks = await manager.getAll(userId: 'user123');
final specificTask = await manager.getById('task-id', 'user123');

// 🎧 Read (reactive queries)
// Use watchAll to get a stream of all items that updates automatically.
// Perfect for powering a list view in Flutter.
manager.watchAll(userId: 'user123').listen((tasks) {
  // Update your UI with the new list of tasks
  print('Task list updated, new count: ${tasks.length}');
});

// Use watchById for a single item.
manager.watchById('task-id', 'user123').listen((task) {
  // task is null if it has been deleted.
  print('Task details updated: ${task?.title}');
});

// Use watchQuery for filtered reactive lists.
final pendingOnlyQuery = SynqQuery({'completed': false});
manager.watchQuery(pendingOnlyQuery, userId: 'user123').listen((pendingTasks) {
  print('Pending task list updated, count: ${pendingTasks.length}');
});

// ✏️ Update
final updated = task.copyWith(
  completed: true,
  modifiedAt: DateTime.now(),
  version: 'v2',
);
await manager.save(updated, 'user123');

// 🗑️ Delete
// The delete method now returns a boolean indicating if an item was deleted.
final bool wasDeleted = await manager.delete('task-id', 'user123');
if (wasDeleted) print('Task deleted successfully!');

```

### 5️⃣ Synchronization

```dart
// 🔄 Manual sync
final result = await manager.sync('user123');
print('Synced: ${result.syncedCount}, Failed: ${result.failedCount}');

// ⚡ Auto-sync
manager.startAutoSync('user123');

// 🎯 Force full sync
await manager.sync('user123', force: true);

// 🎯 Partial Sync (e.g., only recent items)
final scope = SyncScope({'minModifiedDate': DateTime.now().subtract(const Duration(days: 30))});
await manager.sync('user123', scope: scope);

// ⏸️ Stop auto-sync
manager.stopAutoSync(userId: 'user123');
```

### 6️⃣ Listen to Events

Your UI can reactively update by listening to various streams.

```dart
// 🚀 Get initial data and subscribe to all future changes
manager.onInit.listen((event) {
  print('UI updated with ${event.data.length} items.');
  // This is the primary stream for populating and updating a list view.
});

// 📊 Listen to granular data changes (create, update, delete)
manager.onDataChange.listen((event) {
  print('${event.changeType}: ${event.data.title}');
});

// ⚠️ Conflicts
manager.onConflict.listen((event) {
  print('Conflict: ${event.context.type}');
});

// ❌ Errors
manager.onError.listen((event) {
  print('Error: ${event.error}');
});

// 📈 Sync progress
manager.onSyncProgress.listen((event) {
  print('Progress: ${event.completed}/${event.total}');
});
```

---

## 📖 Core Concepts

### 🎯 SyncableEntity

All entities must implement the `SyncableEntity` interface:

```dart
abstract class SyncableEntity {
  String get id;              // Unique identifier
  String get userId;          // User ownership
  DateTime get modifiedAt;    // Last modification time
  DateTime get createdAt;     // Creation time
  String get version;         // Version for conflict detection
  bool get isDeleted;         // Soft delete flag

  Map<String, dynamic> toJson();
  T copyWith({...});
}
```

### 🔄 Sync Operation Flow

```
1. User Action → Save/Delete
2. Local Storage ← Data Written
3. Queue Manager ← Operation Enqueued
4. Sync Trigger → Periodic/Manual
5. Sync Engine → Process Queue
6. Remote Adapter → Push to Server
7. Conflict Detection → If Needed
8. Resolution → Apply Strategy
9. Events → Notify Listeners
10. Metrics → Update Statistics
```

### 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SynqManager                          │
│  (Public API - CRUD, Sync, User Management)            │
└──────────────────┬──────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
┌───────▼──────┐    ┌────────▼────────┐
│ SyncEngine   │    │ QueueManager    │
│ (Sync Logic) │    │ (Operations)    │
└───────┬──────┘    └────────┬────────┘
        │                    │
        └──────────┬─────────┘
                   │
    ┌──────────────┼──────────────┐
    │              │              │
┌───▼────┐  ┌─────▼──────┐  ┌───▼─────────┐
│ Local  │  │  Remote    │  │  Conflict   │
│Adapter │  │  Adapter   │  │  Detector   │
└────────┘  └────────────┘  └─────────────┘
```

---

## 🔧 Configuration

### 📋 SynqConfig Options

```dart
SynqConfig(
  // ⏱️ Auto-sync settings
  autoSyncInterval: Duration(minutes: 5),
  autoSyncOnConnect: true,

  // 🔄 Retry behavior
  maxRetries: 3,
  retryDelay: Duration(seconds: 5),

  // 📦 Batch settings
  batchSize: 50,

  // ⚔️ Conflict resolution
  defaultConflictResolver: LastWriteWinsResolver<Task>(),

  // 👥 User switching
  defaultUserSwitchStrategy: UserSwitchStrategy.syncThenSwitch,

  // 📡 Real-time sync
  enableRealTimeSync: false,

  // ⏰ Timeouts
  syncTimeout: Duration(minutes: 2),

  // 📝 Logging
  enableLogging: true,
)
```

### 🎯 Configuration Profiles

#### 🔧 Development
```dart
SynqConfig(
  autoSyncInterval: Duration(seconds: 30),
  enableLogging: true,
  maxRetries: 1,
  syncTimeout: Duration(seconds: 30),
)
```

#### 🚀 Production
```dart
SynqConfig(
  autoSyncInterval: Duration(minutes: 5),
  enableLogging: false,
  maxRetries: 3,
  retryDelay: Duration(seconds: 10),
  syncTimeout: Duration(minutes: 2),
  batchSize: 100,
)
```

#### 🧪 Testing
```dart
SynqConfig(
  autoSyncInterval: Duration(hours: 24),  // Disable auto-sync
  enableLogging: true,
  maxRetries: 0,
)
```

---

## 🗄️ Adapters

### 📱 Local Adapters

#### Hive (Recommended)
```dart
final localAdapter = HiveAdapter<Task>(
  boxName: 'tasks',
  fromJson: Task.fromJson,
);
```

#### SQLite
```dart
final localAdapter = SQLiteAdapter<Task>(
  tableName: 'tasks',
  fromJson: Task.fromJson,
);
```

### ☁️ Remote Adapters

#### Firebase/Firestore
```dart
final remoteAdapter = FirebaseAdapter<Task>(
  collection: 'tasks',
  fromJson: Task.fromJson,
);
```

#### REST API
```dart
final remoteAdapter = RestApiAdapter<Task>(
  baseUrl: 'https://api.example.com',
  endpoint: '/tasks',
  fromJson: Task.fromJson,
);
```

#### Supabase
```dart
final remoteAdapter = SupabaseAdapter<Task>(
  tableName: 'tasks',
  fromJson: Task.fromJson,
);
```

### 🛠️ Custom Adapter

```dart
class CustomLocalAdapter<T extends SyncableEntity> implements LocalAdapter<T> {
  @override
  Future<void> initialize() async {
    // Initialize storage
  }

  @override
  Future<List<T>> getAll(String userId) async {
    // Fetch all items
  }

  @override
  Future<T?> getById(String id, String userId) async {
    // Fetch single item
  }

  @override
  Future<void> save(T item, String userId) async {
    // Save item
  }

  @override
  Future<void> delete(String id, String userId) async {
    // Delete item
  }

  @override
  Future<List<SyncOperation<T>>> getPendingOperations(String userId) async {
    // Get pending operations
  }

  @override
  Future<void> addPendingOperation(String userId, SyncOperation<T> operation) async {
    // Add to queue
  }

  @override
  Future<void> markAsSynced(String operationId) async {
    // Remove from queue
  }

  @override
  Future<void> clearUserData(String userId) async {
    // Clear user data
  }

  @override
  Future<SyncMetadata?> getSyncMetadata(String userId) async {
    // Get metadata
  }

  @override
  Future<void> updateSyncMetadata(SyncMetadata metadata, String userId) async {
    // Update metadata
  }

  @override
  Future<void> dispose() async {
    // Cleanup
  }
}

```dart
class CustomRemoteAdapter<T extends SyncableEntity>
    implements RemoteAdapter<T> {
  @override
  Future<List<T>> fetchAll(String userId) async {
    // Fetch all items
  }

  @override
  Future<T?> fetchById(String id, String userId) async {
    // Fetch single item
  }

  @override
  Future<T> push(T item, String userId) async {
    // Create or update remotely
  }

  @override
  Future<void> deleteRemote(String id, String userId) async {
    // Delete remotely
  }

  @override
  Future<SyncMetadata?> getSyncMetadata(String userId) async {
    // Return stored metadata snapshot
  }

  @override
  Future<void> updateSyncMetadata(
    SyncMetadata metadata,
    String userId,
  ) async {
    // Persist metadata for future comparisons
  }

  @override
  Future<bool> isConnected() async {
    // Remote availability
  }
}
```

---

## ⚔️ Conflict Resolution

### 🎯 Built-in Resolvers

#### Last-Write-Wins (Default)
```dart
LastWriteWinsResolver<Task>()
```

**Behavior:** Most recent modification wins

**Use Case:** Simple scenarios, collaborative editing

#### Local Priority
```dart
LocalPriorityResolver<Task>()
```

**Behavior:** Local changes always win

**Use Case:** Offline-first apps, user preferences

#### Remote Priority
```dart
RemotePriorityResolver<Task>()
```

**Behavior:** Remote changes always win

**Use Case:** Server authority, synchronized state

### 🛠️ Custom Resolver

```dart
class TaskMergeResolver extends SyncConflictResolver<Task> {
  @override
  Future<ConflictResolution<Task>> resolve({
    required Task? localItem,
    required Task? remoteItem,
    required ConflictContext context,
  }) async {
    if (localItem == null) return ConflictResolution.useRemote(remoteItem!);
    if (remoteItem == null) return ConflictResolution.useLocal(localItem);

    // Custom merge logic
    final merged = localItem.copyWith(
      title: remoteItem.modifiedAt.isAfter(localItem.modifiedAt)
          ? remoteItem.title
          : localItem.title,
      completed: localItem.completed || remoteItem.completed,
      modifiedAt: DateTime.now(),
      version: 'v${int.parse(localItem.version.substring(1)) + 1}',
    );

    return ConflictResolution.merge(merged);
  }

  @override
  String get name => 'TaskMerge';
}
```

### 🔍 Conflict Types

| Type | Description | Example |
|------|-------------|---------|
| `bothModified` | Both local and remote modified | User edits offline, server updates |
| `deletedLocally` | Deleted locally, modified remotely | User deletes, server updates |
| `deletedRemotely` | Modified locally, deleted remotely | User edits, server deletes |
| `versionMismatch` | Version conflict | Concurrent modifications |
| `userMismatch` | Different user IDs | Multi-user conflict |

---

## 📊 Event Streams

### 🎯 Event Types

#### Data Changes
```dart
manager.onDataChange.listen((event) {
  switch (event.changeType) {
    case ChangeType.added:
      print('Added: ${event.data.title}');
      break;
    case ChangeType.updated:
      print('Updated: ${event.data.title}');
      break;
    case ChangeType.deleted:
      print('Deleted: ${event.data.title}');
      break;
  }
});
```

#### Sync Progress
```dart
manager.onSyncProgress.listen((event) {
  final progress = (event.completed / event.total * 100).toStringAsFixed(1);
  print('Sync: $progress% (${event.completed}/${event.total})');
});
```

#### Conflicts
```dart
manager.onConflict.listen((event) {
  print('Conflict Type: ${event.context.type}');
  print('Entity ID: ${event.context.entityId}');
  print('Resolution: ${event.resolution?.action}');
});
```

#### Errors
```dart
manager.onError.listen((event) {
  print('Error: ${event.error}');
  print('Operation: ${event.operation}');
  print('Can Retry: ${event.canRetry}');
});
```

#### Sync Status
```dart
manager.syncStatusStream.listen((snapshot) {
  print('Status: ${snapshot.status}');
  print('Progress: ${snapshot.progress}');
  print('Pending: ${snapshot.pendingOperations}');
});
```

### 📡 All Events
```dart
manager.eventStream.listen((event) {
  if (event is DataChangeEvent<Task>) {
    // Handle data change
  } else if (event is SyncProgressEvent) {
    // Handle sync progress
  } else if (event is ConflictEvent<Task>) {
    // Handle conflict
  } else if (event is ErrorEvent) {
    // Handle error
  }
});
```

---

## 🎯 Advanced Features

### 👥 User Switching

```dart
enum UserSwitchStrategy {
  clearAndFetch,      // 🗑️ Clear local, fetch fresh
  syncThenSwitch,     // ✅ Sync current user first
  promptIfUnsyncedData, // ⚠️ Ask user if unsynced data
  keepLocal,          // 💾 Keep local data as-is
}

final result = await manager.switchUser(
  oldUserId: 'user1',
  newUserId: 'user2',
  strategy: UserSwitchStrategy.syncThenSwitch,
);

if (result.success) {
  print('Switched successfully');
} else {
  print('Switch failed: ${result.error}');
}
```

### 🎨 Middleware

```dart
class LoggingMiddleware<T extends SyncableEntity> extends SynqMiddleware<T> {
  @override
  Future<void> beforeSync(String userId) async {
    print('🔄 Starting sync for $userId');
  }

  @override
  Future<void> afterSync(String userId, SyncResult result) async {
    print('✅ Synced ${result.syncedCount} items');
  }

  @override
  Future<T> transformBeforeSave(T item) async {
    print('💾 Saving: ${item.id}');
    return item;
  }

  @override
  Future<T> transformAfterFetch(T item) async {
    print('📥 Fetched: ${item.id}');
    return item;
  }

  @override
  Future<void> onConflict(ConflictContext context, T? local, T? remote) async {
    print('⚠️ Conflict: ${context.type}');
  }
}

// Add middleware
manager.addMiddleware(LoggingMiddleware<Task>());
```

### 📊 Metrics & Monitoring

```dart
// Get sync statistics
final stats = await manager.getSyncStatistics('user123');
print('Total syncs: ${stats.totalSyncs}');
print('Success rate: ${(stats.successfulSyncs / stats.totalSyncs * 100).toStringAsFixed(1)}%');
print('Avg duration: ${stats.averageDuration.inSeconds}s');
print('Last sync: ${stats.lastSyncTime}');

// Get current sync status
final snapshot = await manager.getSyncSnapshot('user123');
print('Status: ${snapshot.status}');
print('Progress: ${snapshot.progress}');
print('Pending: ${snapshot.pendingOperations}');
print('Last error: ${snapshot.lastError}');

// Health check
final health = await manager.getHealthStatus();
print('Local adapter: ${health.localAdapterHealthy}');
print('Remote adapter: ${health.remoteAdapterHealthy}');
print('Network: ${health.networkConnected}');
```

### ⏸️ Pause & Resume

```dart
// Pause sync
manager.pauseSync('user123');

// Resume sync
manager.resumeSync('user123');

// Cancel ongoing sync
await manager.cancelSync('user123');
```

---

## 🧪 Testing

### 📝 Test Coverage

**34 comprehensive tests** covering:

- ✅ Queue Management (6 tests)
- ✅ Conflict Detection (8 tests)
- ✅ Resolution Strategies (8 tests)
- ✅ Integration Scenarios (12 tests)

### 🚀 Run Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/queue_manager_test.dart

# Run with coverage
flutter test --coverage

# Watch mode
flutter test --watch
```

### 🧪 Example Test

```dart
test('should sync data successfully', () async {
  // Arrange
  final localAdapter = MockLocalAdapter<Task>();
  final remoteAdapter = MockRemoteAdapter<Task>();
  final manager = SynqManager<Task>(
    localAdapter: localAdapter,
    remoteAdapter: remoteAdapter,
  );

  await manager.initialize();

  final task = Task(
    id: 'task-1',
    userId: 'user1',
    title: 'Test task',
    modifiedAt: DateTime.now(),
    createdAt: DateTime.now(),
    version: 'v1',
  );

  // Act
  await manager.save(task, 'user1');
  final result = await manager.sync('user1');

  // Assert
  expect(result.syncedCount, equals(1));
  expect(result.failedCount, equals(0));
});
```

---

## 📝 Best Practices

### 🏗️ Design Guidelines

#### ✅ **DO:**
- Implement `SyncableEntity` correctly with all required fields
- Use meaningful IDs (UUID recommended)
- Include version tracking for conflict detection
- Add timestamps for all entities
- Use soft deletes with `isDeleted` flag

#### ❌ **DON'T:**
- Modify `id` or `userId` after creation
- Skip version updates on modifications
- Use auto-incrementing IDs in distributed systems
- Forget to handle `isDeleted` in queries

### 🔐 Security Best Practices

#### ✅ **DO:**
- Validate user permissions before sync
- Encrypt sensitive data in local storage
- Use secure communication (HTTPS) for remote sync
- Implement proper authentication
- Sanitize data before saving

#### ❌ **DON'T:**
- Store sensitive data unencrypted
- Trust client-side validation alone
- Skip authentication checks
- Expose internal IDs to users

### ⚡ Performance Tips

#### ✅ **DO:**
- Use batch operations for bulk data
- Configure appropriate sync intervals
- Implement efficient indexes in local storage
- Use pagination for large datasets
- Monitor sync performance metrics

#### ❌ **DON'T:**
- Sync too frequently (battery drain)
- Load all data into memory at once
- Ignore network conditions
- Skip error handling and retries

### 🔄 Sync Strategy

#### ✅ **DO:**
- Start with conservative sync intervals (5-15 minutes)
- Implement proper conflict resolution strategy
- Test sync with poor network conditions
- Handle offline mode gracefully
- Provide user feedback during sync

#### ❌ **DON'T:**
- Force sync on every user action
- Assume network is always available
- Ignore sync conflicts
- Block UI during sync operations

---

## 🛠️ Development

### 🚀 Getting Started

```bash
# Clone repository
git clone https://github.com/ahmtydn/synq_manager.git
cd synq_manager

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run example
cd example
flutter run
```

### 🔍 Project Structure

```
synq_manager/
├── lib/
│   ├── synq_manager.dart              # Public API
│   └── src/
│       ├── core/                      # Core components
│       │   ├── synq_manager.dart      # Main manager class
│       │   ├── sync_engine.dart       # Sync orchestration
│       │   ├── queue_manager.dart     # Operation queue
│       │   └── conflict_detector.dart # Conflict detection
│       ├── adapters/                  # Adapter interfaces
│       │   ├── local_adapter.dart
│       │   └── remote_adapter.dart
│       ├── resolvers/                 # Conflict resolvers
│       │   ├── sync_conflict_resolver.dart
│       │   ├── last_write_wins_resolver.dart
│       │   ├── local_priority_resolver.dart
│       │   └── remote_priority_resolver.dart
│       ├── middleware/                # Middleware system
│       │   └── synq_middleware.dart
│       ├── models/                    # Data models
│       │   ├── syncable_entity.dart
│       │   ├── sync_operation.dart
│       │   ├── sync_result.dart
│       │   ├── conflict_context.dart
│       │   └── sync_metadata.dart
│       └── events/                    # Event system
│           ├── sync_event.dart
│           ├── data_change_event.dart
│           └── conflict_event.dart
├── test/                              # Tests (34 tests)
│   ├── core/
│   ├── resolvers/
│   ├── integration/
│   └── mocks/
├── example/                           # Example app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   └── adapters/
│   └── README.md
├── DOCUMENTATION.md                   # Full documentation
├── CONTRIBUTING.md                    # Contribution guide
└── README.md                          # This file
```

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### 🐛 Bug Reports

- Use the [issue tracker](https://github.com/ahmtydn/synq_manager/issues)
- Include minimal reproduction case
- Provide environment details

### 💡 Feature Requests

- Check existing [discussions](https://github.com/ahmtydn/synq_manager/discussions)
- Explain use case and benefits
- Consider implementation complexity

### 🔧 Pull Requests

1. **Fork** the repository
2. **Create** feature branch (`git checkout -b feature/amazing-feature`)
3. **Add** tests for new functionality
4. **Ensure** all tests pass (`flutter test`)
5. **Run** analysis (`flutter analyze`)
6. **Commit** changes (`git commit -m 'Add amazing feature'`)
7. **Push** to branch (`git push origin feature/amazing-feature`)
8. **Submit** pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 📞 Support & Community

### 📚 **Documentation**
- [Full Documentation](DOCUMENTATION.md)
- [API Reference](https://pub.dev/documentation/synq_manager/latest/)
- [Example App](example/)

### 💬 **Community**
- [GitHub Discussions](https://github.com/ahmtydn/synq_manager/discussions)
- [Issue Tracker](https://github.com/ahmtydn/synq_manager/issues)

### 🆘 **Need Help?**
- Check the [FAQ](https://github.com/ahmtydn/synq_manager/discussions/categories/q-a)
- Search [existing issues](https://github.com/ahmtydn/synq_manager/issues)
- Ask in [discussions](https://github.com/ahmtydn/synq_manager/discussions)

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Flutter Team** - For the amazing framework
- **Dart Team** - For excellent language and tooling
- **RxDart Contributors** - For reactive programming support
- **Open Source Community** - For inspiration and feedback
- **Contributors** - For making this project better

---

## 🌟 Show Your Support

If this project helped you, please consider:

- ⭐ **Star** the repository
- 🔗 **Share** with your team
- 🐛 **Report** issues
- 💡 **Suggest** improvements
- 🤝 **Contribute** code

---

<div align="center">

**Built with ❤️ for the Flutter and Dart communities**

[🌐 Repository](https://github.com/ahmtydn/synq_manager) • [📚 Documentation](DOCUMENTATION.md) • [💬 Community](https://github.com/ahmtydn/synq_manager/discussions)

</div>
