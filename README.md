# SynQ Manager

[![pub package](https://img.shields.io/pub/v/synq_manager.svg)](https://pub.dev/packages/synq_manager)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev)

A powerful synchronization manager for Flutter apps with secure local storage, real-time state management, background cloud sync capabilities, and **Socket.io-style event handling**.

## ✨ Features

🎯 **Simplified Socket.io Style Events**: Clean, intuitive event handling with only essential callbacks
- `onEvent` - Universal event listener for all events
- `onInit` - Initialization with all existing data
- `onCreate` - New item creation events
- `onUpdate` - Item modification events  
- `onDelete` - Item deletion events
- `onError` - Error handling

-  **Real-time Synchronization**: Automatic cloud sync with configurable intervals
- 📱 **Background Sync**: Uses WorkManager for background synchronization when app is closed
- 🔐 **Secure Storage**: Encrypted local storage with Hive Plus Secure
- ⚔️ **Conflict Resolution**: Intelligent conflict handling with multiple resolution strategies
- 🌐 **Connectivity Aware**: Automatic sync when network becomes available
- 🎯 **Type-safe API**: Full TypeScript-like generics support for type safety
- ⚡ **High Performance**: Optimized for mobile with single-instance listeners
- 🔧 **Customizable**: Flexible configuration for different use cases
- 📊 **Event-driven**: Real-time event streams for UI updates
- 🏠 **Local-first**: Works offline, syncs when online
- ⭐ **Cascade Notation**: Efficient single-instance listener pattern

## 🚀 Platform Support

**Mobile Only**: This package is designed for mobile platforms (Android & iOS) due to WorkManager dependency requirements.

- ✅ Android
- ✅ iOS
- ❌ Web (WorkManager not supported)
- ❌ Desktop (WorkManager not supported)

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  synq_manager: latest_version
```

Run:

```bash
flutter pub get
```

## 🛠️ WorkManager Setup

SynQ Manager uses WorkManager for background synchronization. Follow these platform-specific setup instructions:

### Android Setup

1. **Minimum SDK Version**: Add to `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 23  // WorkManager requires API 23+
        targetSdkVersion 34
    }
}
```

2. **Permissions**: Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- For background sync -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

3. **WorkManager Service**: Add to `android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
<service
    android:name="be.tramckrijte.workmanager.BackgroundService"
    android:exported="false" />
    
<receiver
    android:name="be.tramckrijte.workmanager.BackgroundService$AlarmReceiver"
    android:exported="false" />
```

### iOS Setup

1. **Minimum iOS Version**: Update `ios/Podfile`:

```ruby
platform :ios, '12.0'  # WorkManager requires iOS 12.0+
```

2. **Background Modes**: Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
    <string>background-fetch</string>
</array>
```

3. **Background App Refresh**: Add to `ios/Runner/Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>be.tramckrijte.workmanager.BackgroundService</string>
</array>
```

## 🎯 Quick Start

### 1. Basic Setup

```dart
import 'package:synq_manager/synq_manager.dart';

// Define your data model
class UserProfile {
  final String id;
  final String name;
  final String email;
  
  UserProfile({required this.id, required this.name, required this.email});
  
  // Add serialization methods
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };
  
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    name: json['name'],
    email: json['email'],
  );
}

// Initialize SynqManager
late SynqManager<UserProfile> userManager;

Future<void> initializeSynq() async {
  userManager = await SynqManager.getInstance<UserProfile>(
    instanceName: 'user_profiles',
    config: SyncConfig(
      syncInterval: Duration(minutes: 5),
      enableBackgroundSync: true,
      encryptionKey: 'your-encryption-key', // Optional
    ),
    cloudSyncFunction: _syncToCloud,
    cloudFetchFunction: _fetchFromCloud,
    fromJson: UserProfile.fromJson, // Function to deserialize UserProfile from JSON
    toJson: (profile) => profile.toJson(), // Function to serialize UserProfile to JSON
  );
}
```

**Important**: The `fromJson` and `toJson` parameters are required when working with complex custom objects that need proper JSON serialization/deserialization. For simple types like `String`, `int`, `Map<String, dynamic>`, these parameters can be omitted.

