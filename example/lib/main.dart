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
  Stream<List<Task>>? _tasksStream;
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncStatus = 'Not synced';
  int _pendingOperations = 0;
  String _currentFilter = 'All';

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
      synqConfig: const SynqConfig(
        autoSyncInterval: Duration(seconds: 30),
        enableLogging: true,
      ),
    );

    await _manager.initialize();

    // Set up the reactive stream for the task list.
    // The UI will now update automatically.
    _setTasksStream();

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

    setState(() {
      _isLoading = false;
    });
    unawaited(_updatePendingOperations());
  }

  Future<void> _updatePendingOperations() async {
    final snapshot = await _manager.getSyncSnapshot(_currentUserId);
    setState(() {
      _pendingOperations = snapshot.pendingOperations;
      if (snapshot.status == SyncStatus.idle) {
        _syncStatus = 'Synced';
      }
    });
  }

  void _setTasksStream() {
    if (_currentFilter == 'Pending') {
      // Use watchQuery to get only incomplete tasks
      const query = SynqQuery({'completed': false});
      setState(() {
        _tasksStream = _manager.watchQuery(query, userId: _currentUserId);
      });
    } else {
      // Use watchAll for all tasks
      setState(() {
        _tasksStream = _manager.watchAll(userId: _currentUserId);
      });
    }
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
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(
      completed: !task.completed,
      modifiedAt: DateTime.now(),
      version: task.version + 1,
    );

    await _manager.save(updated, _currentUserId);
  }

  Future<void> _deleteTask(Task task) async {
    await _manager.delete(task.id, _currentUserId);
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
      await _updatePendingOperations();
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
    print('Pending Operations: $_pendingOperations');
    print('Sync Status: $_syncStatus');
    print('\n--- Tasks ---');

    final tasks = await _manager.getAll(userId: _currentUserId);
    print('Total Tasks: ${tasks.length}');
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
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
    final deletedTasks = tasks.where((t) => t.isDeleted).toList();
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

  Future<void> _navigateToDetail(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            TaskDetailScreen(manager: _manager, taskId: task.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SynqManager Tasks'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (_currentFilter != value) {
                setState(() {
                  _currentFilter = value;
                  _setTasksStream();
                });
              }
            },
            icon: const Icon(Icons.filter_list),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'All',
                child: Text('All Tasks'),
              ),
              const PopupMenuItem<String>(
                value: 'Pending',
                child: Text('Pending Only'),
              ),
            ],
          ),
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
                  child: StreamBuilder<List<Task>>(
                    stream: _tasksStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      final tasks = snapshot.data ?? [];
                      final visibleTasks = tasks
                          .where((t) => !t.isDeleted)
                          .toList()
                        ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

                      if (visibleTasks.isEmpty) {
                        return Center(
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
                        );
                      }

                      return ListView.builder(
                        itemCount: visibleTasks.length,
                        itemBuilder: (context, index) {
                          final task = visibleTasks[index];
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
                              onTap: () => _navigateToDetail(task),
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
}

/// A screen to display details for a single task, demonstrating `watchById`.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    required this.manager,
    required this.taskId,
    super.key,
  });

  final SynqManager<Task> manager;
  final String taskId;
  static const String _currentUserId = 'user123';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
      ),
      body: StreamBuilder<Task?>(
        stream: manager.watchById(taskId, _currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final task = snapshot.data;

          if (task == null) {
            return const Center(
              child: Text(
                'Task not found or has been deleted.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      task.completed
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: task.completed ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.completed ? 'Completed' : 'Pending',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text('ID: ${task.id}'),
                const SizedBox(height: 8),
                Text('Version: ${task.version}'),
                const SizedBox(height: 8),
                Text('Created: ${_formatDate(task.createdAt)}'),
                const SizedBox(height: 8),
                Text('Last Modified: ${_formatDate(task.modifiedAt)}'),
              ],
            ),
          );
        },
      ),
    );
  }
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
