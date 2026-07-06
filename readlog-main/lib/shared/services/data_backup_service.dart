import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'local_storage_service.dart';

final dataBackupServiceProvider = Provider<DataBackupService>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  return DataBackupService(localStorage);
});

class DataBackupService {
  DataBackupService(this._localStorage);

  final LocalStorageService _localStorage;

  // ZIP içindeki klasör yapısı
  static const String _bookCoversDir = 'book_covers';
  static const String _recordingsDir = 'recordings';
  static const String _notesDir = 'notes';
  static const String _profileImagesDir = 'profile_images';
  static const String _backupJsonName = 'backup.json';

  /// Tüm verileri ZIP arşivi olarak dışa aktarır (JSON + tüm dosyalar)
  Future<void> exportData() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final archive = Archive();

      // 1. Metadata JSON oluştur
      final books = _localStorage.loadBooks();
      final logs = _localStorage.loadReadingLogs();
      final profile = _localStorage.loadProfile();
      final themeMode = _localStorage.loadThemeModeString();

      // Dosya path'lerini relative yap ve dosyaları arşive ekle
      final processedBooks = await _processBookPaths(books, appDir, archive);
      final processedLogs = await _processLogPaths(logs, appDir, archive);
      final processedProfile = await _processProfilePath(profile, appDir, archive);

      final Map<String, dynamic> backupData = {
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'books': processedBooks,
        'readingLogs': processedLogs,
        'profile': processedProfile,
        'settings': {
          // Canonical theme representation ('light'|'dark'|null=system).
          'themeMode': themeMode,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final jsonBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile(_backupJsonName, jsonBytes.length, jsonBytes));

      // 2. ZIP dosyası oluştur
      final zipData = ZipEncoder().encode(archive);

      final tempDir = await getTemporaryDirectory();
      final zipFile = File(
        '${tempDir.path}/libris_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await zipFile.writeAsBytes(zipData);

      // 3. Dosyayı paylaş
      await SharePlus.instance.share(ShareParams(
        files: [XFile(zipFile.path)],
        text: 'Libris Yedek Dosyası',
        subject: 'Libris Yedek Dosyası',
      ));
    } catch (e) {
      throw Exception('Yedekleme hatası: $e');
    }
  }

