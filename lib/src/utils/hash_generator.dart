import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Utility for generating consistent hashes representing sync state.
class HashGenerator {
  /// Creates a hash generator.
  const HashGenerator();

  /// Generates a hash from a list of entities.
  String hashEntities<T extends SyncableEntity>(List<T> entities) {
    final sorted = List<T>.from(entities)..sort((a, b) => a.id.compareTo(b.id));
    final jsonList = sorted.map((e) => e.toMap()).toList();
    return _hashJson(jsonList);
  }

  /// Generates a hash from metadata.
  String hashMetadata(Map<String, dynamic> metadata) => _hashJson(metadata);

  String _hashJson(Object data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    return sha256.convert(bytes).toString();
  }
}
