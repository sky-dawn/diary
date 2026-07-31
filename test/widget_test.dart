import 'package:diary_app/app/app.dart';
import 'package:diary_app/features/entries/data/diary_repository.dart';
import 'package:diary_app/features/entries/data/sqlite_diary_repository.dart';
import 'package:diary_app/features/entries/models/diary_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home page renders recent entries', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          diaryRepositoryProvider.overrideWithValue(_FakeDiaryRepository()),
        ],
        child: const DiaryApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('\u4eca\u5929\uff0c\u8bb0\u4e00\u7b14'),
      findsOneWidget,
    );
    expect(find.text('\u901a\u52e4\u8def\u4e0a\u7684\u96e8'), findsOneWidget);
  });
}

class _FakeDiaryRepository implements DiaryRepository {
  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<List<DiaryEntry>> fetchEntriesForMonth(DateTime month) async {
    return <DiaryEntry>[];
  }

  @override
  Future<List<DiaryEntry>> fetchRecentEntries({int limit = 20}) async {
    final DateTime now = DateTime.now();
    return <DiaryEntry>[
      DiaryEntry(
        id: 1,
        entryDate: now,
        title: '\u901a\u52e4\u8def\u4e0a\u7684\u96e8',
        content:
            '\u5730\u94c1\u7ad9\u53e3\u7a81\u7136\u4e0b\u8d77\u5927\u96e8\uff0c\u978b\u5b50\u6e7f\u4e86\uff0c\u4f46\u7a7a\u6c14\u5f88\u597d\u3002',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<DiaryEntry?> getEntryById(int id) async {
    return null;
  }

  @override
  Future<int> saveEntry(DiaryEntry entry) async {
    return 1;
  }

  @override
  Future<List<DiaryEntry>> searchEntries(String query) async {
    return <DiaryEntry>[];
  }
}
