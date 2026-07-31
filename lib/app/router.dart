import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/presentation/calendar_page.dart';
import '../features/entries/presentation/entry_editor_page.dart';
import '../features/entries/presentation/home_page.dart';
import '../features/search/presentation/search_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (BuildContext context, GoRouterState state) {
                return const HomePage();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/calendar',
              builder: (BuildContext context, GoRouterState state) {
                return const CalendarPage();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/search',
              builder: (BuildContext context, GoRouterState state) {
                return const SearchPage();
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/editor',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final String? idValue = state.uri.queryParameters['id'];
        final String? dateValue = state.uri.queryParameters['date'];

        return MaterialPage<void>(
          child: EntryEditorPage(
            entryId: idValue == null ? null : int.tryParse(idValue),
            initialDate:
                dateValue == null ? null : DateTime.tryParse(dateValue),
          ),
        );
      },
    ),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<String> _titles = <String>[
    '\u6700\u8fd1',
    '\u65e5\u5386',
    '\u641c\u7d22',
  ];

  @override
  Widget build(BuildContext context) {
    final int index = navigationShell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[index]),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFF5F1E6),
              Color(0xFFFFFCF5),
            ],
          ),
        ),
        child: navigationShell,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/editor'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('\u5199\u65e5\u8bb0'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int targetIndex) {
          navigationShell.goBranch(
            targetIndex,
            initialLocation: targetIndex == navigationShell.currentIndex,
          );
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '\u6700\u8fd1',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '\u65e5\u5386',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: '\u641c\u7d22',
          ),
        ],
      ),
    );
  }
}
