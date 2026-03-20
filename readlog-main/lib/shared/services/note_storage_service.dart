import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NoteStorageService {
  static const String _notesDirectoryName = 'notes';

  /// Notlar için dizin yolunu al
  Future<Directory> _getNotesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${appDir.path}/$_notesDirectoryName');
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    return notesDir;
  }

  /// Not dosyası yolunu al
  Future<String> getNoteFilePath(String logId) async {
    final notesDir = await _getNotesDirectory();
    return '${notesDir.path}/note_$logId.txt';
  }

  /// Notu dosyaya kaydet
  Future<void> saveNote(String logId, String note) async {
    if (note.trim().isEmpty) {
      // Not boşsa dosyayı sil
      await deleteNote(logId);
      return;
    }

    final filePath = await getNoteFilePath(logId);
    final file = File(filePath);
    await file.writeAsString(note, encoding: const SystemEncoding());
  }

  /// Notu dosyadan oku
  Future<String?> readNote(String logId) async {
    final filePath = await getNoteFilePath(logId);
    final file = File(filePath);
    
    if (!await file.exists()) {
      return null;
    }

    try {
      return await file.readAsString(encoding: const SystemEncoding());
    } catch (e) {
      return null;
    }
  }

  /// Not dosyasını sil
  Future<void> deleteNote(String logId) async {
    final filePath = await getNoteFilePath(logId);
    final file = File(filePath);
    
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        // Dosya silme hatası görmezden gel
      }
    }
  }

  /// Not dosyasının var olup olmadığını kontrol et
  Future<bool> noteExists(String logId) async {
    final filePath = await getNoteFilePath(logId);
    final file = File(filePath);
    return await file.exists();
  }
}

