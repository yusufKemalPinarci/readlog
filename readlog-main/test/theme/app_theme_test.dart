import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libris/app/theme/app_theme.dart';
import 'package:libris/app/theme/theme_color_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme.light', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.light(ColorPalette.classic);
    });

    test('Material 3 kullanır', () {
      expect(theme.useMaterial3, true);
    });

    test('scaffold arka plan rengi doğru', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAF8F5));
    });

    test('card elevation 0', () {
      expect(theme.cardTheme.elevation, 0);
    });

    test('card border radius 20', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20));
    });

    test('dialog border radius 28', () {
      final shape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(28));
    });

    test('dialog elevation 0', () {
      expect(theme.dialogTheme.elevation, 0);
    });

    test('appbar şeffaf arka plan', () {
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    });

    test('appbar elevation 0', () {
      expect(theme.appBarTheme.elevation, 0);
    });

    test('appbar başlık ortalanmış', () {
      expect(theme.appBarTheme.centerTitle, true);
    });

    test('snackbar floating', () {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    test('bottomSheet yuvarlak köşe', () {
      final shape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, isNotNull);
    });

    test('bottomSheet drag handle gösterir', () {
      expect(theme.bottomSheetTheme.showDragHandle, true);
    });

    test('input border radius 16', () {
      final border = theme.inputDecorationTheme.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(16));
    });

    test('filledButton border radius 16', () {
      final style = theme.filledButtonTheme.style!;
      final shape = style.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    test('InkSparkle splash factory kullanır', () {
      expect(theme.splashFactory, InkSparkle.splashFactory);
    });

    test('danger renk extension mevcut', () {
      theme.extension<Object>();
      // Extension can be checked via the theme
      expect(theme.extensions.isNotEmpty, true);
    });
  });

  group('AppTheme.dark', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.dark(ColorPalette.classic);
    });

    test('Material 3 kullanır', () {
      expect(theme.useMaterial3, true);
    });

    test('scaffold arka plan koyu', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0F0F11));
    });

    test('card elevation 0', () {
      expect(theme.cardTheme.elevation, 0);
    });

    test('card rengi koyu', () {
      expect(theme.cardTheme.color, const Color(0xFF1E1E22));
    });

    test('dialog rengi koyu', () {
      expect(theme.dialogTheme.backgroundColor, const Color(0xFF1E1E22));
    });

    test('appbar şeffaf', () {
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    });

    test('InkSparkle splash factory kullanır', () {
      expect(theme.splashFactory, InkSparkle.splashFactory);
    });
  });

  group('5 palet ile tema üretimi', () {
    for (final palette in ColorPalette.values) {
      test('${palette.name} light theme oluşur', () {
        final theme = AppTheme.light(palette);
        expect(theme, isNotNull);
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      test('${palette.name} dark theme oluşur', () {
        final theme = AppTheme.dark(palette);
        expect(theme, isNotNull);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });
    }
  });
}
