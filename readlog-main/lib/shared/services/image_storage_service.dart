import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static const String _imagesDirectoryName = 'book_covers';

  /// Kitap kapakları için dizin yolunu al
  Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/$_imagesDirectoryName');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Kitap kapağı resmi dosya yolunu al
  Future<String> getImageFilePath(String bookId) async {
    final imagesDir = await _getImagesDirectory();
    return '${imagesDir.path}/cover_$bookId.jpg';
  }

  /// Resmi dosyaya kaydet (kopyala)
  Future<String?> saveImage(String bookId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final targetPath = await getImageFilePath(bookId);
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
  Future<void> deleteImage(String bookId) async {
    final filePath = await getImageFilePath(bookId);
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
  Future<bool> imageExists(String bookId) async {
    final filePath = await getImageFilePath(bookId);
    final file = File(filePath);
    return await file.exists();
  }
}

