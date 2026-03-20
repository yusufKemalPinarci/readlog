import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/notification_service.dart';

/// Bildirim ayarları provider'ı
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.hour = 20,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  NotificationSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  static const String _keyEnabled = 'notification_enabled';
  static const String _keyHour = 'notification_hour';
  static const String _keyMinute = 'notification_minute';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      hour: prefs.getInt(_keyHour) ?? 20,
      minute: prefs.getInt(_keyMinute) ?? 0,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    state = state.copyWith(enabled: enabled);
    await _updateNotificationSchedule();
  }

  Future<void> setTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    state = state.copyWith(hour: hour, minute: minute);
    await _updateNotificationSchedule();
  }

  Future<void> _updateNotificationSchedule() async {
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    if (state.enabled) {
      await notificationService.scheduleDailyReminder(
        hour: state.hour,
        minute: state.minute,
        title: 'Okuma Zamanı! 📚',
        body: 'Günlük okuma hedefinize ulaşmak için bugün de okumaya devam edin.',
      );
    } else {
      await notificationService.cancelDailyReminder();
    }
  }
}

