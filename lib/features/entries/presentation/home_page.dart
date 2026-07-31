import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/diary_entry.dart';
import 'providers.dart';
import 'widgets/entry_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DiaryEntry>> entriesAsync =
        ref.watch(recentEntriesProvider);
    final DateTime today = DateTime.now();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '\u4eca\u5929\uff0c\u8bb0\u4e00\u7b14',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatEntryDate(today),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '\u5148\u628a\u5b83\u505a\u6210\u4f60\u613f\u610f\u6bcf\u5929\u6253\u5f00\u7684\u5de5\u5177\uff0c\u518d\u6162\u6162\u52a0\u540c\u6b65\u548c\u81ea\u52a8\u5316\u3002',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      context.push('/editor?date=${today.toIso8601String()}');
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('\u5199\u4eca\u5929\u7684\u65e5\u8bb0'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '\u6700\u8fd1\u8bb0\u5f55',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(recentEntriesProvider),
                child: const Text('\u5237\u65b0'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          entriesAsync.when(
            data: (List<DiaryEntry> entries) {
              if (entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: '\u8fd8\u6ca1\u6709\u5185\u5bb9',
                  message:
                      '\u5148\u5199\u4e00\u7bc7\u4eca\u5929\u7684\u8bb0\u5f55\uff0c\u770b\u770b\u8fd9\u5957\u6d41\u7a0b\u662f\u5426\u987a\u624b\u3002',
                );
              }

              return Column(
                children: entries
                    .map(
                      (DiaryEntry entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EntryCard(
                          entry: entry,
                          onTap: () {
                            context.push('/editor?id=${entry.id}');
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, StackTrace stackTrace) {
              return EmptyState(
                icon: Icons.error_outline,
                title: '\u52a0\u8f7d\u5931\u8d25',
                message: error.toString(),
              );
            },
          ),
        ],
      ),
    );
  }
}