  /// Kitap verilerindeki dosya yollarını relative yap ve dosyaları arşive ekle
  Future<List<Map<String, dynamic>>> _processBookPaths(
    List<Map<String, dynamic>> books,
    Directory appDir,
    Archive archive,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final book in books) {
      final processed = Map<String, dynamic>.from(book);
      final coverPath = book['coverImagePath'] as String?;
      if (coverPath != null && coverPath.isNotEmpty) {
        final file = File(coverPath);
        if (await file.exists()) {
          final relativePath = '$_bookCoversDir/${p.basename(coverPath)}';
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
          processed['coverImagePath'] = relativePath;
        } else {
          processed['coverImagePath'] = null;
        }
      }
      result.add(processed);
    }
    return result;
  }

  /// Reading log verilerindeki dosya yollarını relative yap ve dosyaları arşive ekle
  Future<List<Map<String, dynamic>>> _processLogPaths(
    List<Map<String, dynamic>> logs,
    Directory appDir,
    Archive archive,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final log in logs) {
      final processed = Map<String, dynamic>.from(log);

      // Ses kaydı
      final audioPath = log['audioFilePath'] as String?;
      if (audioPath != null && audioPath.isNotEmpty) {
        final file = File(audioPath);
        if (await file.exists()) {
          final relativePath = '$_recordingsDir/${p.basename(audioPath)}';
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
          processed['audioFilePath'] = relativePath;
        } else {
          processed['audioFilePath'] = null;
        }
      }

      // Not dosyası
      final notePath = log['noteFilePath'] as String?;
      if (notePath != null && notePath.isNotEmpty) {
        final file = File(notePath);
        if (await file.exists()) {
          final relativePath = '$_notesDir/${p.basename(notePath)}';
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
          processed['noteFilePath'] = relativePath;
        } else {
          processed['noteFilePath'] = null;
        }
      }

      result.add(processed);
    }
    return result;
  }

  /// Profil verisindeki avatar yolunu relative yap ve dosyayı arşive ekle
  Future<Map<String, dynamic>?> _processProfilePath(
    Map<String, dynamic>? profile,
    Directory appDir,
    Archive archive,
  ) async {
    if (profile == null) return null;
    final processed = Map<String, dynamic>.from(profile);
    final avatarPath = profile['avatarImagePath'] as String?;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (await file.exists()) {
        final relativePath = '$_profileImagesDir/${p.basename(avatarPath)}';
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        processed['avatarImagePath'] = relativePath;
      } else {
        processed['avatarImagePath'] = null;
      }
    }
    return processed;
  }

  /// Kullanıcıdan yedek dosyası seçmesini ister.
  /// Seçim iptal edilirse `null` döner.
  Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    final file = File(filePath);
    if (!await file.exists()) return null;
    return file;
  }

  /// Seçilmiş dosyadan içe aktarım yapar.
  /// [replaceExisting] true ise mevcut veriler silinir, false ise birleştirilir.
  Future<void> importFromFile(File file, {bool replaceExisting = false}) async {
    try {
      if (file.path.toLowerCase().endsWith('.zip')) {
        await _importFromZip(file, replaceExisting: replaceExisting);
      } else {
        await _importFromJson(file, replaceExisting: replaceExisting);
      }
    } catch (e) {
      throw Exception('İçe aktarma hatası: $e');
    }
  }

  /// ZIP veya JSON dosyasından verileri içe aktarır (eski API — geriye uyumluluk için).
  /// [replaceExisting] true ise mevcut veriler silinir, false ise birleştirilir
  Future<void> importData({bool replaceExisting = false}) async {
    final file = await pickBackupFile();
    if (file == null) return; // Kullanıcı iptal etti
    await importFromFile(file, replaceExisting: replaceExisting);
  }

  /// ZIP arşivinden içe aktarım (v2 format)
  Future<void> _importFromZip(File zipFile, {required bool replaceExisting}) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final appDir = await getApplicationDocumentsDirectory();

    // backup.json'u bul ve parse et
    final jsonFile = archive.findFile(_backupJsonName);
    if (jsonFile == null) {
      throw Exception('ZIP arşivinde backup.json bulunamadı');
    }

    final jsonString = utf8.decode(jsonFile.content as List<int>);
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    final version = backupData['version'] as int? ?? 1;
    if (version != 1 && version != 2) {
      throw Exception('Desteklenmeyen yedek dosyası versiyonu: $version');
    }

    final booksJson = backupData['books'] as List<dynamic>?;
    final logsJson = backupData['readingLogs'] as List<dynamic>?;
    if (booksJson == null || logsJson == null) {
      throw Exception('Yedek dosyası eksik veri içeriyor');
    }

    // Merge modda mevcut ID'leri al — dosya çıkartmayı atlamak için
    Set<String>? existingBookIds;
    Set<String>? existingLogIds;
    if (!replaceExisting) {
      existingBookIds = _localStorage.loadBooks().map((b) => b['id'] as String).toSet();
      existingLogIds = _localStorage.loadReadingLogs().map((l) => l['id'] as String).toSet();
    }

    // Dosyaları arşivden cihaza çıkar ve path'leri güncelle
    final books = await _restoreBookFiles(booksJson, archive, appDir, skipIds: existingBookIds);
    final logs = await _restoreLogFiles(logsJson, archive, appDir, skipIds: existingLogIds);

    // Profil ve ayarları geri yükle
    final profileJson = backupData['profile'] as Map<String, dynamic>?;
    if (profileJson != null) {
      final restoredProfile = await _restoreProfileFiles(profileJson, archive, appDir);
      await _localStorage.saveProfile(restoredProfile);
    }

    _restoreThemeFromSettings(backupData['settings']);

    // Kitap ve log verilerini kaydet
    await _mergeAndSave(books, logs, replaceExisting: replaceExisting);
  }

  /// Eski JSON formatından içe aktarım (v1 geriye uyumluluk)
  Future<void> _importFromJson(File jsonFile, {required bool replaceExisting}) async {
    final jsonString = await jsonFile.readAsString();

    final Map<String, dynamic> backupData;
    try {
      backupData = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Geçersiz JSON formatı: $e');
    }

    final version = backupData['version'] as int? ?? 1;
    if (version != 1 && version != 2) {
      throw Exception('Desteklenmeyen yedek dosyası versiyonu: $version');
    }

    final booksJson = backupData['books'] as List<dynamic>?;
    final logsJson = backupData['readingLogs'] as List<dynamic>?;
    if (booksJson == null || logsJson == null) {
      throw Exception('Yedek dosyası eksik veri içeriyor');
    }

    final books = booksJson.map((item) => item as Map<String, dynamic>).toList();
    final logs = logsJson.map((item) => item as Map<String, dynamic>).toList();

    // v1 JSON'da dosya path'leri mutlak — cihazda karşılığı yoksa temizle
    _cleanInvalidPaths(books, 'coverImagePath');
    for (final log in logs) {
      _cleanInvalidPath(log, 'audioFilePath');
      _cleanInvalidPath(log, 'noteFilePath');
    }

    await _mergeAndSave(books, logs, replaceExisting: replaceExisting);
  }

  /// Arşivdeki kitap kapağı dosyalarını cihaza çıkar, path'leri güncelle
  /// [skipIds] verilmişse bu ID'lerin dosyaları çıkartılmaz (merge modu)
  Future<List<Map<String, dynamic>>> _restoreBookFiles(
    List<dynamic> booksJson,
    Archive archive,
    Directory appDir, {
    Set<String>? skipIds,
  }) async {
    final coversDir = Directory('${appDir.path}/$_bookCoversDir');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final result = <Map<String, dynamic>>[];
    for (final item in booksJson) {
      final book = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final bookId = book['id'] as String?;

      // Merge modda mevcut kitapların dosyalarını çıkartma
      if (skipIds != null && bookId != null && skipIds.contains(bookId)) {
        result.add(book);
        continue;
      }

      final relativePath = book['coverImagePath'] as String?;
      if (relativePath != null && relativePath.isNotEmpty && !relativePath.startsWith('/')) {
        final archiveFile = archive.findFile(relativePath);
        if (archiveFile != null) {
          final safeName = p.basename(relativePath);
          final targetPath = '${coversDir.path}/$safeName';
          await File(targetPath).writeAsBytes(archiveFile.content as List<int>);
          book['coverImagePath'] = targetPath;
        } else {
          book['coverImagePath'] = null;
        }
      }
      result.add(book);
    }
    return result;
  }

  /// Arşivdeki ses kayıtları ve not dosyalarını cihaza çıkar, path'leri güncelle
  /// [skipIds] verilmişse bu ID'lerin dosyaları çıkartılmaz (merge modu)
  Future<List<Map<String, dynamic>>> _restoreLogFiles(
    List<dynamic> logsJson,
    Archive archive,
    Directory appDir, {
    Set<String>? skipIds,
  }) async {
    final recordingsDir = Directory('${appDir.path}/$_recordingsDir');
    final notesDir = Directory('${appDir.path}/$_notesDir');
    if (!await recordingsDir.exists()) await recordingsDir.create(recursive: true);
    if (!await notesDir.exists()) await notesDir.create(recursive: true);

    final result = <Map<String, dynamic>>[];
    for (final item in logsJson) {
      final log = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final logId = log['id'] as String?;

      // Merge modda mevcut logların dosyalarını çıkartma
      if (skipIds != null && logId != null && skipIds.contains(logId)) {
        result.add(log);
        continue;
      }

      // Ses kaydı
      final audioRelative = log['audioFilePath'] as String?;
      if (audioRelative != null && audioRelative.isNotEmpty && !audioRelative.startsWith('/')) {
        final archiveFile = archive.findFile(audioRelative);
        if (archiveFile != null) {
          final targetPath = '${recordingsDir.path}/${p.basename(audioRelative)}';
          await File(targetPath).writeAsBytes(archiveFile.content as List<int>);
          log['audioFilePath'] = targetPath;
        } else {
          log['audioFilePath'] = null;
        }
      }

      // Not dosyası
      final noteRelative = log['noteFilePath'] as String?;
      if (noteRelative != null && noteRelative.isNotEmpty && !noteRelative.startsWith('/')) {
        final archiveFile = archive.findFile(noteRelative);
        if (archiveFile != null) {
          final targetPath = '${notesDir.path}/${p.basename(noteRelative)}';
          await File(targetPath).writeAsBytes(archiveFile.content as List<int>);
          log['noteFilePath'] = targetPath;
        } else {
          log['noteFilePath'] = null;
        }
      }

      result.add(log);
    }
    return result;
  }

  /// Profil avatar dosyasını arşivden cihaza çıkar, path'i güncelle
  Future<Map<String, dynamic>> _restoreProfileFiles(
    Map<String, dynamic> profileJson,
    Archive archive,
    Directory appDir,
  ) async {
    final profile = Map<String, dynamic>.from(profileJson);
    final avatarRelative = profile['avatarImagePath'] as String?;
    if (avatarRelative != null && avatarRelative.isNotEmpty && !avatarRelative.startsWith('/')) {
      final profileImagesDir = Directory('${appDir.path}/$_profileImagesDir');
      if (!await profileImagesDir.exists()) {
        await profileImagesDir.create(recursive: true);
      }
      final archiveFile = archive.findFile(avatarRelative);
      if (archiveFile != null) {
        final targetPath = '${profileImagesDir.path}/${p.basename(avatarRelative)}';
        await File(targetPath).writeAsBytes(archiveFile.content as List<int>);
        profile['avatarImagePath'] = targetPath;
      } else {
        profile['avatarImagePath'] = null;
      }
    }
    return profile;
  }

  /// Verileri mevcut verilerle birleştir veya değiştir ve kaydet
  Future<void> _mergeAndSave(
    List<Map<String, dynamic>> books,
    List<Map<String, dynamic>> logs, {
    required bool replaceExisting,
  }) async {
    if (replaceExisting) {
      await _localStorage.saveBooks(books);
      await _localStorage.saveReadingLogs(logs);
    } else {
      final existingBooks = _localStorage.loadBooks();
      final existingLogs = _localStorage.loadReadingLogs();

      final existingBookIds = existingBooks.map((b) => b['id'] as String).toSet();
      final existingLogIds = existingLogs.map((l) => l['id'] as String).toSet();

      final mergedBooks = [
        ...existingBooks,
        ...books.where((b) => !existingBookIds.contains(b['id'] as String)),
      ];
      final mergedLogs = [
        ...existingLogs,
        ...logs.where((l) => !existingLogIds.contains(l['id'] as String)),
      ];

      await _localStorage.saveBooks(mergedBooks);
      await _localStorage.saveReadingLogs(mergedLogs);
    }
  }

  /// Yedekteki tema ayarını kanonik forma çevirip kaydeder (T1.6).
  /// Yeni yedekler `themeMode` (string), eski yedekler `isDarkMode` (bool) taşır.
  Future<void> _restoreThemeFromSettings(Object? settings) async {
    if (settings is! Map<String, dynamic>) return;
    String? mode;
    final rawMode = settings['themeMode'];
    if (rawMode is String) {
      mode = rawMode;
    } else if (settings['isDarkMode'] is bool) {
      mode = (settings['isDarkMode'] as bool) ? 'dark' : 'light';
    }
    if (mode != null) {
      await _localStorage.saveThemeModeString(mode);
    }
  }

  /// v1 JSON'lardaki mutlak dosya yollarını, dosya yoksa null yap
  void _cleanInvalidPaths(List<Map<String, dynamic>> items, String key) {
    for (final item in items) {
      _cleanInvalidPath(item, key);
    }
  }

  void _cleanInvalidPath(Map<String, dynamic> item, String key) {
    final path = item[key] as String?;
    if (path != null && path.startsWith('/')) {
      if (!File(path).existsSync()) {
        item[key] = null;
      }
    }
  }
}
