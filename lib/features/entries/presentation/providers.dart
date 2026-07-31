import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sqlite_diary_repository.dart';
import '../models/diary_entry.dart';

final StateProvider<String> searchQueryProvider =
    StateProvider<String>((Ref ref) => '');

final StateProvider<DateTime> calendarMonthProvider =
    StateProvider<DateTime>((Ref ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month);
});

final FutureProvider<List<DiaryEntry>> recentEntriesProvider =
    FutureProvider<List<DiaryEntry>>((Ref ref) {
  return ref.watch(diaryRepositoryProvider).fetchRecentEntries();
});

final entryByIdProvider =
    FutureProvider.autoDispose.family<DiaryEntry?, int>((Ref ref, int id) {
  return ref.watch(diaryRepositoryProvider).getEntryById(id);
});

final FutureProvider<List<DiaryEntry>> searchResultsProvider =
    FutureProvider<List<DiaryEntry>>((Ref ref) {
  final String query = ref.watch(searchQueryProvider);
  return ref.watch(diaryRepositoryProvider).searchEntries(query);
});

final FutureProvider<List<DiaryEntry>> calendarEntriesProvider =
    FutureProvider<List<DiaryEntry>>((Ref ref) {
  final DateTime month = ref.watch(calendarMonthProvider);
  return ref.watch(diaryRepositoryProvider).fetchEntriesForMonth(month);
});
