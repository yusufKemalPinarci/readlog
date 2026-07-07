import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/reading/domain/reading_log.dart';

void main() {
  group('Book.copyWith sentinels (T1.8)', () {
    const book = Book(
      id: '1',
      title: 'T',
      author: 'A',
      totalPages: 100,
      shelf: BookShelf.read,
      currentPage: 100,
      totalMinutes: 90,
      coverImagePath: '/covers/cover_1.jpg',
      review: 'good',
      rating: 4,
    );

    test('omitting a nullable field keeps it', () {
      final copy = book.copyWith(title: 'New');
      expect(copy.title, 'New');
      expect(copy.coverImagePath, '/covers/cover_1.jpg');
      expect(copy.review, 'good');
      expect(copy.rating, 4);
      expect(copy.totalMinutes, 90);
    });

    test('passing null clears coverImagePath (Resmi Kaldır)', () {
      final copy = book.copyWith(coverImagePath: null);
      expect(copy.coverImagePath, isNull);
      expect(copy.title, 'T'); // untouched
    });

    test('passing null clears rating and review', () {
      final copy = book.copyWith(rating: null, review: null);
      expect(copy.rating, isNull);
      expect(copy.review, isNull);
    });

    test('passing a value sets it', () {
      final copy = book.copyWith(coverImagePath: '/covers/new.jpg', rating: 5);
      expect(copy.coverImagePath, '/covers/new.jpg');
      expect(copy.rating, 5);
    });
  });

  group('ReadingLog.copyWith sentinels (T1.8)', () {
    final log = ReadingLog(
      id: '1',
      bookId: 'b1',
      date: DateTime(2026, 1, 1),
      minutes: 30,
      pageAtEnd: 50,
      durationSeconds: 1800,
      title: 'Session',
      note: 'a note',
      audioFilePath: '/audio/a.m4a',
      noteFilePath: '/notes/n.jpg',
    );

    test('omitting fields keeps them', () {
      final copy = log.copyWith(minutes: 45);
      expect(copy.minutes, 45);
      expect(copy.title, 'Session');
      expect(copy.audioFilePath, '/audio/a.m4a');
      expect(copy.note, 'a note');
    });

    test('passing null clears audioFilePath and note', () {
      final copy = log.copyWith(audioFilePath: null, note: null);
      expect(copy.audioFilePath, isNull);
      expect(copy.note, isNull);
      expect(copy.title, 'Session'); // untouched
    });
  });
}
