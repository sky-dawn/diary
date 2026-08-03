import 'dart:convert';

import 'diary_photo.dart';

class DiaryEntry {
  const DiaryEntry({
    this.id,
    required this.entryDate,
    required this.title,
    required this.content,
    this.mood,
    this.weather,
    this.photos = const <DiaryPhoto>[],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final DateTime entryDate;
  final String title;
  final String content;
  final String? mood;
  final String? weather;
  final List<DiaryPhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get preview {
    final String text = deltaToPlainText(content);
    if (text.isEmpty) {
      if (photos.isNotEmpty) {
        return '\u8fd9\u4e00\u5929\u4e3b\u8981\u9760\u7167\u7247\u6765\u8bb0\u5f55\u3002';
      }
      return '\u7a7a\u5185\u5bb9';
    }
    return text.length > 72 ? '${text.substring(0, 72)}...' : text;
  }

  static String deltaToPlainText(String deltaJson) {
    if (deltaJson.isEmpty) {
      return '';
    }

    try {
      final List<dynamic> ops = jsonDecode(deltaJson) as List<dynamic>;
      final StringBuffer buffer = StringBuffer();
      for (final dynamic op in ops) {
        if (op is Map<String, dynamic>) {
          final dynamic insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }
      return buffer.toString().replaceAll('\n', ' ').trim();
    } catch (_) {
      final String normalized = deltaJson.replaceAll('\n', ' ').trim();
      return normalized;
    }
  }

  DiaryEntry copyWith({
    int? id,
    DateTime? entryDate,
    String? title,
    String? content,
    String? mood,
    String? weather,
    List<DiaryPhoto>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      weather: weather ?? this.weather,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static DiaryEntry draft({DateTime? entryDate}) {
    final DateTime now = DateTime.now();
    return DiaryEntry(
      entryDate: entryDate ?? now,
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
    );
  }
}
