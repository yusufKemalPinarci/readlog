import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Bildirim servisini başlat
  Future<void> initialize() async {
    if (_initialized) return;

    // Timezone verilerini yükle ve cihaz yerel saatini ayarla.
    // T2.26: don't let an unknown/failed device timezone crash init — fall back
    // to UTC so the rest of initialization (and the app) keeps working.
    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    // Android ayarları
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS ayarları
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Platform ayarları
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Bildirimleri başlat
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Bildirime tıklandığında çağrılır
  void _onNotificationTapped(NotificationResponse response) {
    // Bildirim tıklaması uygulama açıkken veya arka plandayken tetiklenir.
    // Uygulama otomatik olarak ön plana gelir.
  }

  /// Günlük okuma hatırlatıcısı ayarla
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Günlük Hatırlatıcı',
        channelDescription: 'Günlük okuma hatırlatıcıları',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // Okuma hatırlatıcısı için inexact zamanlama yeterli (exact alarm izni gerektirmez)
    await _notifications.zonedSchedule(
      0,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Belirli bir saat için bir sonraki zamanı hesapla
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Eğer zaman geçmişse, yarın için ayarla.
    // T2.26: rebuild from calendar components rather than add(Duration(days:1)),
    // which would land on the wrong wall-clock time across a DST transition.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }

    return scheduledDate;
  }

  /// Günlük hatırlatıcıyı iptal et
  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(0);
  }

  /// Tüm bildirimleri iptal et
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Bildirim izni iste (Android 13+)
  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }
}
