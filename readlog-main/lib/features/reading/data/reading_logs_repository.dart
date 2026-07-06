import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/reading_log.dart';
import '../../../shared/services/note_storage_service.dart';
import '../../../shared/services/local_storage_service.dart';

abstract class ReadingLogsRepository {
  Future<List<ReadingLog>> listByBookId(String bookId);
  Future<List<ReadingLog>> listAll();
  Future<void> add(ReadingLog log);
  Future<ReadingLog?> getById(String id);
  Future<void> update(ReadingLog log);
  Future<void> delete(String id);
  Future<void> deleteByBookId(String bookId);
  Future<bool> hasCompletedReadingToday();
}

class InMemoryReadingLogsRepository implements ReadingLogsRepository {
  InMemoryReadingLogsRepository({List<ReadingLog>? seed}) 
      : _items = [...?seed],
        _noteService = NoteStorageService();

  final List<ReadingLog> _items;
  final NoteStorageService _noteService;

  @override
  Future<List<ReadingLog>> listByBookId(String bookId) async {
    final logs = _items.where((x) => x.bookId == bookId).toList(growable: false);
    // Her log için notu dosyadan yükle
    final logsWithNotes = await Future.wait(
      logs.map((log) => _loadNoteFromFile(log)),
    );
    return logsWithNotes;
  }

  @override
  Future<List<ReadingLog>> listAll() async {
    // Her log için notu dosyadan yükle
    final logsWithNotes = await Future.wait(
      _items.map((log) => _loadNoteFromFile(log)),
    );
    return logsWithNotes;
  }

  @override
  Future<void> add(ReadingLog log) async {
    ReadingLog logToSave = log;
    
    // Not varsa dosyaya kaydet
    if (log.note != null && log.note!.trim().isNotEmpty) {
      await _noteService.saveNote(log.id, log.note!);
      // Eğer noteFilePath zaten varsa (resim için ayarlanmış), onu koru
      // Yoksa metin notu için yeni bir yol oluştur
      if (log.noteFilePath == null) {
        final noteFilePath = await _noteService.getNoteFilePath(log.id);
        logToSave = log.copyWith(noteFilePath: noteFilePath);
      }
    }
    
    _items.add(logToSave);
  }

  @override
  Future<ReadingLog?> getById(String id) async {
    try {
      final log = _items.firstWhere((x) => x.id == id);
      // Not dosyasından oku (eğer varsa)
      return await _loadNoteFromFile(log);
    } catch (_) {
      return null;
    }
  }

  /// Notu dosyadan yükle
  Future<ReadingLog> _loadNoteFromFile(ReadingLog log) async {
    // Eğer noteFilePath varsa, dosyadan oku
    if (log.noteFilePath != null) {
      final note = await _noteService.readNote(log.id);
      if (note != null) {
        return ReadingLog(
          id: log.id,
          bookId: log.bookId,
          date: log.date,
          minutes: log.minutes,
          durationSeconds: log.durationSeconds,
          pageAtEnd: log.pageAtEnd,
          note: note,
          audioFilePath: log.audioFilePath,
          noteFilePath: log.noteFilePath,
        );
      }
    }
    return log;
  }

  @override
  Future<void> update(ReadingLog log) async {
    final index = _items.indexWhere((x) => x.id == log.id);
    if (index >= 0) {
      ReadingLog logToUpdate = log;
      
      // Not varsa dosyaya kaydet
      if (log.note != null && log.note!.trim().isNotEmpty) {
        await _noteService.saveNote(log.id, log.note!);
        // Eğer noteFilePath zaten varsa (resim için ayarlanmış), onu koru
        // Yoksa metin notu için yeni bir yol oluştur
        if (log.noteFilePath == null) {
          final noteFilePath = await _noteService.getNoteFilePath(log.id);
          logToUpdate = log.copyWith(noteFilePath: noteFilePath);
        }
      } else {
        // Not yoksa metin notu dosyasını sil, ama resim varsa onu koru
        await _noteService.deleteNote(log.id);
        // Eğer resim yoksa noteFilePath'i null yap
        if (log.noteFilePath == null) {
          logToUpdate = log.copyWith(note: null, noteFilePath: null);
        } else {
          // Resim varsa sadece note'u null yap
          logToUpdate = log.copyWith(note: null);
        }
      }
      
      _items[index] = logToUpdate;
    }
  }

  @override
  Future<void> delete(String id) async {
    // Not dosyasını sil
    await _noteService.deleteNote(id);
    _items.removeWhere((x) => x.id == id);
  }

  @override
  Future<void> deleteByBookId(String bookId) async {
    // Bu kitaba ait tüm kayıtları bul
    final logsToDelete = _items.where((x) => x.bookId == bookId).toList();
    
    // Her kayıt için not dosyasını ve ses kaydını sil
    for (final log in logsToDelete) {
      // Not dosyasını sil
      await _noteService.deleteNote(log.id);
      
      // Ses kaydı dosyasını sil
      if (log.audioFilePath != null) {
        try {
          final file = File(log.audioFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ses kaydı silinirken hata oluşursa devam et
        }
      }
      
      // Resim dosyasını sil (noteFilePath resim içeriyorsa)
      if (log.noteFilePath != null) {
        try {
          final file = File(log.noteFilePath!);
          if (await file.exists()) {
            // Sadece resim dosyası ise sil (not dosyası değilse)
            final extension = log.noteFilePath!.toLowerCase();
            if (extension.endsWith('.jpg') || 
                extension.endsWith('.jpeg') || 
                extension.endsWith('.png')) {
              await file.delete();
            }
          }
        } catch (e) {
          // Resim silinirken hata oluşursa devam et
        }
      }
    }
    
    // Kayıtları listeden çıkar
    _items.removeWhere((x) => x.bookId == bookId);
  }

  @override
  Future<bool> hasCompletedReadingToday() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    // Bugün oluşturulan kayıtlar var mı kontrol et
    return _items.any((log) {
      return log.date.isAfter(todayStart) && log.date.isBefore(todayEnd);
    });
  }
}

