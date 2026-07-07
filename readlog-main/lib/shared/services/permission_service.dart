import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Mikrofon iznini kontrol et ve gerekirse iste
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        return true;
      } else if (result.isPermanentlyDenied && context.mounted) {
        await _showPermissionDeniedDialog(context, 'Mikrofon');
        return false;
      }
      return false;
    }
    
    if (status.isPermanentlyDenied && context.mounted) {
      await _showPermissionDeniedDialog(context, 'Mikrofon');
      return false;
    }
    
    return false;
  }

  // T4.11: the legacy Permission.storage path was removed — the app writes to
  // its own private directories (getApplicationDocumentsDirectory), so no
  // storage permission is needed on any Android version.

  /// Kamera iznini kontrol et ve gerekirse iste
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        return true;
      } else if (result.isPermanentlyDenied && context.mounted) {
        await _showPermissionDeniedDialog(context, 'Kamera');
        return false;
      }
      return false;
    }
    
    if (status.isPermanentlyDenied && context.mounted) {
      await _showPermissionDeniedDialog(context, 'Kamera');
      return false;
    }
    
    return false;
  }

  /// Galeri iznini kontrol et ve gerekirse iste
  static Future<bool> requestPhotoLibraryPermission(BuildContext context) async {
    // iOS için
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      
      if (status.isGranted) {
        return true;
      }
      
      if (status.isDenied) {
        final result = await Permission.photos.request();
        if (result.isGranted) {
          return true;
        } else if (result.isPermanentlyDenied && context.mounted) {
          await _showPermissionDeniedDialog(context, 'Fotoğraf Galerisi');
          return false;
        }
        return false;
      }
      
      if (status.isPermanentlyDenied && context.mounted) {
        await _showPermissionDeniedDialog(context, 'Fotoğraf Galerisi');
        return false;
      }
      
      return false;
    }
    
    // Android için
    // Android 13+ için READ_MEDIA_IMAGES izni gerekir
    if (await Permission.photos.isGranted) {
      return true;
    }
    
    if (await Permission.photos.isDenied) {
      final result = await Permission.photos.request();
      if (result.isGranted) {
        return true;
      } else if (result.isPermanentlyDenied && context.mounted) {
        await _showPermissionDeniedDialog(context, 'Fotoğraf Galerisi');
        return false;
      }
      return false;
    }
    
    if (await Permission.photos.isPermanentlyDenied && context.mounted) {
      await _showPermissionDeniedDialog(context, 'Fotoğraf Galerisi');
      return false;
    }
    
    return true;
  }

  /// İzin reddedildiğinde gösterilecek dialog
  static Future<void> _showPermissionDeniedDialog(
    BuildContext context,
    String permissionName,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName İzni Gerekli'),
        content: Text(
          // T4.11: per-permission text, not always "voice recording".
          'Bu özelliği kullanabilmek için $permissionName iznine ihtiyacımız var. '
          'Lütfen ayarlardan izni verin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings(); // T4.11: awaited
            },
            child: const Text('Ayarlara Git'),
          ),
        ],
      ),
    );
  }
}

