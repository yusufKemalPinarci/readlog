import 'dart:io';
import 'package:path/path.dart' as p;
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

  /// Resmi dosyaya kaydet (kopyala).
  ///
  /// T1.7: Eğer kaynak zaten hedef dosyaysa (kapak değişmeden kaydedilmişse)
  /// hiçbir şey yapmadan mevcut yolu döndürür — eskiden hedefi silip aynı
  /// dosyadan kopyalamaya çalışıp kapağı yok ediyordu. Aksi halde önce `.tmp`
  /// dosyasına kopyalar, sonra yerine taşır; kopyalama yarıda kalırsa eski
  /// dosya korunur.
  Future<String?> saveImage(String bookId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final targetPath = await getImageFilePath(bookId);
      if (p.canonicalize(sourcePath) == p.canonicalize(targetPath)) {
        // Kaynak = hedef: dokunma, kapak zaten yerinde.
        return targetPath;
      }

      final tmpPath = '$targetPath.tmp';
      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      // Önce tam kopyayı temp'e al (kaynak/hedef bu noktaya kadar bozulmaz).
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