class LocalReadingLogsRepository implements ReadingLogsRepository {
  LocalReadingLogsRepository(this._storage)
      : _noteService = NoteStorageService() {
    _init();
  }

  final LocalStorageService _storage;
  final NoteStorageService _noteService;
  List<ReadingLog> _items = [];

  void _init() {
    _reload();
  }

  void _reload() {
    final storedData = _storage.loadReadingLogs();
    if (storedData.isNotEmpty) {
      final parsed = <ReadingLog>[];
      var skipped = 0;
      for (final json in storedData) {
        final log = ReadingLog.tryParse(json);
        if (log != null) {
          parsed.add(log);
        } else {
          skipped++;
        }
      }
      if (skipped > 0) {
        debugPrint('LocalReadingLogsRepository: skipped $skipped unparseable log record(s).');
      }
      _items = parsed;
    }
  }

  /// Verileri storage'dan yeniden yükle (import sonrası kullanılır)
  Future<void> reload() async {
    _reload();
  }

  Future<void> _save() async {
    final logsJson = _items.map((l) => l.toJson()).toList();
    await _storage.saveReadingLogs(logsJson);
  }

  // Notu dosyadan yükle
  Future<ReadingLog> _loadNoteFromFile(ReadingLog log) async {
    if (log.noteFilePath != null) {
      final note = await _noteService.readNote(log.id);
      if (note != null) {
        return log.copyWith(note: note);
      }
    }
    return log;
  }

  @override
  Future<List<ReadingLog>> listByBookId(String bookId) async {
    final logs = _items.where((x) => x.bookId == bookId).toList(growable: false);
    return await Future.wait(logs.map((log) => _loadNoteFromFile(log)));
  }

  @override
  Future<List<ReadingLog>> listAll() async {
    return await Future.wait(_items.map((log) => _loadNoteFromFile(log)));
  }

  @override
  Future<void> add(ReadingLog log) async {
    ReadingLog logToSave = log;
    
    // Not varsa dosyaya kaydet
    if (log.note != null && log.note!.trim().isNotEmpty) {
      await _noteService.saveNote(log.id, log.note!);
      // Eğer noteFilePath zaten varsa (resim için ayarlanmış), onu koru
      // Yoksa metin notu için yeni bir yol oluştur
      if (log.noteFilePath == null) {
        final noteFilePath = await _noteService.getNoteFilePath(log.id);
        logToSave = log.copyWith(noteFilePath: noteFilePath);
      }
    }

    _items.add(logToSave);
    await _save();
  }

  @override
  Future<ReadingLog?> getById(String id) async {
    try {
      final log = _items.firstWhere((x) => x.id == id);
      return await _loadNoteFromFile(log);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> update(ReadingLog log) async {
    final index = _items.indexWhere((x) => x.id == log.id);
    if (index >= 0) {
      ReadingLog logToUpdate = log;
      
      if (log.note != null && log.note!.trim().isNotEmpty) {
        await _noteService.saveNote(log.id, log.note!);
        // Eğer noteFilePath zaten varsa (resim için ayarlanmış), onu koru
        // Yoksa metin notu için yeni bir yol oluştur
        if (log.noteFilePath == null) {
          final noteFilePath = await _noteService.getNoteFilePath(log.id);
          logToUpdate = log.copyWith(noteFilePath: noteFilePath);
        }
      } else {
        // Not yoksa metin notu dosyasını sil, ama resim varsa onu koru
        await _noteService.deleteNote(log.id);
        // Eğer resim yoksa noteFilePath'i null yap
        if (log.noteFilePath == null) {
          logToUpdate = log.copyWith(note: null, noteFilePath: null);
        } else {
          // Resim varsa sadece note'u null yap
          logToUpdate = log.copyWith(note: null);
        }
      }

      _items[index] = logToUpdate;
      await _save();
    }
  }

  @override
  Future<void> delete(String id) async {
    await _noteService.deleteNote(id);
    _items.removeWhere((x) => x.id == id);
    await _save();
  }

  @override
  Future<void> deleteByBookId(String bookId) async {
    // Bu kitaba ait tüm kayıtları bul
    final logsToDelete = _items.where((x) => x.bookId == bookId).toList();
    
    // Her kayıt için not dosyasını ve ses kaydını sil
    for (final log in logsToDelete) {
      // Not dosyasını sil
      await _noteService.deleteNote(log.id);
      
      // Ses kaydı dosyasını sil
      if (log.audioFilePath != null) {
        try {
          final file = File(log.audioFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ses kaydı silinirken hata oluşursa devam et
        }
      }
      
      // Resim dosyasını sil (noteFilePath resim içeriyorsa)
      if (log.noteFilePath != null) {
        try {
          final file = File(log.noteFilePath!);
          if (await file.exists()) {
            // Sadece resim dosyası ise sil (not dosyası değilse)
            final extension = log.noteFilePath!.toLowerCase();
            if (extension.endsWith('.jpg') || 
                extension.endsWith('.jpeg') || 
                extension.endsWith('.png')) {
              await file.delete();
            }
          }
        } catch (e) {
          // Resim silinirken hata oluşursa devam et
        }
      }
    }
    
    // Kayıtları listeden çıkar
    _items.removeWhere((x) => x.bookId == bookId);
    await _save();
  }

  @override
  Future<bool> hasCompletedReadingToday() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return _items.any((log) => log.date.isAfter(todayStart) && log.date.isBefore(todayEnd));
  }
}
