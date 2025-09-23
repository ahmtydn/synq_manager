# SynQ Manager 🔄

A robust, offline-first synchronization layer for Flutter applications. SynQ Manager provides seamless sync between local storage and arbitrary cloud backends with conflict resolution, guest mode support, and background synchronization.

## ✨ Features

- **🔀 Offline-First**: All data stored locally first, works fully offline
- **⚡ Real-time Sync**: Automatic and manual sync with configurable policies  
- **🔀 Conflict Resolution**: Intelligent conflict detection with customizable resolution strategies
- **👤 Guest Mode**: Full functionality without authentication, upgradeable accounts
- **🔄 Background Sync**: Reliable background synchronization using WorkManager
- **🔌 Backend Agnostic**: Implement CloudAdapter interface for any backend (REST, GraphQL, gRPC)
- **💾 Multiple Storage**: Hive and Isar support with encrypted local storage
- **🎯 Type-Safe**: Strongly typed APIs with generic support
- **🧪 Well-Tested**: Comprehensive unit and integration tests

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  synq_manager: ^1.0.0
  
  # Required dependencies
  hive:
    git:
      url: https://github.com/isar/hive.git
      ref: 52384ded658ad573d16137ea643130ad18153c07
  isar_plus_flutter_libs: ^1.0.8
  workmanager: ^0.9.0+3
  flutter_secure_storage: ^9.2.2
```

## 🚀 Quick Start

### 1. Define Your Data Model

```dart
import 'package:synq_manager/synq_manager.dart';

class Note extends SyncCacheModel {
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.version = 0,
    this.isDeleted = false,
    this.isDirty = false,
    this.guestId,
  });

  @override
  final String id;
  final String title;
  final String content;
  
  @override
  final DateTime updatedAt;
  @override
  final int version;
  @override
  final bool isDeleted;
  @override
  final bool isDirty;
  @override
  final String? guestId;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'isDeleted': isDeleted,
    'isDirty': isDirty,
    'guestId': guestId,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
    version: json['version'] ?? 0,
    isDeleted: json['isDeleted'] ?? false,
    isDirty: json['isDirty'] ?? false,
    guestId: json['guestId'],
  );

  @override
  Note fromJson(dynamic json) => Note.fromJson(json);

  @override
  SyncCacheModel copyWithSyncData({
    DateTime? updatedAt,
    int? version,
    bool? isDeleted,
    bool? isDirty,
    String? guestId,
  }) => Note(
    id: id,
    title: title,
    content: content,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    isDeleted: isDeleted ?? this.isDeleted,
    isDirty: isDirty ?? this.isDirty,
    guestId: guestId ?? this.guestId,
  );
}
```

### 2. Initialize SyncManager

```dart
import 'package:synq_manager/synq_manager.dart';

class SyncService {
  late SyncManager _syncManager;
  late HiveLocalStore<Note> _notesStore;
  late MyCloudAdapter<Note> _cloudAdapter;
  late OfflineAuthProvider _authProvider;

  Future<void> initialize() async {
    // Initialize local storage
    _notesStore = HiveLocalStore<Note>(
      boxName: 'notes',
      adapter: Note.fromJson,
    );

    // Initialize your custom cloud adapter
    _cloudAdapter = MyCloudAdapter<Note>(
      // Your backend configuration
    );

    // Initialize auth provider
    _authProvider = OfflineAuthProvider();

    // Create sync manager
    _syncManager = SyncManager(
      policy: SyncPolicy.realtime,
    );

    // Initialize sync manager
    await _syncManager.initialize(
      stores: [_notesStore],
      adapters: {Note: _cloudAdapter},
      authProvider: _authProvider,
      conflictResolvers: {
        Note: DefaultConflictResolver<Note>(
          strategy: ConflictResolutionStrategy.newerWins,
        ),
      },
    );
  }

  // Create a note
  Future<void> createNote(String title, String content) async {
    final note = Note(
      id: uuid.v4(),
      title: title,
      content: content,
      updatedAt: DateTime.now(),
      isDirty: true,
    );

    await _notesStore.save(note);
    // Sync automatically triggers based on policy
  }

  // Get all notes
  Stream<List<Note>> watchNotes() => _notesStore.watchAll();

  // Manual sync
  Future<void> sync() => _syncManager.triggerSync();
}
```

### 3. Authentication

```dart
// Guest login (works offline)
await authProvider.loginAsGuest();

// Regular login
await authProvider.login('user@example.com', 'password');

