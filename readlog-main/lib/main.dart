import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared/services/local_storage_service.dart';
import 'app/theme/theme_manager.dart';
import 'shared/services/crash_reporting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    // Locale yükleme hatası durumunda devam et
    debugPrint('Locale yükleme hatası: $e');
  }

  // SharedPreferences'ı başlat
  final prefs = await SharedPreferences.getInstance();

  // T2.26: the notification service is initialized lazily by the notification
  // settings notifier only when reminders are enabled, and POST_NOTIFICATIONS is
  // requested at that opt-in moment — not on first frame. So no init here.

  // LocalStorageService'i başlat
  final localStorageService = LocalStorageService(prefs);
  
  // Crash reporting servisini başlat
  final crashReporting = CrashReportingService();
  await crashReporting.initialize();
  
  // Background sync servisi kaldırıldı - Local storage kullandığımız için gerekli değil
  
  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorageService),
        // ThemeManager provider'ını override et
        themeProvider.overrideWith((ref) => ThemeManager(prefs)),
        // ColorPaletteManager provider'ını override et
        colorPaletteProvider.overrideWith((ref) => ColorPaletteManager(prefs)),
      ],
      child: const LibrisApp(),
    ),
  );
}
