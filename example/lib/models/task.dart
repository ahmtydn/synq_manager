import 'package:flutter/foundation.dart';
import 'package:synq_manager/synq_manager.dart';

@immutable
class Task implements SyncableEntity {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.modifiedAt,
    required this.createdAt,
    required this.version,
    this.completed = false,
    this.isDeleted = false,
  });

  @override
  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        userId: json['userId'] as String,
        title: json['title'] as String,
        completed: json['completed'] as bool? ?? false,
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        version: json['version'] as int,
        isDeleted: json['isDeleted'] as bool? ?? false,
      );

  @override
  final String id;

  @override
  final String userId;

  final String title;
  final bool completed;

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
        'title': title,
        'completed': completed,
        'modifiedAt': modifiedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'version': version,
        'isDeleted': isDeleted,
      };

  Task copyWith({
    String? userId,
    DateTime? modifiedAt,
    int? version,
    bool? isDeleted,
    String? title,
    bool? completed,
  }) =>
      Task(
        id: id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        createdAt: createdAt,
        version: version ?? this.version,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          completed == other.completed &&
          version == other.version &&
          isDeleted == other.isDeleted;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      title.hashCode ^
      completed.hashCode ^
      version.hashCode ^
      isDeleted.hashCode;

  @override
  String toString() =>
      'Task(id: $id, title: $title, completed: $completed, version: $version)';
}
