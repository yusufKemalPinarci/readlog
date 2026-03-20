import 'package:flutter_test/flutter_test.dart';
import 'package:berber/features/books/domain/book.dart';
import 'package:berber/features/books/data/books_repository.dart';
import 'package:berber/features/books/application/books_vm.dart';

void main() {
  group('BooksVm', () {
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
      // İlk yükleme tamamlanana kadar bekle
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('başlangıçta kitapları yükler', () {
      expect(vm.state.items.length, 4);
      expect(vm.state.isLoading, false);
    });

    test('byShelf doğru kitapları filtreler', () {
      final toRead = vm.byShelf(BookShelf.toRead);
      expect(toRead.length, 2);
      expect(toRead.every((b) => b.shelf == BookShelf.toRead), true);
    });

    test('byShelf order a göre sıralı döner', () {
      final toRead = vm.byShelf(BookShelf.toRead);
      expect(toRead[0].order <= toRead[1].order, true);
    });

    test('byId mevcut kitabı döner', () {
      final book = vm.byId('2');
      expect(book, isNotNull);
      expect(book!.title, 'Okuyor');
    });

    test('byId olmayan id ile null döner', () {
      expect(vm.byId('yok'), isNull);
    });
  });

  group('BooksState', () {
    test('copyWith items günceller', () {
      const state = BooksState(items: []);
      final updated = state.copyWith(items: [
        const Book(id: '1', title: 'X', author: 'Y', totalPages: 100, shelf: BookShelf.toRead),
      ]);
      expect(updated.items.length, 1);
      expect(updated.isLoading, false);
    });

    test('copyWith isLoading günceller', () {
      const state = BooksState(items: []);
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, true);
      expect(updated.items, isEmpty);
    });

    test('copyWith parametresiz aynı değerleri korur', () {
      final items = [
        const Book(id: '1', title: 'X', author: 'Y', totalPages: 100, shelf: BookShelf.toRead),
      ];
      final state = BooksState(items: items, isLoading: true);
      final copied = state.copyWith();
      expect(copied.items, items);
      expect(copied.isLoading, true);
    });
  });
}
