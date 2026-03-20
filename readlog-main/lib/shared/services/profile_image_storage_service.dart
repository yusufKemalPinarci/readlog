import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ProfileImageStorageService {
  static const String _imagesDirectoryName = 'profile_images';

  /// Profil resimleri için dizin yolunu al
  Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/$_imagesDirectoryName');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Profil resmi dosya yolunu al
  Future<String> getImageFilePath(String userId) async {
    final imagesDir = await _getImagesDirectory();
    return '${imagesDir.path}/avatar_$userId.jpg';
  }

  /// Resmi dosyaya kaydet (kopyala)
  Future<String?> saveImage(String userId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final targetPath = await getImageFilePath(userId);
      final targetFile = File(targetPath);
      
      // Eğer hedef dosya varsa önce sil
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // Kaynak dosyayı hedefe kopyala
      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (e) {
      return null;
    }
  }

  /// Resim dosyasını sil
  Future<void> deleteImage(String userId) async {
    final filePath = await getImageFilePath(userId);
    final file = File(filePath);
    
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        // Dosya silme hatası görmezden gel
      }
    }
  }

  /// Resim dosyasının var olup olmadığını kontrol et
  Future<bool> imageExists(String userId) async {
    final filePath = await getImageFilePath(userId);
    final file = File(filePath);
    return await file.exists();
  }
}

