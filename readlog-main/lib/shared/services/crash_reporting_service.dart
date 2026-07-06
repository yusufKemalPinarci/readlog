import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Crash reporting servisi.
///
/// T2.27: errors were only debugPrinted in debug mode, so in release the
/// PlatformDispatcher handler swallowed everything silently. Now the last N
/// errors are kept in an in-memory ring buffer and mirrored to a local file
/// (app-private, no network) so they can be surfaced/retrieved for diagnostics.
class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  static const int _maxEntries = 50;
  static const String _logFileName = 'diagnostics_log.txt';

  final List<String> _recentErrors = [];
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
    final entry = '${DateTime.now().toIso8601String()} | $error'
        '${stack != null ? '\n$stack' : ''}';

    _recentErrors.add(entry);
    while (_recentErrors.length > _maxEntries) {
      _recentErrors.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint('Error: $error');
      if (stack != null) debugPrint('Stack: $stack');
    }

    // Best-effort persistence; never let logging failures cascade.
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logFileName');
      await file.writeAsString(_recentErrors.join('\n\n'), flush: false);
    } catch (_) {
      // Ignore — diagnostics must never crash the app.
    }
  }

  /// In-memory view of the most recent errors (newest last).
  List<String> get recentErrors => List.unmodifiable(_recentErrors);

  /// Read the persisted diagnostics log (across restarts). Empty when none.
  Future<String> readPersistedLog() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_logFileName');
      if (await file.exists()) return file.readAsString();
    } catch (_) {}
    return '';
  }

  /// Manuel hata kaydet
  void recordError(dynamic error, StackTrace? stack, {String? reason}) {
    _logError(reason != null ? '$reason: $error' : error, stack);
  }

  /// Log mesajı kaydet
  void log(String message) {
    _recentErrors.add('${DateTime.now().toIso8601String()} | LOG | $message');
    while (_recentErrors.length > _maxEntries) {
      _recentErrors.removeAt(0);
    }
    if (kDebugMode) debugPrint('Error Log: $message');
    unawaited(_persist());
  }
}
