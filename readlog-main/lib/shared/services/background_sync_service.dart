import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background sync servisi
/// Local storage kullandığımız için background sync'e ihtiyaç yok
/// Bu servis şimdilik boş bırakıldı, gelecekte gerekirse eklenebilir
class BackgroundSyncService {
  /// Servisi başlat (şimdilik boş)
  Future<void> initialize() async {
    // Local storage kullandığımız için background sync'e ihtiyaç yok
  }

  /// Periyodik sync görevi planla (şimdilik boş)
  Future<void> schedulePeriodicSync({int frequencyMinutes = 60}) async {
    // Local storage kullandığımız için background sync'e ihtiyaç yok
  }

  /// Sync görevini iptal et (şimdilik boş)
  Future<void> cancelSync() async {
    // Local storage kullandığımız için background sync'e ihtiyaç yok
  }

  /// Tek seferlik sync görevi planla (şimdilik boş)
  Future<void> scheduleOneTimeSync({Duration? delay}) async {
    // Local storage kullandığımız için background sync'e ihtiyaç yok
  }
}

final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  return BackgroundSyncService();
});
