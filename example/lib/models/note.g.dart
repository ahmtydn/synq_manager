// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Note _$NoteFromJson(Map<String, dynamic> json) => Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      color: $enumDecodeNullable(_$NoteColorEnumMap, json['color']) ??
          NoteColor.blue,
      isImportant: json['isImportant'] as bool? ?? false,
    );

Map<String, dynamic> _$NoteToJson(Note instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'color': _$NoteColorEnumMap[instance.color]!,
      'isImportant': instance.isImportant,
    };

const _$NoteColorEnumMap = {
  NoteColor.blue: 'blue',
  NoteColor.green: 'green',
  NoteColor.yellow: 'yellow',
  NoteColor.red: 'red',
  NoteColor.purple: 'purple',
  NoteColor.orange: 'orange',
};
