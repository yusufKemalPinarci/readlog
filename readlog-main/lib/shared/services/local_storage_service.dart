import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown by [LocalStorageService] when a stored blob exists but cannot be
/// decoded. Callers must treat this as "data present but unreadable" and must
/// NOT overwrite storage — otherwise a transient decode bug wipes real data.
class StorageCorruptionException implements Exception {
  StorageCorruptionException(this.key, [this.cause]);
  final String key;
  final Object? cause;
  @override
  String toString() => 'StorageCorruptionException($key): $cause';
}

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  static const String _booksKey = 'books_data';
  static const String _readingLogsKey = 'reading_logs_data';
  static const String _themeModeKey = 'theme_mode';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _profileKey = 'profile_data';

  static String _backupKey(String key) => '$key.bak';
  static String _corruptKey(String key) => '$key.corrupt.bak';

  /// Rolls the current blob into `<key>.bak` before it is overwritten, so the
  /// immediately-previous state is always recoverable (T1.4).
  Future<void> _rollBackup(String key) async {
    final existing = _prefs.getString(key);
    if (existing != null) {
      await _prefs.setString(_backupKey(key), existing);
    }
  }

  /// Decodes a stored JSON list. Returns [] only when the key is genuinely
  /// absent. On a decode/type failure it preserves the raw blob under
  /// `<key>.corrupt.bak` and throws [StorageCorruptionException] rather than
  /// masquerading corruption as "empty" (T1.4).
  List<Map<String, dynamic>> _loadList(String key) {
    final String? jsonString = _prefs.getString(key);
    if (jsonString == null) return [];
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      // Eager per-element cast so a bad element throws here, inside the guard.
      return List<Map<String, dynamic>>.from(
        decoded.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      // Keep the raw blob for recovery; never silently drop it.
      unawaited(_prefs.setString(_corruptKey(key), jsonString));
      throw StorageCorruptionException(key, e);
    }
  }

  // Books
  Future<void> saveBooks(List<Map<String, dynamic>> booksJson) async {
    await _rollBackup(_booksKey);
    await _prefs.setString(_booksKey, jsonEncode(booksJson));
  }

  List<Map<String, dynamic>> loadBooks() => _loadList(_booksKey);

  // Reading Logs
  Future<void> saveReadingLogs(List<Map<String, dynamic>> logsJson) async {
    await _rollBackup(_readingLogsKey);
    await _prefs.setString(_readingLogsKey, jsonEncode(logsJson));
  }

  List<Map<String, dynamic>> loadReadingLogs() => _loadList(_readingLogsKey);
  
  // Clear all data (for debugging or logout)
  Future<void> clearAll() async {
    await _prefs.remove(_booksKey);
    await _prefs.remove(_readingLogsKey);
    await _prefs.remove(_profileKey);
    await _prefs.remove(_isFirstLaunchKey);
    await _prefs.remove(_themeModeKey);
  }

  // Theme Mode — canonical representation shared with ThemeManager.
  //
  // T1.6: the same `theme_mode` key used to be written as a bool here and as a
  // String ('light'/'dark') by ThemeManager, colliding. Now this delegates to
  // the string form: 'light' | 'dark', or absent for "system". Reads tolerate a
  // legacy bool value written by older builds.
  Future<void> saveThemeModeString(String? mode) async {
    if (mode == 'light' || mode == 'dark') {
      await _prefs.setString(_themeModeKey, mode!);
    } else {
      await _prefs.remove(_themeModeKey);
    }
  }

  String? loadThemeModeString() {
    final Object? raw = _prefs.get(_themeModeKey);
    if (raw is String) {
      return (raw == 'light' || raw == 'dark') ? raw : null;
    }
    if (raw is bool) {
      return raw ? 'dark' : 'light'; // legacy migration tolerance
    }
    return null;
  }

  // Profile
  Future<void> saveProfile(Map<String, dynamic> profileJson) async {
    await _prefs.setString(_profileKey, jsonEncode(profileJson));
  }

  Map<String, dynamic>? loadProfile() {
    final String? jsonString = _prefs.getString(_profileKey);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // First Launch Status
  bool getIsFirstLaunch() {
    return _prefs.getBool(_isFirstLaunchKey) ?? true; // Default to true if not set
  }

  Future<void> setIsFirstLaunch(bool value) async {
    await _prefs.setBool(_isFirstLaunchKey, value);
  }
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageService must be overridden in main.dart');
});
