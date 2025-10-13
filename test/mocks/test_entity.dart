import 'package:flutter/foundation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// A mock entity for testing purposes.
@immutable
class TestEntity implements SyncableEntity {
  /// Creates a [TestEntity].
  const TestEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.value,
    required this.modifiedAt,
    required this.createdAt,
    required this.version,
    this.isDeleted = false,
    this.completed = false,
  });

  factory TestEntity.fromJson(Map<String, dynamic> json) => TestEntity(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? json['title'] as String? ?? '',
        value: json['value'] as int? ?? 0,
        modifiedAt: DateTime.tryParse(json['modifiedAt'] as String? ?? '') ??
            DateTime(0),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime(0),
        version: json['version'] as int? ?? 1,
        isDeleted: json['isDeleted'] as bool? ?? false,
        completed: json['completed'] as bool? ?? false,
      );

  /// Creates a new [TestEntity] with default values for testing.
  factory TestEntity.create(
    String id,
    String userId,
    String name,
  ) =>
      TestEntity(
        id: id,
        userId: userId,
        name: name,
        value: 0,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
  @override
  final String id;

  @override
  final String userId;

  final String name;
  final int value;

  @override
  final DateTime modifiedAt;

  @override
  final DateTime createdAt;

  @override
  final int version;

  @override
  final bool isDeleted;

  /// A custom field for testing queries.
  final bool completed;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'value': value,
        'modifiedAt': modifiedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'version': version,
        'isDeleted': isDeleted,
        'completed': completed,
      };

  @override
  TestEntity copyWith({
    String? id,
    String? userId,
    String? name,
    int? value,
    DateTime? modifiedAt,
    DateTime? createdAt,
    int? version,
    bool? isDeleted,
    bool? completed,
  }) =>
      TestEntity(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        value: value ?? this.value,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        createdAt: createdAt ?? this.createdAt,
        version: version ?? this.version,
        isDeleted: isDeleted ?? this.isDeleted,
        completed: completed ?? this.completed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          value == other.value &&
          modifiedAt == other.modifiedAt &&
          createdAt == other.createdAt &&
          version == other.version &&
          isDeleted == other.isDeleted &&
          completed == other.completed;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      value.hashCode ^
      modifiedAt.hashCode ^
      createdAt.hashCode ^
      version.hashCode ^
      isDeleted.hashCode ^
      completed.hashCode;

  @override
  Map<String, dynamic>? diff(SyncableEntity oldVersion) {
    if (oldVersion is! TestEntity) {
      // If types don't match, return the full object as a "diff"
      return toJson()
        ..remove('id')
        ..remove('userId');
    }

    final diffMap = <String, dynamic>{};

    if (name != oldVersion.name) diffMap['name'] = name;
    if (value != oldVersion.value) diffMap['value'] = value;
    if (completed != oldVersion.completed) diffMap['completed'] = completed;

    return diffMap.isEmpty ? null : diffMap;
  }
}
