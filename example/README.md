# SynqManager Example

A comprehensive example demonstrating how to use SynqManager for offline-first task management.

## Features Demonstrated

- ✅ **CRUD Operations** — Create, read, update, and delete tasks
- ✅ **Automatic Sync** — Background synchronization every 30 seconds
- ✅ **Manual Sync** — Trigger sync on-demand with sync button
- ✅ **Real-Time Updates** — UI updates automatically on data changes
- ✅ **Offline Support** — Works without network connection
- ✅ **Sync Status** — Visual indicators for pending operations
- ✅ **Conflict Resolution** — Automatic conflict handling with last-write-wins

## Project Structure

```
example/
├── lib/
│   ├── main.dart                           # Main app with TaskListScreen
│   ├── models/
│   │   └── task.dart                       # Task entity implementation
│   └── adapters/
│       ├── memory_local_adapter.dart       # In-memory local storage
│       └── memory_remote_adapter.dart      # In-memory remote storage
├── pubspec.yaml
└── README.md
```

## How to Run

1. Navigate to the example directory:
   ```bash
   cd example
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Code Highlights

### 1. Entity Definition

The `Task` class implements `SyncableEntity`:

```dart
class Task implements SyncableEntity {
  final String id;
  final String userId;
  final String title;
  final bool completed;
  final DateTime modifiedAt;
  final DateTime createdAt;
  final String version;
  final bool isDeleted;
  
  // Implement toJson, fromJson, copyWith...
}
```

### 2. Manager Initialization

```dart
final manager = SynqManager<Task>(
  localAdapter: MemoryLocalAdapter<Task>(fromJson: Task.fromJson),
  remoteAdapter: MemoryRemoteAdapter<Task>(fromJson: Task.fromJson),
  synqConfig: SynqConfig(
    autoSyncInterval: const Duration(seconds: 30),
    enableLogging: true,
    defaultConflictResolver: LastWriteWinsResolver<Task>(),
  ),
);

await manager.initialize();
manager.startAutoSync(userId);
```

### 3. Event Handling

```dart
// Listen to data changes
manager.onDataChange.listen((event) {
  print('${event.changeType}: ${event.data.title}');
  _loadTasks(); // Refresh UI
});

// Listen to sync progress
manager.onSyncProgress.listen((event) {
  setState(() {
    _syncStatus = 'Syncing: ${event.completed}/${event.total}';
  });
});

// Listen to conflicts
manager.onConflict.listen((event) {
  showSnackBar('Conflict detected: ${event.context.type}');
});
```

### 4. CRUD Operations

```dart
// Create
await manager.save(newTask, userId);

// Read
final tasks = await manager.getAll(userId);
final task = await manager.getById(taskId, userId);

// Update
await manager.save(updatedTask, userId);

// Delete
await manager.delete(taskId, userId);
```

### 5. Synchronization

```dart
// Manual sync
final result = await manager.sync(userId);
print('Synced: ${result.syncedCount}, Failed: ${result.failedCount}');

// Auto-sync
manager.startAutoSync(userId, interval: Duration(seconds: 30));

// Stop auto-sync
manager.stopAutoSync(userId: userId);
```

## Adapters

### Memory Local Adapter

The example uses an in-memory implementation for simplicity. In production:

- Use **Hive** for lightweight local storage
- Use **SQLite** for relational data
- Use **SharedPreferences** for simple key-value storage

### Memory Remote Adapter

The example simulates a remote server in-memory. In production:

- Use **Firebase Firestore** for real-time sync
- Use **REST API** with HTTP client
- Use **GraphQL** for flexible queries

## Next Steps

To adapt this example for production:

1. **Replace adapters** with real storage implementations
2. **Add authentication** for user management
3. **Implement custom conflict resolvers** for complex merge logic
4. **Add middleware** for logging, analytics, or validation
5. **Configure retry strategies** for network failures
6. **Add error handling** and user feedback

## Learn More

- [Full Documentation](../DOCUMENTATION.md)
- [API Reference](../README.md)
- [SynqManager Repository](https://github.com/ahmtydn/synq_manager)
