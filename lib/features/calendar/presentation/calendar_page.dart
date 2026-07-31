import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/empty_state.dart';
import '../../entries/models/diary_entry.dart';
import '../../entries/presentation/providers.dart';
import '../../entries/presentation/widgets/entry_card.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  static const List<String> _weekdays = <String>[
    '\u4e00',
    '\u4e8c',
    '\u4e09',
    '\u56db',
    '\u4e94',
    '\u516d',
    '\u65e5',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime month = ref.watch(calendarMonthProvider);
    final AsyncValue<List<DiaryEntry>> entriesAsync =
        ref.watch(calendarEntriesProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () {
                  ref.read(calendarMonthProvider.notifier).state =
                      DateTime(month.year, month.month - 1);
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  formatMonthLabel(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(calendarMonthProvider.notifier).state =
                      DateTime(month.year, month.month + 1);
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: entriesAsync.when(
                data: (List<DiaryEntry> entries) {
                  final Map<DateTime, int> countByDay = <DateTime, int>{};
                  for (final DiaryEntry entry in entries) {
                    final DateTime day = normalizeDate(entry.entryDate);
                    countByDay.update(day, (int value) => value + 1,
                        ifAbsent: () => 1);
                  }

                  return Column(
                    children: <Widget>[
                      Row(
                        children: _weekdays
                            .map(
                              (String day) => Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 14),
                      _MonthGrid(
                        month: month,
                        countByDay: countByDay,
                        onDateTap: (DateTime date) {
                          context
                              .push('/editor?date=${date.toIso8601String()}');
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object error, StackTrace stackTrace) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    title: '\u65e5\u5386\u52a0\u8f7d\u5931\u8d25',
                    message: error.toString(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '\u672c\u6708\u8bb0\u5f55',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          entriesAsync.when(
            data: (List<DiaryEntry> entries) {
              if (entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: '\u8fd9\u4e2a\u6708\u8fd8\u6ca1\u6709\u5185\u5bb9',
                  message:
                      '\u70b9\u65e5\u5386\u4e0a\u7684\u67d0\u4e00\u5929\uff0c\u5c31\u80fd\u76f4\u63a5\u5f00\u59cb\u5199\u3002',
                );
              }

              return Column(
                children: entries
                    .map(
                      (DiaryEntry entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EntryCard(
                          entry: entry,
                          onTap: () => context.push('/editor?id=${entry.id}'),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (Object error, StackTrace stackTrace) =>
                const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.countByDay,
    required this.onDateTap,
  });

  final DateTime month;
  final Map<DateTime, int> countByDay;
  final ValueChanged<DateTime> onDateTap;

  @override
  Widget build(BuildContext context) {
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    final DateTime nextMonth = DateTime(month.year, month.month + 1, 1);
    final int totalDays = nextMonth.difference(firstDay).inDays;
    final int leadingBlanks = firstDay.weekday - 1;
    final List<DateTime?> cells = <DateTime?>[
      ...List<DateTime?>.filled(leadingBlanks, null),
      ...List<DateTime>.generate(
        totalDays,
        (int index) => DateTime(month.year, month.month, index + 1),
      ),
    ];

    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: <Widget>[
        for (int row = 0; row < cells.length / 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                for (int column = 0; column < 7; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _DayCell(
                        date: cells[row * 7 + column],
                        count: cells[row * 7 + column] == null
                            ? 0
                            : countByDay[
                                    normalizeDate(cells[row * 7 + column]!)] ??
                                0,
                        onTap: onDateTap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.count,
    required this.onTap,
  });

  final DateTime? date;
  final int count;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const SizedBox(height: 64);
    }

    final DateTime today = normalizeDate(DateTime.now());
    final bool isToday = normalizeDate(date!) == today;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap(date!),
      child: Ink(
        height: 64,
        decoration: BoxDecoration(
          color: count > 0
              ? const Color(0xFFF0E7D6)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isToday
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE5DDCD),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${date!.day}'),
              const Spacer(),
              if (count > 0)
                Text(
                  '$count \u7bc7',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