// Upgrade guest to full account
await authProvider.upgradeGuestAccount(
  email: 'user@example.com',
  password: 'password',
  mergeGuestData: true,
);
```

## 🏗️ Architecture

### Core Components

- **SyncManager**: Central coordinator for all sync operations
- **LocalStore**: Generic interface for local storage (Hive implementation included)
- **CloudAdapter**: Pluggable interface for cloud backends
- **AuthProvider**: Authentication with offline support
- **ConflictResolver**: Customizable conflict resolution strategies

### Data Flow

```
[UI] ↔ [LocalStore] ↔ [SyncManager] ↔ [CloudAdapter] ↔ [Backend]
                          ↕
                    [AuthProvider]
                          ↕
                   [ConflictResolver]
```

## 📱 Platform Support

SynQ Manager supports **Android** and **iOS** platforms, providing native mobile synchronization capabilities.

## 📱 Platform Setup

### Android Setup

1. **Add WorkManager to `android/app/src/main/AndroidManifest.xml`:**

```xml
<application>
    <!-- Your existing configuration -->
    
    <!-- WorkManager for background sync -->
    <provider
        android:name="androidx.startup.InitializationProvider"
        android:authorities="\${applicationId}.androidx-startup"
        android:exported="false"
        tools:node="merge">
        <meta-data
            android:name="androidx.work.WorkManagerInitializer"
            android:value="androidx.startup" />
    </provider>
</application>

<!-- Required permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

2. **Create `android/app/src/main/kotlin/.../Application.kt`:**

```kotlin
import io.flutter.app.FlutterApplication
import be.tramckrijte.workmanager.WorkmanagerPlugin

class MainApplication: FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        WorkmanagerPlugin.initialize(this)
    }
}
```

3. **Update `android/app/src/main/AndroidManifest.xml`:**

```xml
<application
    android:name=".MainApplication"
    android:label="your_app_name">
    <!-- Your existing configuration -->
</application>
```

### iOS Setup

Add to `ios/Runner/Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>be.tramckrijte.workmanager.backgroundrefresh</string>
</array>
```

## 🔧 Implementing Cloud Adapters

SynQ Manager is completely backend-agnostic. You implement the `CloudAdapter` interface for your specific backend:

### CloudAdapter Interface

```dart
abstract class CloudAdapter<T extends SyncCacheModel> {
  String get adapterName;
  
  Future<void> initialize();
  Future<T> pushCreate(T entity);
  Future<T> pushUpdate(T entity);
  Future<void> pushDelete(String id, {int? version});
  Future<List<T>> fetchAll();
  Future<List<T>> fetchSince(DateTime since);
  Future<T?> fetchById(String id);
  Future<List<T>> pushBatch(List<T> entities);
  Future<List<T>> fetchBatch(List<String> ids);
}
```

### Example: REST API Adapter

```dart
class RestApiAdapter<T extends SyncCacheModel> implements CloudAdapter<T> {
  final String baseUrl;
  final String endpoint;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, String> headers;
  
  RestApiAdapter({
    required this.baseUrl,
    required this.endpoint,
    required this.fromJson,
    this.headers = const {},
  });

  @override
  String get adapterName => 'RestAPI';

  @override
  Future<void> initialize() async {
    // Initialize your API client
  }

  @override
  Future<T> pushCreate(T entity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(entity.toJson()),
    );
    
    if (response.statusCode == 201) {
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create entity');
  }

  @override
  Future<T> pushUpdate(T entity) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint/${entity.id}'),
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(entity.toJson()),
    );
    
    if (response.statusCode == 200) {
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update entity');
  }

  @override
  Future<void> pushDelete(String id, {int? version}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$endpoint/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 204) {
      throw Exception('Failed to delete entity');
    }
  }

  @override
  Future<List<T>> fetchAll() async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => fromJson(json)).toList();
    }
    throw Exception('Failed to fetch entities');
  }

  @override
  Future<List<T>> fetchSince(DateTime since) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint?since=${since.toIso8601String()}'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => fromJson(json)).toList();
    }
    throw Exception('Failed to fetch entities');
  }

  // ... implement other methods
}
```

### Example: Supabase Adapter

```dart
class SupabaseAdapter<T extends SyncCacheModel> implements CloudAdapter<T> {
  final SupabaseClient client;
  final String tableName;
  final T Function(Map<String, dynamic>) fromJson;
  
  SupabaseAdapter({
    required this.client,
    required this.tableName,
    required this.fromJson,
  });

  @override
  String get adapterName => 'Supabase';

  @override
  Future<T> pushCreate(T entity) async {
    final response = await client
        .from(tableName)
        .insert(entity.toJson())
        .select()
        .single();
    
    return fromJson(response);
  }

  @override
  Future<List<T>> fetchSince(DateTime since) async {
    final response = await client
        .from(tableName)
        .select()
        .gte('updated_at', since.toIso8601String());
    
    return response.map((json) => fromJson(json)).toList();
  }

  // ... implement other methods
}
```

