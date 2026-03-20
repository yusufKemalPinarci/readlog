import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_color_palette.dart';

// Provider for theme mode (light/dark/system)
final themeProvider = StateNotifierProvider<ThemeManager, ThemeMode>((ref) {
  throw UnimplementedError('ThemeManager provider requires SharedPreferences override');
});

// Provider for color palette
final colorPaletteProvider = StateNotifierProvider<ColorPaletteManager, ColorPalette>((ref) {
  throw UnimplementedError('ColorPaletteManager provider requires SharedPreferences override');
});

/// Theme Mode Manager (Light/Dark/System)
class ThemeManager extends StateNotifier<ThemeMode> {
  ThemeManager(this._prefs) : super(ThemeMode.system) {
    _loadTheme();
  }

  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  void _loadTheme() {
    final saved = _prefs.getString(_key);
    if (saved == 'light') {
      state = ThemeMode.light;
    } else if (saved == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    if (mode == ThemeMode.light) {
      await _prefs.setString(_key, 'light');
    } else if (mode == ThemeMode.dark) {
      await _prefs.setString(_key, 'dark');
    } else {
      await _prefs.remove(_key);
    }
  }
}

/// Color Palette Manager
class ColorPaletteManager extends StateNotifier<ColorPalette> {
  ColorPaletteManager(this._prefs) : super(ColorPalette.classic) {
    _loadPalette();
  }

  final SharedPreferences _prefs;
  static const _key = 'color_palette';

  void _loadPalette() {
    final saved = _prefs.getString(_key);
    if (saved != null) {
      try {
        final index = int.parse(saved);
        if (index >= 0 && index < ColorPalette.values.length) {
          state = ColorPalette.values[index];
        }
      } catch (_) {
        // Invalid value, keep default
      }
    }
  }

  Future<void> setPalette(ColorPalette palette) async {
    state = palette;
    await _prefs.setString(_key, palette.index.toString());
  }
}

