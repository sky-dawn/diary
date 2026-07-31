import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../entries/models/diary_entry.dart';
import '../../entries/presentation/providers.dart';
import '../../entries/presentation/widgets/entry_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = ref.watch(searchQueryProvider);
    final AsyncValue<List<DiaryEntry>> resultsAsync =
        ref.watch(searchResultsProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: <Widget>[
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText:
                  '\u641c\u6b63\u6587\u3001\u6807\u9898\u3001\u5173\u952e\u8bcd',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (String value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 20),
          if (query.trim().isEmpty)
            const EmptyState(
              icon: Icons.manage_search_outlined,
              title: '\u8f93\u5165\u5173\u952e\u8bcd\u5f00\u59cb\u641c\u7d22',
              message:
                  '\u53ef\u4ee5\u641c\u4eba\u540d\u3001\u5730\u70b9\u3001\u9879\u76ee\u540d\uff0c\u6216\u8005\u5f53\u5929\u53d1\u751f\u7684\u4e8b\u3002',
            )
          else
            resultsAsync.when(
              data: (List<DiaryEntry> entries) {
                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_outlined,
                    title: '\u6ca1\u6709\u627e\u5230\u5185\u5bb9',
                    message:
                        '\u6362\u4e2a\u8bcd\u8bd5\u8bd5\uff0c\u6216\u8005\u56de\u60f3\u4e0b\u4f60\u5f53\u65f6\u662f\u600e\u4e48\u5199\u7684\u3002',
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
                  title: '\u641c\u7d22\u5931\u8d25',
                  message: error.toString(),
                );
              },
            ),
        ],
      ),
    );
  }
}
