# SynqManager Notes Demo

A comprehensive Flutter example demonstrating the **SynqManager** package capabilities for local storage, cloud synchronization, and conflict resolution.

## Features

This example app demonstrates:

- ✅ **Local Storage**: Persistent storage with encryption
- ✅ **Real-time Events**: Live updates for data changes
- ✅ **Cloud Synchronization**: Mock cloud sync with retry logic
- ✅ **Conflict Resolution**: Automatic conflict handling
- ✅ **Background Sync**: Automatic synchronization in background
- ✅ **Error Handling**: Graceful error management
- ✅ **CRUD Operations**: Create, Read, Update, Delete operations
- ✅ **Data Persistence**: Survives app restarts

## What's Included

### Models
- **Note**: A sample data model with JSON serialization
- **NoteColor**: Enum for note color themes

### Key Features Demonstrated
1. **SynqManager Setup**: Proper initialization with configuration
2. **Event Listening**: Real-time sync status and data change events
3. **Local Operations**: CRUD operations on local storage
4. **Cloud Integration**: Mock cloud sync and fetch functions
5. **UI Integration**: Flutter UI with Provider state management

### App Functionality
- Create, edit, and delete notes
- Color-coded notes with importance flags
- Manual sync trigger
- Real-time sync status display
- Automatic background synchronization
- Persistent data storage

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)

### Installation

1. Navigate to the example directory:
```bash
cd example
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate JSON serialization code:
```bash
dart run build_runner build
```

4. Run the app:
```bash
flutter run
```

## How It Works

### SynqManager Configuration
```dart
_synqManager = await SynqManager.getInstance<Map<String, dynamic>>(
  instanceName: 'notes_manager',
  config: const SyncConfig(
    syncInterval: Duration(seconds: 30),
    encryptionKey: 'example_encryption_key_32_chars!',
    enableBackgroundSync: true,
    enableConflictResolution: true,
  ),
  cloudSyncFunction: _mockCloudSync,
  cloudFetchFunction: _mockCloudFetch,
);
```

### Event Handling
```dart
_eventSubscription = _synqManager!.events.listen(_handleSynqEvent);
```

### CRUD Operations
```dart
// Create
await _synqManager!.put(note.id, note.toJson());

// Read
final notesData = await _synqManager!.getAll();

// Update
await _synqManager!.update(note.id, updatedNote.toJson());

// Delete
await _synqManager!.delete(note.id);
```

### Cloud Integration
The example includes mock cloud functions that simulate:
- Network delays
- Occasional network errors
- Successful sync operations
- Data fetching from remote server

In a real application, replace these with actual API calls to your backend service.

## Key Code Files

- `lib/main.dart` - Main app with SynqManager integration
- `lib/models/note.dart` - Note data model with JSON serialization
- `lib/models/note.g.dart` - Generated JSON serialization code

## Architecture

```
┌─────────────────────┐
│    Flutter UI       │
├─────────────────────┤
│    SynqManager      │
├─────────────────────┤
│  Storage Service    │  ←→  │  Sync Service  │
├─────────────────────┤      ├────────────────┤
│   Local Storage     │      │  Cloud Backend │
│   (Encrypted)       │      │   (Mock API)   │
└─────────────────────┘      └────────────────┘
```

## Learning Resources

- **SynqManager Documentation**: See the main package README
- **Flutter Provider**: [State management pattern](https://pub.dev/packages/provider)
- **JSON Serialization**: [Flutter JSON guide](https://docs.flutter.dev/data-and-backend/json)

## Next Steps

To adapt this example for your own app:

1. Replace the `Note` model with your own data structure
2. Implement real cloud sync functions with your backend API
3. Customize the UI to match your app's design
4. Add authentication and user-specific data handling
5. Configure appropriate sync intervals and conflict resolution strategies

## Troubleshooting

### Build Issues
- Ensure `dart run build_runner build` has been executed
- Check that all dependencies are properly installed

### Sync Issues
- Verify cloud functions are properly implemented
- Check network connectivity
- Review error messages in the status bar

### Performance
- Adjust sync intervals based on your use case
- Consider batch sizes for large datasets
- Monitor memory usage with large numbers of items
