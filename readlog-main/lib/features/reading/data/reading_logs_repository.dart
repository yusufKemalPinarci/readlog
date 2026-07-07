import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/reading_log.dart';
import '../../../shared/services/note_storage_service.dart';
import '../../../shared/services/local_storage_service.dart';

/// T2.6: a log counts as "today" from midnight (inclusive) to the next
/// midnight (exclusive). Uses DateTime(y,m,d±1) to stay DST-safe. Shared by
/// both repository implementations so they can't drift.
bool _hasLogOnDay(List<ReadingLog> items, DateTime dayStart) {
  final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
  return items.any((log) => !log.date.isBefore(dayStart) && log.date.isBefore(dayEnd));
}

/// T2.3: delete every on-disk asset a log owns (note file, audio, note image).
Future<void> _deleteLogAssets(NoteStorageService noteService, ReadingLog log) async {
  await noteService.deleteNote(log.id);

  if (log.audioFilePath != null) {
    try {
      final file = File(log.audioFilePath!);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ses kaydı silinemezse devam et
    }
  }

  if (log.noteFilePath != null) {
    try {
      final file = File(log.noteFilePath!);
      if (await file.exists()) {
        final ext = log.noteFilePath!.toLowerCase();
        if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
          await file.delete();
        }
      }
    } catch (_) {
      // Resim silinemezse devam et
    }
  }
}

abstract class ReadingLogsRepository {
  Future<List<ReadingLog>> listByBookId(String bookId);
  Future<List<ReadingLog>> listAll();
  Future<void> add(ReadingLog log);
  Future<ReadingLog?> getById(String id);
  Future<void> update(ReadingLog log);
  Future<void> delete(String id);
  Future<void> deleteByBookId(String bookId);
  Future<bool> hasCompletedReadingToday();

  /// Re-read from the backing store (T2.4: after a backup import).
  Future<void> reload();
}

class InMemoryReadingLogsRepository implements ReadingLogsRepository {
  // T4.5: a true test double — pure in-memory, no NoteStorageService file I/O.
  // Notes live on the ReadingLog objects themselves.
  InMemoryReadingLogsRepository({List<ReadingLog>? seed}) : _items = [...?seed];

  final List<ReadingLog> _items;

  @override
  Future<List<ReadingLog>> listByBookId(String bookId) async =>
      _items.where((x) => x.bookId == bookId).toList(growable: false);

  @override
  Future<List<ReadingLog>> listAll() async => List<ReadingLog>.from(_items);

  @override
  Future<void> add(ReadingLog log) async => _items.add(log);

  @override
  Future<ReadingLog?> getById(String id) async {
    for (final log in _items) {
      if (log.id == id) return log;
    }
    return null;
  }

  @override
  Future<void> update(ReadingLog log) async {
    final index = _items.indexWhere((x) => x.id == log.id);
    if (index >= 0) _items[index] = log;
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((x) => x.id == id);

  @override
  Future<void> deleteByBookId(String bookId) async =>
      _items.removeWhere((x) => x.bookId == bookId);

  @override
  Future<bool> hasCompletedReadingToday() async {
    final now = DateTime.now();
    return _hasLogOnDay(_items, DateTime(now.year, now.month, now.day));
  }

  @override
  Future<void> reload() async {}
}

class LocalReadingLogsRepository implements ReadingLogsRepository {
  LocalReadingLogsRepository(this._storage)
      : _noteService = NoteStorageService() {
    _init();
  }

  final LocalStorageService _storage;
  final NoteStorageService _noteService;
  List<ReadingLog> _items = [];

  /// True when storage exists but couldn't be decoded; repo goes read-only (T1.4).
  bool _corrupt = false;
  bool get isCorrupt => _corrupt;

  void _init() {
    _reload();
  }

  void _reload() {
    try {
      final storedData = _storage.loadReadingLogs();
      _corrupt = false;
      // T2.4: assign unconditionally so empty storage clears the list.
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
    } on StorageCorruptionException catch (e) {
      _corrupt = true;
      debugPrint('LocalReadingLogsRepository: storage corrupt, entering read-only. $e');
    }
  }

  /// Verileri storage'dan yeniden yükle (import sonrası kullanılır)
  @override
  Future<void> reload() async {
    _reload();
  }

  Future<void> _save() async {
    if (_corrupt) {
      debugPrint('LocalReadingLogsRepository: refusing to save over corrupt storage.');
      return;
    }
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
    // T2.3: also delete the log's audio/note-image, not just the note file.
    final index = _items.indexWhere((x) => x.id == id);
    if (index < 0) return;
    await _deleteLogAssets(_noteService, _items[index]);
    _items.removeAt(index);
    await _save();
  }

  @override
  Future<void> deleteByBookId(String bookId) async {
    final logsToDelete = _items.where((x) => x.bookId == bookId).toList();
    for (final log in logsToDelete) {
      await _deleteLogAssets(_noteService, log);
    }
    _items.removeWhere((x) => x.bookId == bookId);
    await _save();
  }

  @override
  Future<bool> hasCompletedReadingToday() async {
    final now = DateTime.now();
    return _hasLogOnDay(_items, DateTime(now.year, now.month, now.day));
  }
}
