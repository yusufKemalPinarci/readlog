import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageHelper {
  static Future<String?> cropImage({
    required BuildContext context,
    required String sourcePath,
    CropAspectRatio? aspectRatio,
    bool lockAspectRatio = false,
  }) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Kırp',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: aspectRatio != null ? CropAspectRatioPreset.square : CropAspectRatioPreset.original,
            lockAspectRatio: lockAspectRatio,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Kırp',
            aspectRatioLockEnabled: lockAspectRatio,
            resetAspectRatioEnabled: true,
          ),
        ],
        aspectRatio: aspectRatio,
      );

      return croppedFile?.path;
    } catch (e) {
      debugPrint('Crop error: $e');
      return null;
    }
  }
}
