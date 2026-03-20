import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_color_palette.dart';

class AppTheme {
  static const Color _danger = Color(0xFFE74C3C);

  static ThemeData light(ColorPalette palette) {
    final seedColor = palette.seedColor;
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: const Color(0xFFFAF8F5),
      onSurface: const Color(0xFF1A1A2E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFAF8F5),
      splashFactory: InkSparkle.splashFactory,
      textTheme: GoogleFonts.crimsonTextTextTheme().apply(
        bodyColor: const Color(0xFF1A1A2E),
        displayColor: const Color(0xFF1A1A2E),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.crimsonText(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1A2E),
        ),
        iconTheme: IconThemeData(color: const Color(0xFF1A1A2E).withValues(alpha: 0.8), size: 22),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: GoogleFonts.crimsonText(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1A2E),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: GoogleFonts.crimsonText(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.crimsonText(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.crimsonText(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F3EE),
        hintStyle: GoogleFonts.crimsonText(color: Colors.black38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.withValues(alpha: 0.1),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      extensions: const [
        _AppColors(danger: _danger),
      ],
    );
  }


  static ThemeData dark(ColorPalette palette) {
    final seedColor = palette.seedColor;
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF161618),
      onSurface: const Color(0xFFEAEAEA),
      surfaceContainerHighest: const Color(0xFF2A2A2E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F11),
      splashFactory: InkSparkle.splashFactory,
      textTheme: GoogleFonts.crimsonTextTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.crimsonText(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEAEAEA),
        ),
        iconTheme: IconThemeData(color: const Color(0xFFEAEAEA).withValues(alpha: 0.8), size: 22),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E22),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: GoogleFonts.crimsonText(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEAEAEA),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: Colors.transparent,
        color: const Color(0xFF262628),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: GoogleFonts.crimsonText(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.crimsonText(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.crimsonText(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E22),
        hintStyle: GoogleFonts.crimsonText(color: Colors.white30),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      extensions: const [
        _AppColors(danger: _danger),
      ],
    );
  }
}

@immutable
class _AppColors extends ThemeExtension<_AppColors> {
  const _AppColors({required this.danger});

  final Color danger;

  @override
  _AppColors copyWith({Color? danger}) => _AppColors(danger: danger ?? this.danger);

  @override
  _AppColors lerp(ThemeExtension<_AppColors>? other, double t) {
    if (other is! _AppColors) return this;
    return _AppColors(danger: Color.lerp(danger, other.danger, t) ?? danger);
  }
}

extension AppColorsX on BuildContext {
  Color get danger => Theme.of(this).extension<_AppColors>()!.danger;
}


