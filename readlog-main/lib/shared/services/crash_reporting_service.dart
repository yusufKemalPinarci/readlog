import 'package:flutter/foundation.dart';

/// Crash reporting servisi
/// Local storage için hata loglama yapar
/// İleride Firebase Crashlytics eklenebilir
class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  bool _isInitialized = false;

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Local storage için error handler ayarla
      // İleride Firebase Crashlytics eklenebilir
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _logError(details.exception, details.stack);
      };

      // Platform exception handler
      PlatformDispatcher.instance.onError = (error, stack) {
        _logError(error, stack);
        return true;
      };

      _isInitialized = true;
    } catch (e) {
      debugPrint('Crash reporting başlatılamadı: $e');
    }
  }

  /// Hata kaydet (local storage için)
  void _logError(dynamic error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('Error: $error');
      if (stack != null) {
        debugPrint('Stack: $stack');
      }
    }
    // İleride local dosyaya kaydedilebilir veya Firebase Crashlytics eklenebilir
  }

  /// Manuel hata kaydet
  void recordError(dynamic error, StackTrace? stack, {String? reason}) {
    _logError(error, stack);
    // İleride local dosyaya kaydedilebilir veya Firebase Crashlytics eklenebilir
  }

  /// Log mesajı kaydet
  void log(String message) {
    if (kDebugMode) {
      debugPrint('Error Log: $message');
    }
    // İleride local dosyaya kaydedilebilir veya Firebase Crashlytics eklenebilir
  }

  /// Kullanıcı bilgisi ayarla (local storage için şimdilik kullanılmıyor)
  void setUserIdentifier(String userId) {
    // İleride local storage'da saklanabilir veya Firebase Crashlytics eklenebilir
  }
}
