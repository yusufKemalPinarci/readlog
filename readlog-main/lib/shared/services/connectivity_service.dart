import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// İnternet bağlantısı durumunu kontrol eden servis
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// İnternet bağlantısı durumunu kontrol et
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  /// İnternet bağlantısı durumunu stream olarak dinle.
  /// T4.14: connected if ANY interface is up (don't just take the arbitrary
  /// first result — [none, wifi] would otherwise read as offline).
  Stream<bool> get connectedStream {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }

  /// WiFi bağlı mı?
  Future<bool> isWifiConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Mobil veri bağlı mı?
  Future<bool> isMobileConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile);
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// İnternet bağlantısı akışı (bağlı mı?).
final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectedStream;
});

/// İnternet bağlı mı? (bool)
///
/// T4.14: a plain derived bool (not a second StreamProvider). While the first
/// connectivity result is still loading — or on error — assume connected, so the
/// offline banner never flashes on startup or after a reconnect.
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (connected) => connected,
        orElse: () => true,
      );
});