### 2. Implement Cloud Functions

```dart
// Sync local changes to cloud
Future<SyncResult<UserProfile>> _syncToCloud(
  Map<String, SyncData<UserProfile>> localChanges,
  Map<String, String> headers,
) async {
  try {
    // Your API call logic here
    final response = await http.post(
      Uri.parse('https://your-api.com/sync'),
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode({
        'changes': localChanges.map((key, data) => MapEntry(key, {
          'value': data.value.toJson(),
          'version': data.version,
          'timestamp': data.timestamp,
          'deleted': data.deleted,
        })),
      }),
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final remoteData = <String, SyncData<UserProfile>>{};
      
      // Parse remote data
      for (final entry in responseData['data'].entries) {
        remoteData[entry.key] = SyncData<UserProfile>(
          value: UserProfile.fromJson(entry.value['value']),
          version: entry.value['version'],
          timestamp: entry.value['timestamp'],
          deleted: entry.value['deleted'] ?? false,
        );
      }
      
      return SyncResult<UserProfile>(
        success: true,
        remoteData: remoteData,
        conflicts: [], // Handle conflicts if any
      );
    } else {
      throw Exception('Sync failed: ${response.statusCode}');
    }
  } catch (error) {
    return SyncResult<UserProfile>(
      success: false,
      error: error,
    );
  }
}

// Fetch updates from cloud
Future<Map<String, SyncData<UserProfile>>> _fetchFromCloud(
  int lastSyncTimestamp,
  Map<String, String> headers,
) async {
  try {
    final response = await http.get(
      Uri.parse('https://your-api.com/updates?since=$lastSyncTimestamp'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final remoteData = <String, SyncData<UserProfile>>{};
      
      for (final entry in responseData['data'].entries) {
        remoteData[entry.key] = SyncData<UserProfile>(
          value: UserProfile.fromJson(entry.value['value']),
          version: entry.value['version'],
          timestamp: entry.value['timestamp'],
          deleted: entry.value['deleted'] ?? false,
        );
      }
      
      return remoteData;
    } else {
      throw Exception('Fetch failed: ${response.statusCode}');
    }
  } catch (error) {
    return {};
  }
}
```

### 3. Use the Manager

```dart
class UserProfileScreen extends StatefulWidget {
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  StreamSubscription<SynqEvent<UserProfile>>? _subscription;
  List<UserProfile> _profiles = [];
  
  @override
  void initState() {
    super.initState();
    _setupListener();
    _loadProfiles();
  }
  
  void _setupListener() {
    _subscription = userManager.onData.listen((event) {
      setState(() {
        // Update UI based on events
        switch (event.type) {
          case SynqEventType.create:
          case SynqEventType.update:
            _loadProfiles(); // Refresh list
            break;
          case SynqEventType.delete:
            _profiles.removeWhere((p) => p.id == event.key);
            break;
        }
      });
    });
    
    // Listen to sync events
    userManager.onDone.listen((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync completed')),
      );
    });
    
    userManager.onError.listen((event) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync error: ${event.error}')),
      );
    });
  }
  
  Future<void> _loadProfiles() async {
    final profiles = await userManager.getAll();
    setState(() {
      _profiles = profiles.values.toList();
    });
  }
  
  Future<void> _addProfile() async {
    final profile = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'New User',
      email: 'user@example.com',
    );
    
    await userManager.put(profile.id, profile);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profiles'),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () => userManager.sync(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync status
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(userManager.connectivityStatus == ConnectivityStatus.online 
                  ? Icons.cloud_done : Icons.cloud_off),
                SizedBox(width: 8),
                Text(userManager.isSyncing ? 'Syncing...' : 'Ready'),
                Spacer(),
                Text('Pending: ${userManager.pendingChangesCount}'),
              ],
            ),
          ),
          // Profile list
          Expanded(
            child: ListView.builder(
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                return ListTile(
                  title: Text(profile.name),
                  subtitle: Text(profile.email),
                  onTap: () => _editProfile(profile),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProfile,
        child: Icon(Icons.add),
      ),
    );
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

### 3B. Socket.io Style Usage (New! 🚀)

For a more intuitive and less boilerplate approach, use the new Socket.io-style API:

```dart
class UserProfileScreen extends StatefulWidget {
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  List<UserProfile> _profiles = [];
  bool _syncing = false;
  SynqListeners<UserProfile>? _listeners;
  
