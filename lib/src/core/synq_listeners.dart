import 'dart:async';

import 'package:synq_manager/synq_manager.dart';

/// Socket.io style event listeners for SynqManager
class SynqListeners<T extends DocumentSerializable> {
  SynqListeners(this._manager);
  final SynqManager<T> _manager;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<StreamSubscription<dynamic>> get subscriptions => _subscriptions;

  /// Listen for all events (tüm eventleri dinleyen genel callback)
  SynqListeners<T> onEvent(void Function(SynqEvent<T> event) callback) {
    _subscriptions.add(
      _manager.events.listen(callback),
    );
    return this;
  }

  /// Listen for initialization with all existing data
  SynqListeners<T> onInit(void Function(Map<String, T> data) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.connected).listen((_) async {
        final data = await _manager.getAll();
        callback(data);
      }),
    );
    return this;
  }

  /// Listen for data creation events
  SynqListeners<T> onCreate(void Function(String key, T data) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.create).listen((event) async {
        if (event.data.value != null) {
          callback(event.key, event.data.value!);
        }
      }),
    );
    return this;
  }

  /// Listen for data update events
  SynqListeners<T> onUpdate(void Function(String key, T data) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.update).listen((event) async {
        if (event.data.value != null) {
          callback(event.key, event.data.value!);
        }
      }),
    );
    return this;
  }

  /// Listen for data delete events
  SynqListeners<T> onDelete(void Function(String key) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.delete).listen((event) {
        callback(event.key);
      }),
    );
    return this;
  }

  /// Listen for error events
  SynqListeners<T> onError(void Function(Object error) callback) {
    _subscriptions.add(
      _manager.onError
          .listen((event) => callback(event.error ?? 'Unknown error')),
    );
    return this;
  }

  /// Cancel all event listeners
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
