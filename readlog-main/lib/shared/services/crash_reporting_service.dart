import 'package:flutter/foundation.dart';

/// Crash reporting servisi
/// Hata loglama ve izleme
class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  bool _isInitialized = false;

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
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

  void _logError(dynamic error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('Error: $error');
      if (stack != null) {
        debugPrint('Stack: $stack');
      }
    }
  }

  /// Manuel hata kaydet
  void recordError(dynamic error, StackTrace? stack, {String? reason}) {
    _logError(error, stack);
  }

  /// Log mesajı kaydet
  void log(String message) {
    if (kDebugMode) {
      debugPrint('Error Log: $message');
    }
  }
}
