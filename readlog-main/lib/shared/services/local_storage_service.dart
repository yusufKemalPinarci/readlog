import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  static const String _booksKey = 'books_data';
  static const String _readingLogsKey = 'reading_logs_data';
  static const String _themeModeKey = 'theme_mode';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _profileKey = 'profile_data';

  // Books
  Future<void> saveBooks(List<Map<String, dynamic>> booksJson) async {
    await _prefs.setString(_booksKey, jsonEncode(booksJson));
  }

  List<Map<String, dynamic>> loadBooks() {
    final String? jsonString = _prefs.getString(_booksKey);
    if (jsonString == null) return [];
    
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      // JSON format hatası durumunda boş liste dön
      return [];
    }
  }

  // Reading Logs
  Future<void> saveReadingLogs(List<Map<String, dynamic>> logsJson) async {
    await _prefs.setString(_readingLogsKey, jsonEncode(logsJson));
  }

  List<Map<String, dynamic>> loadReadingLogs() {
    final String? jsonString = _prefs.getString(_readingLogsKey);
    if (jsonString == null) return [];

    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
       // JSON format hatası durumunda boş liste dön
      return [];
    }
  }
  
  // Clear all data (for debugging or logout)
  Future<void> clearAll() async {
    await _prefs.remove(_booksKey);
    await _prefs.remove(_readingLogsKey);
    await _prefs.remove(_profileKey);
    await _prefs.remove(_isFirstLaunchKey);
    await _prefs.remove(_themeModeKey);
  }

  // Theme Mode
  Future<void> saveThemeMode(bool isDark) async {
    await _prefs.setBool(_themeModeKey, isDark);
  }

  bool loadThemeMode() {
    return _prefs.getBool(_themeModeKey) ?? false; // Default to light mode
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
