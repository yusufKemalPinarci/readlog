import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'shared/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared/services/local_storage_service.dart';
import 'app/theme/theme_manager.dart';
import 'shared/services/crash_reporting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    // Locale yükleme hatası durumunda devam et
    debugPrint('Locale yükleme hatası: $e');
  }

  // SharedPreferences'ı başlat
  final prefs = await SharedPreferences.getInstance();
  
  // Bildirim servisini başlat
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermission();

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
      child: const ReadLogApp(),
    ),
  );
}