  @override
  void initState() {
    super.initState();
    _setupSocketStyleListeners();
  }
  
  void _setupSocketStyleListeners() {
    // Simplified Socket.io style - single instance with cascade notation
    _listeners = userManager.on()
      ..onInit((allProfiles) {
        // Called when manager is ready with ALL data
        print('📥 Loaded ${allProfiles.length} profiles');
        setState(() {
          _profiles = allProfiles.values.toList();
        });
      })
      ..onCreate((key, profile) {
        // Called when NEW profile is created - only new data
        print('✨ New profile created: ${profile.name}');
        setState(() {
          _profiles.add(profile);
        });
      })
      ..onUpdate((key, profile) {
        // Called when profile is updated - only updated data
        print('📝 Profile updated: ${profile.name}');
        setState(() {
          final index = _profiles.indexWhere((p) => p.id == key);
          if (index != -1) _profiles[index] = profile;
        });
      })
      ..onDelete((key) {
        // Called when profile is deleted - only key
        print('🗑️ Profile deleted: $key');
        setState(() {
          _profiles.removeWhere((p) => p.id == key);
        });
      })
      ..onError((error) {
        setState(() => _syncing = false);
        _showError('Sync failed: $error');
      })
      ..onEvent((event) {
        // Listen to all events - general callback
        print('📊 Event: ${event.type}');
        switch (event.type) {
          case SynqEventType.syncStart:
            setState(() => _syncing = true);
            break;
          case SynqEventType.syncComplete:
            setState(() => _syncing = false);
            _showMessage('Sync completed! ✅');
            break;
          default:
            break;
        }
      });
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profiles'),
        actions: [
          if (_syncing) 
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.sync),
              onPressed: () => userManager.sync(),
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _profiles.length,
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          return ListTile(
            title: Text(profile.name),
            subtitle: Text(profile.email),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => userManager.delete(profile.id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProfile,
        child: Icon(Icons.add),
      ),
    );
  }
  
  Future<void> _addProfile() async {
    final profile = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'New User ${_profiles.length + 1}',
      email: 'user${_profiles.length + 1}@example.com',
    );
    
    // This will automatically trigger onCreate() callback
    await userManager.put(profile.id, profile);
  }
  
  @override
  void dispose() {
    _listeners?.dispose(); // Clean up listeners
    super.dispose();
  }
}
```

### Socket.io Style API Reference

| Method | When Called | Data Provided | Use Case |
|--------|-------------|---------------|----------|
| `onEvent(callback)` | **All events** | **Event object** | Listen to all events in one place |
| `onInit(callback)` | Manager ready | **All existing data** | Initialize UI with all data |
| `onCreate(callback)` | New item added | **Only new item** | Add item to UI |
| `onUpdate(callback)` | Item modified | **Only updated item** | Update item in UI |
| `onDelete(callback)` | Item removed | **Only key** | Remove item from UI |
| `onError(callback)` | Error occurs | **Error object** | Show error message |

**Key Benefits of Simplified API:**
- 🚀 **Single Instance**: Uses cascade notation with one listener instance instead of multiple
- ⚡ **Better Performance**: Reduced memory footprint and improved efficiency
- 🎯 **Essential Callbacks Only**: Removed 10+ redundant callbacks, kept only the necessary 6
- 🔄 **Universal Event Handler**: `onEvent()` captures all events for advanced use cases
- � **Clean Code**: Intuitive API that's easy to understand and maintain

**Pattern Comparison:**
```dart
// ❌ Old: Creates multiple instances
manager.onInit(...).onCreate(...).onUpdate(...)

