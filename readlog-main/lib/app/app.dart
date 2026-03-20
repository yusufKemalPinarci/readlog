import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import '../shared/widgets/offline_banner.dart';

class ReadLogApp extends ConsumerWidget {
  const ReadLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final colorPalette = ref.watch(colorPaletteProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Libris',
      theme: AppTheme.light(colorPalette),
      darkTheme: AppTheme.dark(colorPalette),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: OfflineBanner(),
            ),
          ],
        );
      },
    );
  }
}


