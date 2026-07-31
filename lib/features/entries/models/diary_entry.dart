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
    final String normalized = content.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) {
      return '\u8fd9\u4e00\u5929\u4e3b\u8981\u9760\u7167\u7247\u6765\u8bb0\u5f55\u3002';
    }
    return normalized.length > 72
        ? '${normalized.substring(0, 72)}...'
        : normalized;
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
