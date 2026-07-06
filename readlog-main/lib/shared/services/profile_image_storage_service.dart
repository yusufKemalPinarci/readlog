import 'dart:io';
import 'package:path/path.dart' as p;
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

  /// Resmi dosyaya kaydet (kopyala).
  ///
  /// T1.7: Kaynak zaten hedefse dokunmadan yolu döndürür; aksi halde `.tmp`
  /// üzerinden atomik olarak yerine taşır (kopyalama yarıda kalırsa eski
  /// dosya korunur).
  Future<String?> saveImage(String userId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final targetPath = await getImageFilePath(userId);
      if (p.canonicalize(sourcePath) == p.canonicalize(targetPath)) {
        return targetPath;
      }

      final tmpPath = '$targetPath.tmp';
      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      await sourceFile.copy(tmpPath);
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tmpFile.rename(targetPath);
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

