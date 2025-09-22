import 'package:synq_manager/synq_manager.dart';

/// Example Note model that implements SyncCacheModel
class Note extends SyncCacheModel {
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.version = 0,
    this.isDeleted = false,
    this.isDirty = false,
    this.guestId,
    this.color = 0xFFFFFFFF,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      color: json['color'] as int? ?? 0xFFFFFFFF,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isDirty: json['isDirty'] as bool? ?? false,
      guestId: json['guestId'] as String?,
    );
  }

  @override
  final String id;

  final String title;
  final String content;
  final int color;

  @override
  final DateTime updatedAt;

  @override
  final int version;

  @override
  final bool isDeleted;

  @override
  final bool isDirty;

  @override
  final String? guestId;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'color': color,
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
      'isDeleted': isDeleted,
      'isDirty': isDirty,
      'guestId': guestId,
    };
  }

  @override
  Note fromJson(dynamic json) {
    return Note.fromJson(json as Map<String, dynamic>);
  }

  @override
  SyncCacheModel copyWithSyncData({
    DateTime? updatedAt,
    int? version,
    bool? isDeleted,
    bool? isDirty,
    String? guestId,
  }) {
    return Note(
      id: id,
      title: title,
      content: content,
      color: color,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      isDirty: isDirty ?? this.isDirty,
      guestId: guestId ?? this.guestId,
    );
  }

  /// Create a copy with updated fields
  Note copyWith({
    String? title,
    String? content,
    int? color,
    DateTime? updatedAt,
    int? version,
    bool? isDeleted,
    bool? isDirty,
    String? guestId,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      isDirty: isDirty ?? this.isDirty,
      guestId: guestId ?? this.guestId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(id, title, content, version);
}
