import 'package:flutter/foundation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

@immutable
class TestEntity implements SyncableEntity {
  const TestEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.value,
    required this.modifiedAt,
    required this.createdAt,
    required this.version,
    this.isDeleted = false,
  });

  factory TestEntity.fromJson(Map<String, dynamic> json) => TestEntity(
        id: json['id'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        value: json['value'] as int,
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        version: json['version'] as int,
        isDeleted: json['isDeleted'] as bool? ?? false,
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
      };

  TestEntity copyWith({
    String? id,
    String? userId,
    String? name,
    int? value,
    DateTime? modifiedAt,
    DateTime? createdAt,
    int? version,
    bool? isDeleted,
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
          version == other.version &&
          isDeleted == other.isDeleted;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      value.hashCode ^
      version.hashCode ^
      isDeleted.hashCode;
}
