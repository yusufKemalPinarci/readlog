import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:berber/shared/widgets/confirm_dialog.dart';
import 'package:berber/app/theme/app_theme.dart';
import 'package:berber/app/theme/theme_color_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('showConfirmDialog', () {
    Widget buildApp({required Widget child}) {
      return MaterialApp(
        theme: AppTheme.light(ColorPalette.classic),
        home: child,
      );
    }

    testWidgets('title ve message gösterir', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmDialog(
                context: context,
                title: 'Silme Onayı',
                message: 'Silmek istediğinize emin misiniz?',
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.text('Silme Onayı'), findsOneWidget);
      expect(find.text('Silmek istediğinize emin misiniz?'), findsOneWidget);
    });

    testWidgets('varsayılan buton metinleri doğru', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmDialog(
                context: context,
                title: 'Test',
                message: 'Test mesaj',
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('Evet, Sil'), findsOneWidget);
    });

    testWidgets('özel buton metinleri kullanılır', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmDialog(
                context: context,
                title: 'Test',
                message: 'Test mesaj',
                cancelText: 'Hayır',
                confirmText: 'Tamam',
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.text('Hayır'), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);
    });

    testWidgets('iptal butonu false döner', (tester) async {
      bool? result;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context: context,
                  title: 'Test',
                  message: 'Msg',
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();

      expect(result, false);
    });

    testWidgets('onay butonu true döner', (tester) async {
      bool? result;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context: context,
                  title: 'Test',
                  message: 'Msg',
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evet, Sil'));
      await tester.pumpAndSettle();

      expect(result, true);
    });
  });
}
