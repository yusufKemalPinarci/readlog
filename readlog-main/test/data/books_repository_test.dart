import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';

void main() {
  group('InMemoryBooksRepository', () {
    late InMemoryBooksRepository repo;

    setUp(() {
      repo = InMemoryBooksRepository();
    });

    test('başlangıçta boş liste döner', () async {
      final items = await repo.list();
      expect(items, isEmpty);
    });

    test('seed ile başlatılabilir', () async {
      repo = InMemoryBooksRepository(seed: [
        const Book(id: '1', title: 'A', author: 'X', totalPages: 100, shelf: BookShelf.toRead),
        const Book(id: '2', title: 'B', author: 'Y', totalPages: 200, shelf: BookShelf.reading),
      ]);
      final items = await repo.list();
      expect(items.length, 2);
    });

    test('upsert yeni kitap ekler', () async {
      const book = Book(id: '1', title: 'Test', author: 'A', totalPages: 100, shelf: BookShelf.toRead);
      await repo.upsert(book);
      final items = await repo.list();
      expect(items.length, 1);
      expect(items.first.title, 'Test');
    });

    test('upsert mevcut kitabı günceller', () async {
      const book = Book(id: '1', title: 'Eski', author: 'A', totalPages: 100, shelf: BookShelf.toRead);
      await repo.upsert(book);
      await repo.upsert(book.copyWith(title: 'Yeni'));
      final items = await repo.list();
      expect(items.length, 1);
      expect(items.first.title, 'Yeni');
    });

    test('getById mevcut kitabı döner', () async {
      const book = Book(id: 'abc', title: 'X', author: 'Y', totalPages: 50, shelf: BookShelf.reading);
      await repo.upsert(book);
      final found = await repo.getById('abc');
      expect(found, isNotNull);
      expect(found!.id, 'abc');
    });

    test('getById olmayan id ile null döner', () async {
      final found = await repo.getById('yok');
      expect(found, isNull);
    });

    test('delete kitabı siler', () async {
      const book = Book(id: '1', title: 'X', author: 'Y', totalPages: 50, shelf: BookShelf.toRead);
      await repo.upsert(book);
      await repo.delete('1');
      final items = await repo.list();
      expect(items, isEmpty);
    });

    test('delete olmayan id ile hata vermez', () async {
      await repo.delete('yok');
      final items = await repo.list();
      expect(items, isEmpty);
    });

    test('list orijinal listeyi döndürmez (defensive copy)', () async {
      const book = Book(id: '1', title: 'X', author: 'Y', totalPages: 50, shelf: BookShelf.toRead);
      await repo.upsert(book);
      final list1 = await repo.list();
      final list2 = await repo.list();
      expect(identical(list1, list2), false);
    });
  });
}