### Example: Firebase Adapter

```dart
class FirebaseAdapter<T extends SyncCacheModel> implements CloudAdapter<T> {
  final FirebaseFirestore firestore;
  final String collection;
  final T Function(Map<String, dynamic>) fromJson;
  
  FirebaseAdapter({
    required this.firestore,
    required this.collection,
    required this.fromJson,
  });

  @override
  String get adapterName => 'Firebase';

  @override
  Future<T> pushCreate(T entity) async {
    final docRef = await firestore
        .collection(collection)
        .add(entity.toJson());
    
    final doc = await docRef.get();
    return fromJson({...doc.data()!, 'id': doc.id});
  }

  // ... implement other methods
}
```

## ⚔️ Conflict Resolution

### Built-in Strategies

```dart
// Always keep local version
ConflictResolutionStrategy.localWins

// Always keep remote version  
ConflictResolutionStrategy.remoteWins

// Keep newer version based on timestamp
ConflictResolutionStrategy.newerWins

// Prompt user to choose (requires callback)
ConflictResolutionStrategy.prompt

// Custom merge logic
ConflictResolutionStrategy.merge
```

### Custom Conflict Resolver

```dart
class NoteConflictResolver extends DefaultConflictResolver<Note> {
  NoteConflictResolver() : super(strategy: ConflictResolutionStrategy.prompt);

  @override
  Future<Note> resolve(ConflictEvent<Note> conflictEvent) async {
    // Show UI to user for conflict resolution
    final choice = await showConflictDialog(
      local: conflictEvent.localEntity,
      remote: conflictEvent.remoteEntity,
    );
    
    return choice == 'local' 
        ? conflictEvent.localEntity 
        : conflictEvent.remoteEntity;
  }

  @override
  Future<Note> mergeEntities(Note local, Note remote) async {
    // Custom merge logic
    return Note(
      id: local.id,
      title: '\${local.title} (merged)',
      content: '\${local.content}\\n\\n--- MERGED ---\\n\\n\${remote.content}',
      updatedAt: DateTime.now(),
      version: remote.version + 1,
      isDirty: true,
    );
  }
}
```

## 📊 Sync Policies

```dart
// Real-time sync (aggressive)
const policy = SyncPolicy.realtime; // every 5 minutes, immediate push

// Conservative sync  
const policy = SyncPolicy.conservative; // hourly, manual push

// Custom policy
const policy = SyncPolicy(
  autoSyncInterval: Duration(minutes: 30),
  pushOnEveryLocalChange: false,
  fetchOnStart: true,
  mergeGuestOnUpgrade: true,
  maxRetryAttempts: 5,
  backgroundSyncEnabled: true,
);
```

## 🔍 Monitoring

```dart
// Listen to sync status
syncManager.statusStream.listen((status) {
  print('Online: \${status.isOnline}');
  print('Pending: \${status.pendingCount}');
  print('Conflicts: \${status.conflictCount}');
  print('Last sync: \${status.lastSyncTime}');
});

// Listen to conflicts
syncManager.conflictStream.listen((conflict) {
  print('Conflict detected for \${conflict.entityType}');
  // Handle conflict in UI
});
```

## 🧪 Testing

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/synq_manager.dart';

void main() {
  group('SyncManager Tests', () {
    late SyncManager syncManager;
    late MockLocalStore<Note> mockStore;
    late MockCloudAdapter<Note> mockAdapter;

    setUp(() async {
      mockStore = MockLocalStore<Note>();
      mockAdapter = MockCloudAdapter<Note>();
      
      syncManager = SyncManager(policy: SyncPolicy.conservative);
      await syncManager.initialize(
        stores: [mockStore],
        adapters: {Note: mockAdapter},
      );
    });

    test('should sync dirty entities', () async {
      // Arrange
      final note = Note(/*...*/);
      when(mockStore.getDirtyEntities()).thenAnswer((_) async => [note]);
      
      // Act
      await syncManager.triggerSync();
      
      // Assert
      verify(mockAdapter.pushCreate(note)).called(1);
    });
  });
}
```


## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by offline-first principles
- Built on top of excellent packages like Hive, WorkManager, and Connectivity Plus
- Follows Flutter and Dart community best practices

---

**SynQ Manager** - Making offline-first Flutter apps simple and robust! 🚀