import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/notification_service.dart';

/// Bildirim ayarları provider'ı
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettings {
  const NotificationSettings({
    this.enabled = false, // T2.26: OFF until the user opts in (permission consent)
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
      enabled: prefs.getBool(_keyEnabled) ?? false, // T2.26: default OFF
      hour: prefs.getInt(_keyHour) ?? 20,
      minute: prefs.getInt(_keyMinute) ?? 0,
    );
    // T2.26: only touch the notification plugin (and its permission prompts)
    // when the user has previously enabled reminders — never on a fresh install.
    if (state.enabled) {
      await _updateNotificationSchedule();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      // T2.26: request POST_NOTIFICATIONS only at the moment of opt-in. If the
      // user refuses, keep reminders off instead of pretending they're on.
      final service = NotificationService();
      try {
        await service.initialize();
      } catch (_) {}
      final granted = await service.requestPermission();
      if (!granted) {
        await prefs.setBool(_keyEnabled, false);
        state = state.copyWith(enabled: false);
        return;
      }
    }
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
    // T2.26: notification failures must never propagate to the UI/startup.
    try {
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
    } catch (_) {
      // Yoksay — bildirim planlaması kritik değil.
    }
  }
}

