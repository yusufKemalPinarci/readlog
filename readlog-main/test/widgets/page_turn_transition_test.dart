import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:berber/shared/widgets/page_turn_transition.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('PageTurnTransition', () {
    test('fade ve slide geçişi kullanır', () {
      final page = PageTurnTransition(
        child: const SizedBox(),
      );
      expect(page, isA<CustomTransitionPage<void>>());
    });

    test('forward süresi 350ms', () {
      final page = PageTurnTransition(child: const SizedBox());
      expect(page.transitionDuration, const Duration(milliseconds: 350));
    });

    test('reverse süresi 280ms', () {
      final page = PageTurnTransition(child: const SizedBox());
      expect(page.reverseTransitionDuration, const Duration(milliseconds: 280));
    });

    testWidgets('transitionsBuilder FadeTransition ve SlideTransition içerir', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/detail',
            pageBuilder: (context, state) => PageTurnTransition(
              child: const Scaffold(body: Text('Detail')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/detail');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));

      // Geçiş esnasında FadeTransition ve SlideTransition bulunmalı
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);
    });
  });
}
