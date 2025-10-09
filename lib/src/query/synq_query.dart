import 'dart:async';

import 'package:synq_manager/src/models/syncable_entity.dart';

typedef _Predicate<T> = bool Function(T);
typedef _Selector<T, R extends Comparable<Object?>> = R Function(T);

class SynqQuery<T extends SyncableEntity> {
  SynqQuery({
    required Future<List<T>> Function() fetcher,
    Stream<List<T>> Function()? watcher,
  })  : _fetcher = fetcher,
        _watcher = watcher;

  final Future<List<T>> Function() _fetcher;
  final Stream<List<T>> Function()? _watcher;
  final List<_Predicate<T>> _predicates = [];
  _Selector<T, Comparable<Object?>>? _ordering;
  bool _descending = false;
  int? _limit;
  int _skip = 0;

  SynqQuery<T> where(_Predicate<T> predicate) {
    _predicates.add(predicate);
    return this;
  }

  void orderBy<R extends Comparable<Object?>>(
    _Selector<T, R> selector, {
    bool descending = false,
  }) {
    _ordering = (item) => selector(item);
    _descending = descending;
  }

  void limit(int count) {
    _limit = count;
  }

  void skip(int count) {
    _skip = count;
  }

  Future<List<T>> execute() async {
    var results = await _fetcher();
    for (final predicate in _predicates) {
      results = results.where(predicate).toList();
    }
    if (_ordering != null) {
      results.sort((a, b) {
        final aValue = _ordering!(a);
        final bValue = _ordering!(b);
        final comparison = aValue.compareTo(bValue);
        return _descending ? -comparison : comparison;
      });
    }
    if (_skip > 0) {
      results = results.skip(_skip).toList();
    }
    if (_limit != null) {
      results = results.take(_limit!).toList();
    }
    return results;
  }

  Stream<List<T>> watch() {
    final baseStream = _watcher?.call();
    if (baseStream == null) {
      return Stream.fromFuture(execute());
    }
    return baseStream.asyncMap((_) => execute());
  }
}
