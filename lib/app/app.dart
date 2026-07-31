import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '\u65e5\u8bb0',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
