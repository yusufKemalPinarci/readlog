import 'package:flutter/material.dart';

/// Renk paletleri enum'u - 5 farklı renk paleti
enum ColorPalette {
  classic,  // Mevcut kahverengi/deri tonu
  ocean,    // Mavi tonları
  forest,   // Yeşil tonları
  lavender, // Mor tonları
  ruby,     // Kırmızı tonları
}

/// ColorPalette extension - display names ve seed colors
extension ColorPaletteExtension on ColorPalette {
  /// Kullanıcı dostu isim
  String get displayName {
    switch (this) {
      case ColorPalette.classic:
        return 'Klasik';
      case ColorPalette.ocean:
        return 'Okyanus';
      case ColorPalette.forest:
        return 'Orman';
      case ColorPalette.lavender:
        return 'Lavanta';
      case ColorPalette.ruby:
        return 'Yakut';
    }
  }

  /// Her paletin seed color'u
  Color get seedColor {
    switch (this) {
      case ColorPalette.classic:
        return const Color(0xFF8D6E63); // Kahverengi/Deri
      case ColorPalette.ocean:
        return const Color(0xFF0277BD); // Mavi
      case ColorPalette.forest:
        return const Color(0xFF2E7D32); // Yeşil
      case ColorPalette.lavender:
        return const Color(0xFF7B1FA2); // Mor
      case ColorPalette.ruby:
        return const Color(0xFFC62828); // Kırmızı
    }
  }

  /// Her paletin ikonu (settings'te gösterebilmek için)
  IconData get icon {
    switch (this) {
      case ColorPalette.classic:
        return Icons.menu_book;
      case ColorPalette.ocean:
        return Icons.water;
      case ColorPalette.forest:
        return Icons.park;
      case ColorPalette.lavender:
        return Icons.spa;
      case ColorPalette.ruby:
        return Icons.favorite;
    }
  }

  /// Renk örneği (preview için)
  Color get previewColor => seedColor;
}
