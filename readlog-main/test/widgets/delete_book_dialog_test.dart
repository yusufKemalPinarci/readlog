import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:berber/shared/widgets/delete_book_dialog.dart';

void main() {
  group('DeleteBookDialog', () {
    testWidgets('dialog başlığı ve açıklaması gösterilir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DeleteBookDialog(onConfirm: () {}),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.text('Kitabı Sil?'), findsOneWidget);
      expect(find.textContaining('Bu kitabı silmek'), findsOneWidget);
      expect(find.text('Onay Kodu'), findsOneWidget);
    });

    testWidgets('6 haneli doğrulama kodu gösterilir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DeleteBookDialog(onConfirm: () {}),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      // 6 haneli kod gösterilmeli
      final codeTexts = tester.widgetList<Text>(find.byType(Text));
      final codeWidget = codeTexts.where((t) {
        final text = t.data ?? '';
        return RegExp(r'^\d{6}$').hasMatch(text);
      });
      expect(codeWidget.isNotEmpty, true, reason: '6 haneli doğrulama kodu bulunamadı');
    });

    testWidgets('İptal butonu dialogu kapatır', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DeleteBookDialog(onConfirm: () {}),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      expect(find.text('Kitabı Sil?'), findsOneWidget);

      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(find.text('Kitabı Sil?'), findsNothing);
    });

    testWidgets('yanlış kod ile hata mesajı gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DeleteBookDialog(onConfirm: () {}),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      // Yanlış kod gir
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(find.text('Kod hatalı. Lütfen tekrar deneyin.'), findsOneWidget);
    });

    testWidgets('doğru kod ile onConfirm çağrılır', (tester) async {
      bool confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DeleteBookDialog(onConfirm: () => confirmed = true),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      // Doğru kodu bul
      final codeTexts = tester.widgetList<Text>(find.byType(Text));
      final codeWidget = codeTexts.firstWhere((t) {
        final text = t.data ?? '';
        return RegExp(r'^\d{6}$').hasMatch(text);
      });
      final correctCode = codeWidget.data!;

      // Doğru kodu gir
      await tester.enterText(find.byType(TextField), correctCode);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(confirmed, true);
    });

    testWidgets('silme ikonu kırmızı gösterilir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DeleteBookDialog(onConfirm: () {}),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded));
      expect(icon.color, Colors.red);
    });
  });
}
