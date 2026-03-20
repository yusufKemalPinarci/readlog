import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:berber/app/theme/theme_color_palette.dart';

void main() {
  group('ColorPalette', () {
    test('5 palet vardır', () {
      expect(ColorPalette.values.length, 5);
    });

    test('her paletin displayName i var', () {
      for (final palette in ColorPalette.values) {
        expect(palette.displayName.isNotEmpty, true);
      }
    });

    test('displayName ler Türkçe', () {
      expect(ColorPalette.classic.displayName, 'Klasik');
      expect(ColorPalette.ocean.displayName, 'Okyanus');
      expect(ColorPalette.forest.displayName, 'Orman');
      expect(ColorPalette.lavender.displayName, 'Lavanta');
      expect(ColorPalette.ruby.displayName, 'Yakut');
    });

    test('her paletin seedColor u var', () {
      for (final palette in ColorPalette.values) {
        expect(palette.seedColor, isA<Color>());
      }
    });

    test('seed color ler benzersiz', () {
      final colors = ColorPalette.values.map((p) => p.seedColor).toSet();
      expect(colors.length, 5);
    });

    test('her paletin iconu var', () {
      for (final palette in ColorPalette.values) {
        expect(palette.icon, isA<IconData>());
      }
    });

    test('classic kahverengi tonu', () {
      expect(ColorPalette.classic.seedColor, const Color(0xFF8D6E63));
    });

    test('ocean mavi tonu', () {
      expect(ColorPalette.ocean.seedColor, const Color(0xFF0277BD));
    });

    test('forest yeşil tonu', () {
      expect(ColorPalette.forest.seedColor, const Color(0xFF2E7D32));
    });

    test('lavender mor tonu', () {
      expect(ColorPalette.lavender.seedColor, const Color(0xFF7B1FA2));
    });

    test('ruby kırmızı tonu', () {
      expect(ColorPalette.ruby.seedColor, const Color(0xFFC62828));
    });
  });
}
