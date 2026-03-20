import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:berber/shared/widgets/book_scaffold.dart';

void main() {
  group('BookScaffold', () {
    testWidgets('body yi render eder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookScaffold(body: Text('İçerik')),
        ),
      );
      expect(find.text('İçerik'), findsOneWidget);
    });

    testWidgets('appBar gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookScaffold(
            appBar: AppBar(title: const Text('Başlık')),
            body: const SizedBox(),
          ),
        ),
      );
      expect(find.text('Başlık'), findsOneWidget);
    });

    testWidgets('FAB gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookScaffold(
            body: const SizedBox(),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('scaffold arka planı tema rengini kullanır', (tester) async {
      const testColor = Color(0xFFFAF8F5);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: testColor),
          home: const BookScaffold(body: SizedBox()),
        ),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, testColor);
    });

    testWidgets('extendBody true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookScaffold(body: SizedBox()),
        ),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBody, true);
    });

    testWidgets('bottomNavigationBar gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookScaffold(
            body: const SizedBox(),
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });
  });
}
