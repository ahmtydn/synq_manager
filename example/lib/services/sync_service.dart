import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:synq_manager/synq_manager.dart';
import 'package:synq_manager_example/models/note.dart';
import 'package:uuid/uuid.dart';

/// Service that manages sync operations and provides a simplified API
class SyncService extends ChangeNotifier {
  SyncService() : _uuid = const Uuid();

  final Uuid _uuid;
  late SyncManager _syncManager;
  late HiveLocalStore<Note> _notesStore;
  late OfflineAuthProvider _authProvider;

  bool _isInitialized = false;
  List<Note> _notes = [];
  SyncSystemStatus? _syncStatus;
  AuthState? _authState;

  bool get isInitialized => _isInitialized;
  List<Note> get notes => _notes;
  SyncSystemStatus? get syncStatus => _syncStatus;
  AuthState? get authState => _authState;

  Stream<AuthState> get authStateChanges => _authProvider.authStateChanges;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize auth provider
      _authProvider = OfflineAuthProvider();
      await _authProvider.initialize();

      // Initialize local store for notes
      _notesStore = HiveLocalStore<Note>(
        boxName: 'notes',
        adapter: Note.fromJson,
      );

      // Create sync manager
      _syncManager = SyncManager(
        policy: SyncPolicy.realtime,
      );

      // Initialize sync manager
      await _syncManager.initialize(
        stores: [_notesStore],
        adapters: {
          Note: DemoCloudAdapter<Note>(),
        },
        authProvider: _authProvider,
        conflictResolvers: {
          Note: NoteConflictResolver(),
        },
      );

      // Listen to changes
      _notesStore.watchAll().listen((notes) {
        _notes = notes;
        notifyListeners();
      });

      _syncManager.statusStream.listen((status) {
        _syncStatus = status;
        notifyListeners();
      });

      _authProvider.authStateChanges.listen((authState) {
        _authState = authState;
        notifyListeners();
      });

      // Load initial notes
      _notes = await _notesStore.getAll();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize SyncService: $e');
    }
  }

  /// Login with email and password
  Future<void> login(String email, String password) async {
    await _authProvider.login(email, password);
  }

  /// Login as guest
  Future<void> loginAsGuest() async {
    await _authProvider.loginAsGuest();
  }

  /// Logout
  Future<void> logout() async {
    await _authProvider.logout();
  }

  /// Create a new note
  Future<void> createNote(String title, String content, {int? color}) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      color: color ?? 0xFFFFFFFF,
      updatedAt: DateTime.now(),
      isDirty: true,
    );

    await _notesStore.save(note);

    // Trigger sync if policy allows
    if (_syncManager.policy.pushOnEveryLocalChange) {
      _syncManager.triggerSync();
    }
  }

  /// Update an existing note
  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    int? color,
  }) async {
    final existingNote = await _notesStore.get(id);
    if (existingNote == null) return;

    final updatedNote = existingNote.copyWith(
      title: title,
      content: content,
      color: color,
      updatedAt: DateTime.now(),
      isDirty: true,
    );

    await _notesStore.save(updatedNote);

    // Trigger sync if policy allows
    if (_syncManager.policy.pushOnEveryLocalChange) {
      _syncManager.triggerSync();
    }
  }

  /// Delete a note
  Future<void> deleteNote(String id) async {
    final existingNote = await _notesStore.get(id);
    if (existingNote == null) return;

    final deletedNote = existingNote.markAsDeleted() as Note;
    await _notesStore.save(deletedNote);

    // Trigger sync if policy allows
    if (_syncManager.policy.pushOnEveryLocalChange) {
      _syncManager.triggerSync();
    }
  }

  /// Manually trigger sync
  Future<void> sync() async {
    await _syncManager.triggerSync();
  }

  /// Watch all notes as a stream
  Stream<List<Note>> watchNotes() => _notesStore.watchAll();

  @override
  void dispose() {
    if (_isInitialized) {
      _syncManager.shutdown();
    }
    super.dispose();
  }
}

/// Demo cloud adapter that simulates network operations
class DemoCloudAdapter<T extends SyncEntity> implements CloudAdapter<T> {
  final Map<String, T> _storage = {};

  @override
  String get adapterName => 'Demo';

  @override
  Future<void> initialize() async {
    // Simulate initialization delay
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<T> pushCreate(T entity) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final updatedEntity = entity.copyWithSyncData(
      version: 1,
      isDirty: false,
    ) as T;

    _storage[entity.id] = updatedEntity;
    return updatedEntity;
  }

  @override
  Future<T> pushUpdate(T entity) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final updatedEntity = entity.copyWithSyncData(
      version: entity.version + 1,
      isDirty: false,
    ) as T;

    _storage[entity.id] = updatedEntity;
    return updatedEntity;
  }

  @override
  Future<void> pushDelete(String id, {int? version}) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _storage.remove(id);
  }

  @override
  Future<List<T>> fetchAll() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _storage.values.toList();
  }

  @override
  Future<List<T>> fetchSince(DateTime since) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _storage.values
        .where((entity) => entity.updatedAt.isAfter(since))
        .toList();
  }

  @override
  Future<T?> fetchById(String id) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _storage[id];
  }

  @override
  Future<List<T>> pushBatch(List<T> entities) async {
    final results = <T>[];
    for (final entity in entities) {
      if (entity.version == 0) {
        results.add(await pushCreate(entity));
      } else {
        results.add(await pushUpdate(entity));
      }
    }
    return results;
  }

  @override
  bool get supportsBatchOperations => true;

  @override
  bool get supportsRealTimeUpdates => false;

  @override
  Stream<T>? subscribeToUpdates() => null;

  @override
  Future<bool> testConnection() async {
    return true;
  }

  @override
  Future<void> dispose() async {}
}

/// Conflict resolver for notes that prefers newer content
class NoteConflictResolver extends DefaultConflictResolver<Note> {
  NoteConflictResolver()
      : super(strategy: ConflictResolutionStrategy.newerWins);

  @override
  Future<Note> mergeEntities(Note local, Note remote) async {
    // Custom merge logic: combine titles and content
    return Note(
      id: local.id,
      title: '${local.title} (merged with ${remote.title})',
      content: '${local.content}\\n\\n--- MERGED ---\\n\\n${remote.content}',
      color: local.color,
      updatedAt: DateTime.now(),
      version: remote.version + 1,
      isDeleted: local.isDeleted || remote.isDeleted,
      isDirty: true,
    );
  }
}
