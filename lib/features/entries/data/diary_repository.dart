import '../models/diary_entry.dart';

abstract class DiaryRepository {
  Future<List<DiaryEntry>> fetchRecentEntries({int limit = 20});
  Future<List<DiaryEntry>> fetchEntriesForMonth(DateTime month);
  Future<List<DiaryEntry>> searchEntries(String query);
  Future<DiaryEntry?> getEntryById(int id);
  Future<int> saveEntry(DiaryEntry entry);
  Future<void> deleteEntry(int id);
}
