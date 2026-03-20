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

  /// İnternet bağlantısı durumunu stream olarak dinle
  Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((results) {
      // İlk sonucu döndür, yoksa none
      return results.isNotEmpty ? results.first : ConnectivityResult.none;
    });
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

/// İnternet bağlantısı durumu provider'ı
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectivityStream;
});

/// İnternet bağlı mı? (bool)
final isConnectedProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (result) => Stream.value(result != ConnectivityResult.none),
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});
