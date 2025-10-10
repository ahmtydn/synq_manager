import 'dart:async';

import 'package:flutter/material.dart';
import 'package:synq_manager/synq_manager.dart';
import 'package:synq_manager_example/adapters/memory_local_adapter.dart';
import 'package:synq_manager_example/adapters/memory_remote_adapter.dart';
import 'package:synq_manager_example/models/task.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SynqManager Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late SynqManager<Task> _manager;
  final String _currentUserId = 'user123';
  List<Task> _tasks = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncStatus = 'Not synced';
  int _pendingOperations = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeManager());
  }

  Future<void> _initializeManager() async {
    // Create adapters (using in-memory adapters for demo)
    final localAdapter = MemoryLocalAdapter<Task>(
      fromJson: Task.fromJson,
    );

    final remoteAdapter = MemoryRemoteAdapter<Task>(
      fromJson: Task.fromJson,
    );

    // Initialize manager
    _manager = SynqManager<Task>(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      synqConfig: SynqConfig(
        autoSyncInterval: const Duration(seconds: 30),
        enableLogging: true,
        defaultConflictResolver: LastWriteWinsResolver<Task>(),
      ),
    );

    await _manager.initialize();

    // Listen to events
    _manager.onDataChange.listen((event) {
      print('Data changed: ${event.changeType} - ${event.data.title}');
      unawaited(_loadTasks());
    });

    _manager.onSyncProgress.listen((event) {
      setState(() {
        _syncStatus = 'Syncing: ${event.completed}/${event.total}';
      });
    });

    _manager.onConflict.listen((event) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conflict detected: ${event.context.type}'),
          backgroundColor: Colors.orange,
        ),
      );
    });

    // Start auto-sync
    _manager.startAutoSync(_currentUserId);

    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await _manager.getAll(_currentUserId);
    final snapshot = await _manager.getSyncSnapshot(_currentUserId);

    setState(() {
      _tasks = tasks.where((t) => !t.isDeleted).toList()
        ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      _isLoading = false;
      _pendingOperations = snapshot.pendingOperations;
      if (snapshot.status == SyncStatus.idle) {
        _syncStatus = 'Synced';
      }
    });
  }

  Future<void> _addTask(String title) async {
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _currentUserId,
      title: title,
      modifiedAt: DateTime.now(),
      createdAt: DateTime.now(),
      version: 1,
    );

    await _manager.save(task, _currentUserId);
    await _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(
      completed: !task.completed,
      modifiedAt: DateTime.now(),
      version: task.version + 1,
    );

    await _manager.save(updated, _currentUserId);
    await _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    await _manager.delete(task.id, _currentUserId);
    await _loadTasks();
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Syncing...';
    });

    try {
      final result = await _manager.sync(_currentUserId);
      setState(() {
        _syncStatus =
            'Synced: ${result.syncedCount} items, ${result.failedCount} failed';
      });

      if (result.failedCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.failedCount} items failed to sync'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on Exception catch (e) {
      setState(() {
        _syncStatus = 'Sync failed: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
      await _loadTasks();
    }
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Task'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Task title',
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                unawaited(_addTask(value));
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  unawaited(_addTask(controller.text));
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manager.stopAutoSync(userId: _currentUserId);
    unawaited(_manager.dispose());
    super.dispose();
  }

  Future<void> _printAllData() async {
    print('=== 🔍 DEBUG: ALL DATA ===');
    print('Current User ID: $_currentUserId');
    print('Total Tasks: ${_tasks.length}');
    print('Pending Operations: $_pendingOperations');
    print('Sync Status: $_syncStatus');
    print('\n--- Tasks ---');
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      print('[$i] Task:');
      print('  ID: ${task.id}');
      print('  Title: ${task.title}');
      print('  Completed: ${task.completed}');
      print('  User ID: ${task.userId}');
      print('  Version: ${task.version}');
      print('  Created: ${task.createdAt}');
      print('  Modified: ${task.modifiedAt}');
      print('  Deleted: ${task.isDeleted}');
      print('  JSON: ${task.toJson()}');
      print('');
    }

    // Get all tasks including deleted
    final allTasks = await _manager.getAll(_currentUserId);
    final deletedTasks = allTasks.where((t) => t.isDeleted).toList();
    if (deletedTasks.isNotEmpty) {
      print('--- Deleted Tasks (${deletedTasks.length}) ---');
      for (final task in deletedTasks) {
        print('  ${task.id}: ${task.title}');
      }
    }

    // Get sync snapshot
    final snapshot = await _manager.getSyncSnapshot(_currentUserId);
    print('\n--- Sync Snapshot ---');
    print('  User ID: ${snapshot.userId}');
    print('  Status: ${snapshot.status}');
    print('  Progress: ${snapshot.progress}');
    print('  Pending Operations: ${snapshot.pendingOperations}');
    print('  Completed Operations: ${snapshot.completedOperations}');
    print('  Failed Operations: ${snapshot.failedOperations}');
    print('  Last Started: ${snapshot.lastStartedAt}');
    print('  Last Completed: ${snapshot.lastCompletedAt}');
    print('  Has Unsynced Data: ${snapshot.hasUnsyncedData}');
    print('  Has Failures: ${snapshot.hasFailures}');

    print('=== END DEBUG ===\n');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 All data printed to console'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SynqManager Tasks'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _printAllData,
            tooltip: 'Print all data',
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncNow,
            tooltip: 'Sync now',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[200],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _pendingOperations > 0
                                ? Icons.cloud_upload
                                : Icons.cloud_done,
                            size: 16,
                            color: _pendingOperations > 0
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _syncStatus,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      if (_pendingOperations > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_pendingOperations pending',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Task list
                Expanded(
                  child: _tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to add your first task',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return Dismissible(
                              key: Key(task.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _deleteTask(task),
                              child: ListTile(
                                leading: Checkbox(
                                  value: task.completed,
                                  onChanged: (_) => _toggleTask(task),
                                ),
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    decoration: task.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.completed ? Colors.grey : null,
                                  ),
                                ),
                                subtitle: Text(
                                  'Modified: ${_formatDate(task.modifiedAt)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteTask(task),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}
