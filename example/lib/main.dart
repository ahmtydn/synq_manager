import 'dart:async';

import 'package:flutter/material.dart';
import 'package:synq_manager/synq_manager.dart';
import 'package:uuid/uuid.dart';

import 'models/note.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SynqManager Notes Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const NotesScreen(),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  SynqManager<Note>? _synqManager;
  List<Note> _notes = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _status = 'Initializing...';
  final Uuid _uuid = const Uuid();
  StreamSubscription<SynqEvent<Note>>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSynqManager();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSynqManager() async {
    try {
      setState(() {
        _status = 'Starting SynqManager...';
      });

      _synqManager = await SynqManager.getInstance<Note>(
        instanceName: 'notes_manager',
        config: const SyncConfig(
          syncInterval: Duration(seconds: 30),
          encryptionKey: 'example_encryption_key_32_chars!',
          enableBackgroundSync: true,
          enableConflictResolution: true,
        ),
        cloudSyncFunction: _mockCloudSync,
        cloudFetchFunction: _mockCloudFetch,
        fromJson: Note.fromJson,
        toJson: (note) => note.toJson(),
      );

      // Sadeleştirilmiş Socket.io style event listening
      final listeners = _synqManager!.on();
      listeners
        ..onInit((data) {
          // Initial data loaded
          debugPrint('📥 Initial data loaded: ${data.length} items');
          _refreshNotesFromData(data);
        })
        ..onCreate((key, data) {
          // New data created
          debugPrint('✨ Data created: $key');
          _loadNotes();
        })
        ..onUpdate((key, data) {
          // Data updated
          debugPrint('📝 Data updated: $key');
          _loadNotes();
        })
        ..onDelete((key) {
          // Data deleted
          debugPrint('🗑️ Data deleted: $key');
          _loadNotes();
        })
        ..onError((error) {
          setState(() {
            _isSyncing = false;
            _status = 'Error: $error';
          });
        })
        ..onEvent((event) {
          debugPrint('📊 Event: ${event.type} for key: ${event.key}');

          switch (event.type) {
            case SynqEventType.syncStart:
              setState(() {
                _isSyncing = true;
                _status = 'Synchronization started...';
              });
              break;
            case SynqEventType.syncComplete:
              setState(() {
                _isSyncing = false;
                _status = 'Synchronization completed';
              });
              break;
            default:
              break;
          }
        });

      setState(() {
        _isLoading = false;
        _status = 'Ready';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  void _refreshNotesFromData(Map<String, Note> data) {
    final notes = data.values.toList();
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _notes = notes;
    });
  }

  Future<void> _loadNotes() async {
    if (_synqManager == null) return;

    try {
      final notesData = await _synqManager!.getAll();
      _refreshNotesFromData(notesData);
    } catch (e) {
      setState(() {
        _status = 'Note loading error: $e';
      });
    }
  }

  // Mock cloud sync function - simulates sending data to a cloud service
  Future<SyncResult<Note>> _mockCloudSync(
    Map<String, SyncData<Note>> localChanges,
    Map<String, String> headers,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // In a real app, this would send data to your backend
    debugPrint('📤 Cloud sync: ${localChanges.length} changes');

    // Simulate occasional network errors
    if (DateTime.now().millisecond % 20 == 0) {
      throw Exception('Simulated network error');
    }

    // Return successful sync result
    return const SyncResult<Note>(
      success: true,
      remoteData: {},
      conflicts: [],
    );
  }

  // Mock cloud fetch function - simulates fetching data from a cloud service
  Future<CloudFetchResponse<Note>> _mockCloudFetch(
    int lastSyncTimestamp,
    Map<String, String> headers,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // In a real app, this would fetch data from your backend
    debugPrint('📥 Cloud fetch: lastSync=$lastSyncTimestamp');

    // Return empty data for demo (in real app, return actual cloud data)
    return const CloudFetchResponse<Note>(
      data: {},
      cloudUserId: 'demo_user_123',
    );
  }

  Future<void> _addNote() async {
    if (_synqManager == null) return;

    final note = Note(
      id: _uuid.v4(),
      title: 'New Note',
      content: 'Note content goes here...',
      createdAt: DateTime.now(),
      color: NoteColor.values[_notes.length % NoteColor.values.length],
    );

    try {
      await _synqManager!.put(note.id, note);
      setState(() {
        _status = 'Note added';
      });
    } catch (e) {
      setState(() {
        _status = 'Note add error: $e';
      });
    }
  }

  Future<void> _editNote(Note note) async {
    final result = await showDialog<Note>(
      context: context,
      builder: (context) => NoteEditDialog(note: note),
    );

    if (result != null && _synqManager != null) {
      try {
        final updatedNote = result.copyWith(updatedAt: DateTime.now());
        await _synqManager!.update(updatedNote.id, updatedNote);
        setState(() {
          _status = 'Note updated';
        });
      } catch (e) {
        setState(() {
          _status = 'Note update error: $e';
        });
      }
    }
  }

  Future<void> _deleteNote(Note note) async {
    if (_synqManager == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content:
            Text('Are you sure you want to delete the note "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _synqManager!.delete(note.id);
        setState(() {
          _status = 'Note deleted';
        });
      } catch (e) {
        setState(() {
          _status = 'Note delete error: $e';
        });
      }
    }
  }

  Future<void> _manualSync() async {
    if (_synqManager == null || _isSyncing) return;

    try {
      await _synqManager!.sync();
    } catch (e) {
      setState(() {
        _status = 'Manual synchronization error: $e';
      });
    }
  }

  Color _getNoteColor(NoteColor color) {
    switch (color) {
      case NoteColor.blue:
        return Colors.blue.shade100;
      case NoteColor.green:
        return Colors.green.shade100;
      case NoteColor.yellow:
        return Colors.yellow.shade100;
      case NoteColor.red:
        return Colors.red.shade100;
      case NoteColor.purple:
        return Colors.purple.shade100;
      case NoteColor.orange:
        return Colors.orange.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SynqManager Notes Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _manualSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Manual Synchronization',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                Icon(
                  _synqManager?.isReady == true
                      ? Icons.check_circle
                      : Icons.error,
                  color:
                      _synqManager?.isReady == true ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_status, style: const TextStyle(fontSize: 12))),
                Text('${_notes.length} notes',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          // Notes list
          Expanded(
            child: _notes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_add, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No notes yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Tap the + button to add a new note'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return Card(
                        color: _getNoteColor(note.color),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: note.isImportant
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created: ${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          leading: note.isImportant
                              ? const Icon(Icons.star, color: Colors.orange)
                              : null,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _editNote(note);
                                  break;
                                case 'delete':
                                  _deleteNote(note);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _editNote(note),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        tooltip: 'Add New Note',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteEditDialog extends StatefulWidget {
  const NoteEditDialog({super.key, required this.note});

  final Note note;

  @override
  State<NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<NoteEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late NoteColor _selectedColor;
  late bool _isImportant;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _selectedColor = widget.note.color;
    _isImportant = widget.note.isImportant;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Color: '),
                ...NoteColor.values.map((color) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _getNoteColor(color),
                          border: Border.all(
                            color: _selectedColor == color
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Important'),
              value: _isImportant,
              onChanged: (value) =>
                  setState(() => _isImportant = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final updatedNote = widget.note.copyWith(
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              color: _selectedColor,
              isImportant: _isImportant,
            );
            Navigator.pop(context, updatedNote);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Color _getNoteColor(NoteColor color) {
    switch (color) {
      case NoteColor.blue:
        return Colors.blue.shade300;
      case NoteColor.green:
        return Colors.green.shade300;
      case NoteColor.yellow:
        return Colors.yellow.shade300;
      case NoteColor.red:
        return Colors.red.shade300;
      case NoteColor.purple:
        return Colors.purple.shade300;
      case NoteColor.orange:
        return Colors.orange.shade300;
    }
  }
}
