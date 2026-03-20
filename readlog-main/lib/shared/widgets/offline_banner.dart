import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Offline durumunu gösteren banner widget'ı
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(isConnectedProvider);

    return connectivity.when(
      data: (isConnected) {
        if (isConnected) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange,
          child: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'İnternet bağlantısı yok',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