// ✅ New: Single instance with cascade
final listeners = manager.on();
listeners..onInit(...)..onCreate(...)..onUpdate(...);
```

## 🔧 Advanced Configuration

```dart
final config = SyncConfig(
  // Sync frequency
  syncInterval: Duration(minutes: 5),
  
  // Batch processing
  batchSize: 50,
  maxRetries: 3,
  retryDelay: Duration(seconds: 2),
  
  // Network settings
  requestTimeout: Duration(seconds: 30),
  connectTimeout: Duration(seconds: 10),
  
  // Encryption (AES-256)
  encryptionKey: 'your-32-character-encryption-key',
  
  // Conflict resolution strategy
  conflictResolution: ConflictResolution.lastWriteWins,
```

## ⚙️ Configuration Options

### SyncConfig

```dart
final config = SyncConfig(
  // Sync interval (default: 5 minutes)
  syncInterval: Duration(minutes: 5),
  
  // Retry attempts for failed syncs (default: 3)
  retryAttempts: 3,
  
  // Delay between retries (default: 2 seconds)
  retryDelay: Duration(seconds: 2),
  
  // Batch size for bulk operations (default: 50)
  batchSize: 50,
  
  // Encryption key for local storage (optional)
  encryptionKey: 'your-secret-key',
  
  // Sync priority (default: normal)
  priority: SyncPriority.high,
  
  // Enable background sync (default: true)
  enableBackgroundSync: true,
  
  // Enable automatic retry (default: true)
  enableAutoRetry: true,
  
  // Enable conflict resolution (default: true)
  enableConflictResolution: true,
  
  // Maximum storage size in MiB (default: 100)
  maxStorageSize: 100,
  
  // Enable compression (default: true)
  compressionEnabled: true,
  
  // Custom headers for API calls
  customHeaders: {
    'Authorization': 'Bearer $token',
    'X-API-Version': '1.0',
  },
);
```

### Predefined Configurations

```dart
// High priority - frequent syncs
final config = SyncConfig.highPriority(
  encryptionKey: 'key',
  customHeaders: {'Authorization': 'Bearer $token'},
);

// Low priority - less frequent syncs
final config = SyncConfig.lowPriority();

// Mobile optimized - smaller batches, longer intervals
final config = SyncConfig.mobile();
```

## 🔄 Conflict Resolution

Handle data conflicts when the same data is modified both locally and remotely:

```dart
// Listen for conflicts
userManager.onConflict.listen((event) async {
  final conflict = userManager.activeConflicts[event.key];
  if (conflict != null) {
    // Show conflict resolution UI
    await _showConflictDialog(conflict);
  }
});

Future<void> _showConflictDialog(DataConflict<UserProfile> conflict) async {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Data Conflict'),
      content: Column(
        children: [
          Text('Local: ${conflict.localData.value.name}'),
          Text('Remote: ${conflict.remoteData.value.name}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Use local version
            userManager.resolveConflict(
              conflict.key,
              ConflictResolutionStrategy.useLocal,
            );
            Navigator.pop(context);
          },
          child: Text('Keep Local'),
        ),
        TextButton(
          onPressed: () {
            // Use remote version
            userManager.resolveConflict(
              conflict.key,
              ConflictResolutionStrategy.useRemote,
            );
            Navigator.pop(context);
          },
          child: Text('Use Remote'),
        ),
        TextButton(
          onPressed: () {
            // Use custom merge logic
            userManager.resolveConflict(
              conflict.key,
              ConflictResolutionStrategy.merge,
              customResolver: (local, remote) {
                // Custom merge logic
                return local.copyWith(
                  value: UserProfile(
                    id: local.value.id,
                    name: remote.value.name, // Use remote name
                    email: local.value.email, // Keep local email
                  ),
                );
              },
            );
            Navigator.pop(context);
          },
          child: Text('Merge'),
        ),
      ],
    ),
  );
}
```

## 📊 Monitoring & Statistics

```dart
// Get sync statistics
final syncStats = userManager.syncStats;
print('Last sync: ${syncStats.timeSinceLastSync}');
print('Pending changes: ${syncStats.pendingChangesCount}');
print('Active conflicts: ${syncStats.activeConflictsCount}');

// Get storage statistics
final storageStats = await userManager.storageStats;
print('Total items: ${storageStats.totalItems}');
print('Storage size: ${storageStats.sizeInBytes} bytes');

