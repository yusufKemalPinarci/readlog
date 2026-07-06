import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';
import 'package:libris/features/books/application/books_vm.dart';

/// Wraps InMemory repo and counts persist calls to assert batched saves (T1.9).
class _CountingRepo implements BooksRepository {
  _CountingRepo(this._inner);
  final InMemoryBooksRepository _inner;
  int upsertCalls = 0;
  int upsertAllCalls = 0;

  @override
  Future<List<Book>> list() => _inner.list();
  @override
  Future<Book?> getById(String id) => _inner.getById(id);
  @override
  Future<void> upsert(Book book) {
    upsertCalls++;
    return _inner.upsert(book);
  }

  @override
  Future<void> upsertAll(List<Book> books) {
    upsertAllCalls++;
    return _inner.upsertAll(books);
  }

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<void> reload() => _inner.reload();
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

List<Book> _seed() => [
      const Book(id: 'A', title: 'A', author: 'x', totalPages: 10, shelf: BookShelf.toRead, order: 0),
      const Book(id: 'B', title: 'B', author: 'x', totalPages: 10, shelf: BookShelf.toRead, order: 1),
      const Book(id: 'C', title: 'C', author: 'x', totalPages: 10, shelf: BookShelf.toRead, order: 2),
      const Book(id: 'D', title: 'D', author: 'x', totalPages: 10, shelf: BookShelf.toRead, order: 3),
    ];

void main() {
  group('reorderBooks (T1.9)', () {
    late _CountingRepo repo;
    late BooksVm vm;

    setUp(() async {
      repo = _CountingRepo(InMemoryBooksRepository(seed: _seed()));
      vm = BooksVm(repo);
      await _settle();
    });

    List<String> ids() => vm.byShelf(BookShelf.toRead).map((b) => b.id).toList();

    test('drag first to end lands at end (newIndex == length)', () async {
      await vm.reorderBooks(BookShelf.toRead, 0, 4); // Flutter reports length
      expect(ids(), ['B', 'C', 'D', 'A']);
    });

    test('down-drag adjusts for the removed gap', () async {
      await vm.reorderBooks(BookShelf.toRead, 0, 2); // drop after B
      expect(ids(), ['B', 'A', 'C', 'D']);
    });

    test('up-drag needs no adjustment', () async {
      await vm.reorderBooks(BookShelf.toRead, 3, 0);
      expect(ids(), ['D', 'A', 'B', 'C']);
    });

    test('invalid oldIndex is a no-op', () async {
      await vm.reorderBooks(BookShelf.toRead, 10, 0);
      expect(ids(), ['A', 'B', 'C', 'D']);
    });

    test('persists as a single batched save, not one per book', () async {
      repo.upsertAllCalls = 0;
      repo.upsertCalls = 0;
      await vm.reorderBooks(BookShelf.toRead, 0, 4);
      expect(repo.upsertAllCalls, 1);
      expect(repo.upsertCalls, 0);
    });
  });
}
