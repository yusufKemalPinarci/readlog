import 'dart:convert';
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
    // T4.10: explicit UTF-8 so Turkish characters aren't mangled by the
    // platform's default SystemEncoding.
    await file.writeAsString(note, encoding: utf8);
  }

  /// Notu dosyadan oku. Dosya yoksa null döner (eksik not); dosya varsa ama
  /// çözümlenemezse legacy kodlama için hoşgörülü çözümleme dener (T4.10).
  Future<String?> readNote(String logId) async {
    final filePath = await getNoteFilePath(logId);
    final file = File(filePath);

    if (!await file.exists()) {
      return null; // genuinely missing
    }

    try {
      return await file.readAsString(encoding: utf8);
    } catch (_) {
      // Decode failure (e.g. a note written by an older SystemEncoding build):
      // read raw bytes and decode leniently instead of losing the note.
      try {
        return utf8.decode(await file.readAsBytes(), allowMalformed: true);
      } catch (_) {
        return null;
      }
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