// Monitor connectivity
userManager.onConnected.listen((_) {
  print('Connected to internet');
});

userManager.onDisconnected.listen((_) {
  print('Lost internet connection');
});
```

## 🧪 Testing

For testing, you can mock the cloud functions:

```dart
// Mock sync function for testing
Future<SyncResult<TestModel>> mockSyncFunction(
  Map<String, SyncData<TestModel>> localChanges,
  Map<String, String> headers,
) async {
  // Simulate network delay
  await Future.delayed(Duration(milliseconds: 100));
  
  return SyncResult<TestModel>(
    success: true,
    remoteData: {},
  );
}

// Mock fetch function for testing
Future<Map<String, SyncData<TestModel>>> mockFetchFunction(
  int lastSyncTimestamp,
  Map<String, String> headers,
) async {
  await Future.delayed(Duration(milliseconds: 100));
  return {};
}

// Use in tests
final testManager = await SynqManager.getInstance<TestModel>(
  instanceName: 'test',
  cloudSyncFunction: mockSyncFunction,
  cloudFetchFunction: mockFetchFunction,
);
```

## 🚀 Advanced Usage

### Multiple Managers

You can create multiple managers for different data types:

```dart
final userManager = await SynqManager.getInstance<User>(
  instanceName: 'users',
  cloudSyncFunction: syncUsers,
  cloudFetchFunction: fetchUsers,
);

final postManager = await SynqManager.getInstance<Post>(
  instanceName: 'posts',
  cloudSyncFunction: syncPosts,
  cloudFetchFunction: fetchPosts,
);
```

### Custom Event Handling

```dart
// Listen to specific events
userManager.onEvent(SynqEventType.syncStart).listen((_) {
  // Show loading indicator
});

userManager.onEvent(SynqEventType.syncComplete).listen((_) {
  // Hide loading indicator
});

// Filter events by key
userManager.events
  .where((event) => event.key.startsWith('user_'))
  .listen((event) {
    // Handle user-specific events
  });
```

### Force Sync Specific Keys

```dart
// Sync only specific items
await userManager.syncKeys(['user_1', 'user_2']);
```

## 🔧 Troubleshooting

### Common Issues

1. **Background sync not working**: Ensure WorkManager setup is correct and app has background permissions.

2. **Encryption errors**: Make sure the encryption key is consistent across app launches.

3. **Memory issues**: Reduce `batchSize` and `maxStorageSize` for memory-constrained devices.

4. **Sync conflicts**: Implement proper conflict resolution strategies for your use case.

### Debug Mode

Enable debug logging:

```dart
import 'package:flutter/foundation.dart';

// Debug events
if (kDebugMode) {
  userManager.events.listen((event) {
    print('SynQ Event: ${event.type} - ${event.key}');
  });
}
```

## 📄 API Reference

### SynqManager<T>

Main manager class for synchronization operations.

#### Methods

- `Future<void> put(String key, T value, {Map<String, dynamic>? metadata})` - Store data
- `Future<T?> get(String key)` - Retrieve data
- `Future<void> update(String key, T value, {Map<String, dynamic>? metadata})` - Update data
- `Future<void> delete(String key)` - Delete data
- `Future<Map<String, T>> getAll()` - Get all data
- `Future<void> sync()` - Manual sync
- `Future<void> syncKeys(List<String> keys)` - Sync specific keys
- `Future<void> resolveConflict(String key, ConflictResolutionStrategy strategy)` - Resolve conflicts

#### Properties

- `Stream<SynqEvent<T>> events` - All events stream
- `bool isReady` - Whether manager is ready
- `ConnectivityStatus connectivityStatus` - Current connectivity
- `bool isSyncing` - Whether sync is in progress
- `int pendingChangesCount` - Number of pending changes
- `Map<String, DataConflict<T>> activeConflicts` - Active conflicts
- `SyncStats syncStats` - Sync statistics

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Documentation](https://github.com/ahmtydn/synq_manager)
- [Issues](https://github.com/ahmtydn/synq_manager/issues)
- [Changelog](CHANGELOG.md)

---

Made with ❤️ for the Flutter community
