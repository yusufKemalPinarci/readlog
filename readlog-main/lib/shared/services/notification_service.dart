import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // Timezone verilerini yükle
    tz.initializeTimeZones();

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
    // Bildirime tıklandığında yapılacak işlemler
    // (ileride navigation eklenebilir)
  }

  /// Günlük okuma hatırlatıcısı ayarla
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _notifications.zonedSchedule(
      0,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Günlük Hatırlatıcı',
          channelDescription: 'Günlük okuma hatırlatıcıları',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 10 saniye sonra test bildirimi gönder
  Future<void> scheduleTestNotification() async {
    // 10 saniye bekle
    await Future.delayed(const Duration(seconds: 10));
    
    // Bildirimi göster
    await _notifications.show(
      999,
      'Okuma Vakti!',
      'Uygulamadan ayrıldın ama okumayı unutma! 📚',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Bildirimleri',
          channelDescription: 'Test amaçlı bildirimler',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
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

    // Eğer zaman geçmişse, yarın için ayarla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
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
