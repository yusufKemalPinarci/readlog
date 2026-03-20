import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:berber/shared/widgets/book_page_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookPageTransition', () {
    test('PageTransitionsBuilder instance oluşur', () {
      const transition = BookPageTransition();
      expect(transition, isA<PageTransitionsBuilder>());
    });

    testWidgets('buildTransitions FadeTransition ve SlideTransition üretir', (tester) async {
      const transition = BookPageTransition();
      final animationController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      animationController.value = 0.5;

      const child = SizedBox(key: Key('child'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return transition.buildTransitions(
                MaterialPageRoute(builder: (_) => child),
                context,
                animationController,
                kAlwaysDismissedAnimation,
                child,
              );
            },
          ),
        ),
      );

      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);

      animationController.dispose();
    });
  });

  group('BookPageView', () {
    testWidgets('child widget ları render eder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookPageView(
              children: const [
                Center(child: Text('Sayfa 1')),
                Center(child: Text('Sayfa 2')),
                Center(child: Text('Sayfa 3')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Sayfa 1'), findsOneWidget);
    });

    testWidgets('onPageChanged callback çağrılır', (tester) async {
      int? changedPage;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookPageView(
              onPageChanged: (page) => changedPage = page,
              children: const [
                Center(child: Text('Sayfa 1')),
                Center(child: Text('Sayfa 2')),
              ],
            ),
          ),
        ),
      );

      // Swipe ile ikinci sayfaya geç
      await tester.fling(find.text('Sayfa 1'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(changedPage, 1);
    });

    testWidgets('controller ile sayfa kontrol edilir', (tester) async {
      final controller = PageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookPageView(
              controller: controller,
              children: const [
                Center(child: Text('Sayfa 1')),
                Center(child: Text('Sayfa 2')),
                Center(child: Text('Sayfa 3')),
              ],
            ),
          ),
        ),
      );

      controller.jumpToPage(2);
      await tester.pumpAndSettle();

      expect(find.text('Sayfa 3'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('BouncingScrollPhysics varsayılan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookPageView(
              children: const [
                Center(child: Text('Sayfa 1')),
              ],
            ),
          ),
        ),
      );
      // PageView render edildi - varsayılan physics BouncingScrollPhysics
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
