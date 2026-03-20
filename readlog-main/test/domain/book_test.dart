import 'package:flutter_test/flutter_test.dart';
import 'package:berber/features/books/domain/book.dart';

void main() {
  group('Book', () {
    const book = Book(
      id: '1',
      title: 'Test Kitap',
      author: 'Yazar',
      totalPages: 300,
      shelf: BookShelf.reading,
      currentPage: 150,
      totalMinutes: 120,
      category: 'Roman',
      readCount: 1,
      order: 0,
      coverImagePath: '/path/cover.jpg',
      review: 'Harika bir kitap',
      rating: 5,
      finalReadingTimeMinutes: 180,
    );

    test('progress hesaplanır', () {
      expect(book.progress, 0.5);
    });

    test('progress 0 sayfa ile 0 döner', () {
      final b = book.copyWith(currentPage: 0);
      expect(b.progress, 0.0);
    });

    test('progress totalPages=0 ile 0 döner', () {
      const b = Book(
        id: '2',
        title: 'X',
        author: 'Y',
        totalPages: 0,
        shelf: BookShelf.toRead,
      );
      expect(b.progress, 0.0);
    });

    test('progress 1 i aşmaz', () {
      final b = book.copyWith(currentPage: 500);
      expect(b.progress, 1.0);
    });

    test('currentPage null iken progress 0 döner', () {
      const b = Book(
        id: '3',
        title: 'X',
        author: 'Y',
        totalPages: 100,
        shelf: BookShelf.toRead,
      );
      expect(b.progress, 0.0);
    });

    test('copyWith tüm alanları günceller', () {
      final updated = book.copyWith(
        title: 'Yeni Başlık',
        author: 'Yeni Yazar',
        totalPages: 500,
        shelf: BookShelf.read,
        currentPage: 500,
        rating: 4,
      );
      expect(updated.title, 'Yeni Başlık');
      expect(updated.author, 'Yeni Yazar');
      expect(updated.totalPages, 500);
      expect(updated.shelf, BookShelf.read);
      expect(updated.currentPage, 500);
      expect(updated.rating, 4);
      // Değişmeyen alanlar aynı kalır
      expect(updated.id, '1');
      expect(updated.review, 'Harika bir kitap');
    });

    test('toJson doğru map üretir', () {
      final json = book.toJson();
      expect(json['id'], '1');
      expect(json['title'], 'Test Kitap');
      expect(json['author'], 'Yazar');
      expect(json['totalPages'], 300);
      expect(json['shelf'], BookShelf.reading.index);
      expect(json['currentPage'], 150);
      expect(json['totalMinutes'], 120);
      expect(json['category'], 'Roman');
      expect(json['readCount'], 1);
      expect(json['order'], 0);
      expect(json['coverImagePath'], '/path/cover.jpg');
      expect(json['review'], 'Harika bir kitap');
      expect(json['rating'], 5);
      expect(json['finalReadingTimeMinutes'], 180);
    });

    test('fromJson doğru Book üretir', () {
      final json = book.toJson();
      final parsed = Book.fromJson(json);
      expect(parsed.id, book.id);
      expect(parsed.title, book.title);
      expect(parsed.author, book.author);
      expect(parsed.totalPages, book.totalPages);
      expect(parsed.shelf, book.shelf);
      expect(parsed.currentPage, book.currentPage);
      expect(parsed.totalMinutes, book.totalMinutes);
      expect(parsed.category, book.category);
      expect(parsed.readCount, book.readCount);
      expect(parsed.order, book.order);
      expect(parsed.coverImagePath, book.coverImagePath);
      expect(parsed.review, book.review);
      expect(parsed.rating, book.rating);
      expect(parsed.finalReadingTimeMinutes, book.finalReadingTimeMinutes);
    });

    test('fromJson null alanlarla çalışır', () {
      final json = {
        'id': 'x',
        'title': 'X',
        'author': 'Y',
        'totalPages': 100,
        'shelf': 0,
      };
      final parsed = Book.fromJson(json);
      expect(parsed.currentPage, isNull);
      expect(parsed.totalMinutes, isNull);
      expect(parsed.category, isNull);
      expect(parsed.readCount, 0);
      expect(parsed.order, 0);
      expect(parsed.coverImagePath, isNull);
      expect(parsed.review, isNull);
      expect(parsed.rating, isNull);
    });

    test('toJson -> fromJson roundtrip', () {
      final reconstructed = Book.fromJson(book.toJson());
      expect(reconstructed.id, book.id);
      expect(reconstructed.title, book.title);
      expect(reconstructed.totalPages, book.totalPages);
      expect(reconstructed.shelf, book.shelf);
      expect(reconstructed.progress, book.progress);
    });
  });

  group('BookShelf', () {
    test('3 tane raf vardır', () {
      expect(BookShelf.values.length, 3);
    });

    test('index değerleri doğru', () {
      expect(BookShelf.toRead.index, 0);
      expect(BookShelf.reading.index, 1);
      expect(BookShelf.read.index, 2);
    });
  });
}
