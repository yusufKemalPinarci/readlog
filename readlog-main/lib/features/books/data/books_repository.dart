import 'package:flutter/foundation.dart';

import '../domain/book.dart';
import '../../../shared/services/local_storage_service.dart';

abstract class BooksRepository {
  Future<List<Book>> list();
  Future<Book?> getById(String id);
  Future<void> upsert(Book book);

  /// Upserts many books with a single persist (T1.9: batched reorder save).
  Future<void> upsertAll(List<Book> books);
  Future<void> delete(String id);

  /// Re-read from the backing store (T2.4: called after a backup import so the
  /// app-lifetime singleton repo reflects the new data without being recreated).
  Future<void> reload();
}

class InMemoryBooksRepository implements BooksRepository {
  InMemoryBooksRepository({List<Book>? seed}) : _items = [...?seed];

  final List<Book> _items;

  @override
  Future<List<Book>> list() async => [..._items];

  @override
  Future<Book?> getById(String id) async {
    for (final b in _items) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<void> upsert(Book book) async {
    final index = _items.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      _items[index] = book;
    } else {
      _items.add(book);
    }
  }

  @override
  Future<void> upsertAll(List<Book> books) async {
    for (final book in books) {
      final index = _items.indexWhere((b) => b.id == book.id);
      if (index >= 0) {
        _items[index] = book;
      } else {
        _items.add(book);
      }
    }
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> reload() async {
    // In-memory test double: nothing to re-read.
  }
}

class LocalBooksRepository implements BooksRepository {
  LocalBooksRepository(this._storage) {
    _init();
  }

  final LocalStorageService _storage;
  List<Book> _items = [];

  /// True when storage exists but couldn't be decoded. The repo goes read-only
  /// so a save can't overwrite (and wipe) the corrupt-but-present data (T1.4).
  bool _corrupt = false;
  bool get isCorrupt => _corrupt;

  void _init() {
    _reload();
  }

  void _reload() {
    try {
      final storedData = _storage.loadBooks();
      _corrupt = false;
      // T2.4: assign unconditionally — empty storage means an empty library
      // (e.g. after an import that removed books), not "keep the old items".
      final parsed = <Book>[];
      var skipped = 0;
      for (final json in storedData) {
        final book = Book.tryParse(json);
        if (book != null) {
          parsed.add(book);
        } else {
          skipped++;
        }
      }
      if (skipped > 0) {
        debugPrint('LocalBooksRepository: skipped $skipped unparseable book record(s).');
      }
      _items = parsed;
    } on StorageCorruptionException catch (e) {
      _corrupt = true;
      debugPrint('LocalBooksRepository: storage corrupt, entering read-only. $e');
      // Do NOT touch _items; never wipe the (backed-up) corrupt blob.
    }
  }

  /// Verileri storage'dan yeniden yükle (import sonrası kullanılır)
  @override
  Future<void> reload() async {
    _reload();
  }

  Future<void> _save() async {
    if (_corrupt) {
      debugPrint('LocalBooksRepository: refusing to save over corrupt storage.');
      return;
    }
    final booksJson = _items.map((b) => b.toJson()).toList();
    await _storage.saveBooks(booksJson);
  }

  @override
  Future<List<Book>> list() async => [..._items];

  @override
  Future<Book?> getById(String id) async {
    try {
      return _items.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Book book) async {
    final index = _items.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      _items[index] = book;
    } else {
      _items.add(book);
    }
    await _save();
  }

  @override
  Future<void> upsertAll(List<Book> books) async {
    for (final book in books) {
      final index = _items.indexWhere((b) => b.id == book.id);
      if (index >= 0) {
        _items[index] = book;
      } else {
        _items.add(book);
      }
    }
    await _save(); // single persist for the whole batch
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((b) => b.id == id);
    await _save();
  }
}



