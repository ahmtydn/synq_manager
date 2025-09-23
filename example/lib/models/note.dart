import 'package:json_annotation/json_annotation.dart';

part 'note.g.dart';

/// A simple note model to demonstrate SynqManager functionality
@JsonSerializable()
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.color = NoteColor.blue,
    this.isImportant = false,
  });

  /// Creates a Note from JSON
  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  /// The unique identifier for this note
  final String id;

  /// The title of the note
  final String title;

  /// The content/body of the note
  final String content;

  /// When this note was created
  final DateTime createdAt;

  /// When this note was last updated (null if never updated)
  final DateTime? updatedAt;

  /// The color theme for this note
  final NoteColor color;

  /// Whether this note is marked as important
  final bool isImportant;

  /// Converts this Note to JSON
  Map<String, dynamic> toJson() => _$NoteToJson(this);

  /// Creates a copy of this note with updated values
  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    NoteColor? color,
    bool? isImportant,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      isImportant: isImportant ?? this.isImportant,
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, content: $content, '
        'createdAt: $createdAt, updatedAt: $updatedAt, '
        'color: $color, isImportant: $isImportant)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.color == color &&
        other.isImportant == isImportant;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      content,
      createdAt,
      updatedAt,
      color,
      isImportant,
    );
  }
}

/// Available colors for notes
enum NoteColor {
  @JsonValue('blue')
  blue,
  @JsonValue('green')
  green,
  @JsonValue('yellow')
  yellow,
  @JsonValue('red')
  red,
  @JsonValue('purple')
  purple,
  @JsonValue('orange')
  orange,
}
