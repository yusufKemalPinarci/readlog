import '../domain/book.dart';
import '../../../shared/services/local_storage_service.dart';

abstract class BooksRepository {
  Future<List<Book>> list();
  Future<Book?> getById(String id);
  Future<void> upsert(Book book);
  Future<void> delete(String id);
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
  Future<void> delete(String id) async {
    _items.removeWhere((b) => b.id == id);
  }
}

class LocalBooksRepository implements BooksRepository {
  LocalBooksRepository(this._storage, {List<Book>? seed}) {
    _init(seed);
  }

  final LocalStorageService _storage;
  List<Book> _items = [];

  void _init(List<Book>? seed) {
    _reload(seed);
  }

  void _reload(List<Book>? seed) {
    final storedData = _storage.loadBooks();
    if (storedData.isNotEmpty) {
      _items = storedData.map((json) => Book.fromJson(json)).toList();
    } else if (seed != null) {
      _items = [...seed];
      _save();
    }
  }

  /// Verileri storage'dan yeniden yükle (import sonrası kullanılır)
  Future<void> reload() async {
    _reload(null);
  }

  Future<void> _save() async {
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
  Future<void> delete(String id) async {
    _items.removeWhere((b) => b.id == id);
    await _save();
  }
}



