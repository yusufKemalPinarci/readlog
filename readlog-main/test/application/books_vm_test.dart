import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';
import 'package:libris/features/books/application/books_vm.dart';
import 'package:libris/shared/services/local_storage_service.dart';

/// T5.6: settle async provider loads deterministically instead of the old
/// flaky Future.delayed(50ms).
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('BooksVm (in-memory)', () {
    late InMemoryBooksRepository repo;
    late BooksVm vm;

    setUp(() async {
      repo = InMemoryBooksRepository(seed: [
        const Book(id: '1', title: 'Okuyacak', author: 'A', totalPages: 200, shelf: BookShelf.toRead, order: 0),
        const Book(id: '2', title: 'Okuyor', author: 'B', totalPages: 300, shelf: BookShelf.reading, currentPage: 100, order: 1),
        const Book(id: '3', title: 'Okumuş', author: 'C', totalPages: 150, shelf: BookShelf.read, order: 2),
        const Book(id: '4', title: 'İkinci Okuyacak', author: 'D', totalPages: 100, shelf: BookShelf.toRead, order: 1),
      ]);
      vm = BooksVm(repo);
      await _settle();
    });

    test('başlangıçta kitapları yükler', () {
      expect(vm.state.items.length, 4);
      expect(vm.state.isLoading, false);
    });

    test('byShelf order a göre sıralı döner', () {
      final toRead = vm.byShelf(BookShelf.toRead);
      expect(toRead.length, 2);
      expect(toRead[0].order <= toRead[1].order, true);
    });

    test('byId', () {
      expect(vm.byId('2')!.title, 'Okuyor');
      expect(vm.byId('yok'), isNull);
    });

    test('addBook appends to toRead with a higher order', () async {
      await vm.addBook(title: 'Yeni', author: 'E', totalPages: 120);
      await _settle();
      final toRead = vm.byShelf(BookShelf.toRead);
      expect(toRead.map((b) => b.title), contains('Yeni'));
      expect(toRead.last.title, 'Yeni'); // highest order
    });

    test('markAsRead moves to read and sets fields', () async {
      await vm.markAsRead('2', finalMinutes: 90, rating: 4);
      await _settle();
      final b = vm.byId('2')!;
      expect(b.shelf, BookShelf.read);
      expect(b.currentPage, b.totalPages);
      expect(b.totalMinutes, 90);
      expect(b.rating, 4);
      expect(b.readCount, 1);
    });

    test('moveBookToShelf reading->read completes the book', () async {
      await vm.moveBookToShelf('2', BookShelf.read);
      await _settle();
      final b = vm.byId('2')!;
      expect(b.shelf, BookShelf.read);
      expect(b.currentPage, b.totalPages);
    });

    test('updateBook can clear the cover via T1.8 sentinel', () async {
      await vm.updateBook(
        id: '3', title: 'X', author: 'C', totalPages: 150, coverImagePath: null,
      );
      await _settle();
      expect(vm.byId('3')!.coverImagePath, isNull);
    });
  });

  group('LocalBooksRepository persistence (T5.6)', () {
    test('upsert persists and a fresh repo reloads it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final repo = LocalBooksRepository(storage);
      await repo.upsert(const Book(
        id: 'x', title: 'Persisted', author: 'A', totalPages: 100, shelf: BookShelf.toRead,
      ));

      // A new repo instance sees the persisted book.
      final fresh = LocalBooksRepository(storage);
      final books = await fresh.list();
      expect(books.single.title, 'Persisted');
    });

    test('upsertAll persists the whole batch once', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalBooksRepository(LocalStorageService(prefs));
      await repo.upsertAll(const [
        Book(id: 'a', title: 'A', author: 'x', totalPages: 10, shelf: BookShelf.toRead, order: 0),
        Book(id: 'b', title: 'B', author: 'x', totalPages: 10, shelf: BookShelf.toRead, order: 1),
      ]);
      final books = await repo.list();
      expect(books.map((b) => b.id).toList()..sort(), ['a', 'b']);
    });
  });
}
