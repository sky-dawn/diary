import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/media_store.dart';
import '../../../core/utils/date_formats.dart';
import '../models/diary_entry.dart';
import '../models/diary_photo.dart';
import 'diary_repository.dart';

final Provider<AppDatabase> appDatabaseProvider =
    Provider<AppDatabase>((Ref ref) => AppDatabase());

final Provider<MediaStore> mediaStoreProvider =
    Provider<MediaStore>((Ref ref) => MediaStore());

final Provider<DiaryRepository> diaryRepositoryProvider =
    Provider<DiaryRepository>((Ref ref) {
  return SqliteDiaryRepository(
    database: ref.watch(appDatabaseProvider),
    mediaStore: ref.watch(mediaStoreProvider),
  );
});

class SqliteDiaryRepository implements DiaryRepository {
  SqliteDiaryRepository({
    required AppDatabase database,
    required MediaStore mediaStore,
  })  : _database = database,
        _mediaStore = mediaStore;

  final AppDatabase _database;
  final MediaStore _mediaStore;

  @override
  Future<List<DiaryEntry>> fetchRecentEntries({int limit = 20}) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'entries',
      where: 'deleted_at IS NULL',
      orderBy: 'entry_date DESC, updated_at DESC',
      limit: limit,
    );
    return _hydrateEntries(rows);
  }

  @override
  Future<List<DiaryEntry>> fetchEntriesForMonth(DateTime month) async {
    final Database db = await _database.database;
    final DateTime start = DateTime(month.year, month.month);
    final DateTime next = DateTime(month.year, month.month + 1);
    final List<Map<String, Object?>> rows = await db.query(
      'entries',
      where: 'deleted_at IS NULL AND entry_date >= ? AND entry_date < ?',
      whereArgs: <Object>[storageDate(start), storageDate(next)],
      orderBy: 'entry_date DESC, updated_at DESC',
    );
    return _hydrateEntries(rows);
  }

  @override
  Future<List<DiaryEntry>> searchEntries(String query) async {
    final String keyword = query.trim();
    if (keyword.isEmpty) {
      return <DiaryEntry>[];
    }

    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'entries',
      where: 'deleted_at IS NULL AND (title LIKE ? OR content LIKE ?)',
      whereArgs: <Object>['%$keyword%', '%$keyword%'],
      orderBy: 'entry_date DESC, updated_at DESC',
    );
    return _hydrateEntries(rows);
  }

  @override
  Future<DiaryEntry?> getEntryById(int id) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'entries',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final List<DiaryEntry> entries = await _hydrateEntries(rows);
    return entries.firstOrNull;
  }

  @override
  Future<int> saveEntry(DiaryEntry entry) async {
    final Database db = await _database.database;
    final DateTime now = DateTime.now().toUtc();
    final Map<String, Object?> row = <String, Object?>{
      'entry_date': storageDate(entry.entryDate),
      'title': entry.title.trim(),
      'content': entry.content.trim(),
      'mood': entry.mood,
      'weather': entry.weather,
      'updated_at': now.toIso8601String(),
      'deleted_at': entry.deletedAt?.toUtc().toIso8601String(),
    };

    late final int entryId;

    await db.transaction((Transaction txn) async {
      if (entry.id == null) {
        row['created_at'] = now.toIso8601String();
        entryId = await txn.insert('entries', row);
      } else {
        await txn.update(
          'entries',
          row,
          where: 'id = ?',
          whereArgs: <Object>[entry.id!],
        );
        await txn.delete(
          'photos',
          where: 'entry_id = ?',
          whereArgs: <Object>[entry.id!],
        );
        entryId = entry.id!;
      }

      for (int index = 0; index < entry.photos.length; index++) {
        final DiaryPhoto photo = entry.photos[index];
        await txn.insert(
          'photos',
          <String, Object?>{
            'entry_id': entryId,
            'local_path': photo.localPath,
            'thumb_path': photo.thumbPath,
            'width': photo.width,
            'height': photo.height,
            'taken_at': photo.takenAt?.toUtc().toIso8601String(),
            'sort_order': index,
            'created_at': photo.createdAt.toUtc().toIso8601String(),
          },
        );
      }
    });

    return entryId;
  }

  @override
  Future<void> deleteEntry(int id) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> photoRows = await db.query(
      'photos',
      columns: <String>['local_path', 'thumb_path'],
      where: 'entry_id = ?',
      whereArgs: <Object>[id],
    );

    await db.delete(
      'entries',
      where: 'id = ?',
      whereArgs: <Object>[id],
    );

    for (final Map<String, Object?> row in photoRows) {
      await _mediaStore.deletePhoto(row['local_path'] as String?);
      await _mediaStore.deletePhoto(row['thumb_path'] as String?);
    }
  }

  Future<List<DiaryEntry>> _hydrateEntries(
      List<Map<String, Object?>> entryRows) async {
    if (entryRows.isEmpty) {
      return <DiaryEntry>[];
    }

    final Database db = await _database.database;
    final List<int> ids = entryRows
        .map((Map<String, Object?> row) => row['id'] as int)
        .toList(growable: false);
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<Map<String, Object?>> photoRows = await db.query(
      'photos',
      where: 'entry_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'entry_id ASC, sort_order ASC',
    );

    final Map<int, List<DiaryPhoto>> photosByEntry = <int, List<DiaryPhoto>>{};
    for (final Map<String, Object?> row in photoRows) {
      final int entryId = row['entry_id'] as int;
      final List<DiaryPhoto> photos =
          photosByEntry.putIfAbsent(entryId, () => <DiaryPhoto>[]);
      photos.add(
        DiaryPhoto(
          id: row['id'] as int,
          localPath: row['local_path'] as String,
          thumbPath: row['thumb_path'] as String?,
          width: row['width'] as int?,
          height: row['height'] as int?,
          takenAt: _parseDateTime(row['taken_at'] as String?),
          sortOrder: row['sort_order'] as int? ?? 0,
          createdAt: _parseDateTime(row['created_at'] as String)!,
        ),
      );
    }

    return entryRows.map((Map<String, Object?> row) {
      final int id = row['id'] as int;
      return DiaryEntry(
        id: id,
        entryDate: DateTime.parse(row['entry_date'] as String),
        title: row['title'] as String? ?? '',
        content: row['content'] as String? ?? '',
        mood: row['mood'] as String?,
        weather: row['weather'] as String?,
        photos: photosByEntry[id] ?? const <DiaryPhoto>[],
        createdAt: _parseDateTime(row['created_at'] as String)!,
        updatedAt: _parseDateTime(row['updated_at'] as String)!,
        deletedAt: _parseDateTime(row['deleted_at'] as String?),
      );
    }).toList(growable: false);
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value).toLocal();
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
