import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';
import 'package:libris/features/reading/domain/reading_log.dart';
import 'package:libris/features/reading/data/reading_logs_repository.dart';
import 'package:libris/features/profile/domain/user_profile.dart';
import 'package:libris/shared/services/local_storage_service.dart';
import 'package:libris/shared/utils/json_parse.dart';

void main() {
  group('json_parse helpers (T1.3)', () {
    test('asIntOrNull coerces types', () {
      expect(asIntOrNull(5), 5);
      expect(asIntOrNull(5.7), 6);
      expect(asIntOrNull('42'), 42);
      expect(asIntOrNull('3.5'), 4);
      expect(asIntOrNull('abc'), isNull);
      expect(asIntOrNull(null), isNull);
    });

    test('enumByIndex clamps out-of-range to fallback', () {
      expect(enumByIndex(BookShelf.values, 1, BookShelf.toRead), BookShelf.reading);
      expect(enumByIndex(BookShelf.values, 7, BookShelf.toRead), BookShelf.toRead);
      expect(enumByIndex(BookShelf.values, -1, BookShelf.toRead), BookShelf.toRead);
      expect(enumByIndex(BookShelf.values, null, BookShelf.toRead), BookShelf.toRead);
    });

    test('asDateOr falls back on garbage', () {
      final fb = DateTime(2000);
      expect(asDateOr('2026-01-02T03:04:05.000', fb), DateTime.parse('2026-01-02T03:04:05.000'));
      expect(asDateOr('not-a-date', fb), fb);
      expect(asDateOr(null, fb), fb);
    });
  });

  group('Book.tryParse (T1.3)', () {
    test('valid record parses', () {
      final b = Book.tryParse({
        'id': '1', 'title': 'T', 'author': 'A', 'totalPages': 100, 'shelf': 2,
      });
      expect(b, isNotNull);
      expect(b!.shelf, BookShelf.read);
    });

    test('out-of-range shelf clamps to toRead, does not throw', () {
      final b = Book.tryParse({
        'id': '1', 'title': 'T', 'author': 'A', 'totalPages': 100, 'shelf': 7,
      });
      expect(b, isNotNull);
      expect(b!.shelf, BookShelf.toRead);
    });

    test('numeric fields tolerate string/double', () {
      final b = Book.tryParse({
        'id': '1', 'title': 'T', 'author': 'A', 'totalPages': '250', 'shelf': 0,
        'rating': 4.0,
      });
      expect(b!.totalPages, 250);
      expect(b.rating, 4);
    });

    test('missing id returns null', () {
      expect(Book.tryParse({'title': 'T', 'author': 'A'}), isNull);
    });
  });

  group('ReadingLog.tryParse (T1.3)', () {
    test('valid record parses', () {
      final l = ReadingLog.tryParse({
        'id': 'l1', 'bookId': 'b1', 'date': '2026-01-01T00:00:00.000',
        'minutes': 30, 'pageAtEnd': 50,
      });
      expect(l, isNotNull);
      expect(l!.minutes, 30);
    });

    test('unparseable date returns null', () {
      expect(
        ReadingLog.tryParse({
          'id': 'l1', 'bookId': 'b1', 'date': 'garbage', 'minutes': 30, 'pageAtEnd': 50,
        }),
        isNull,
      );
    });

    test('missing bookId returns null', () {
      expect(
        ReadingLog.tryParse({'id': 'l1', 'date': '2026-01-01T00:00:00.000', 'minutes': 30, 'pageAtEnd': 5}),
        isNull,
      );
    });
  });

  group('UserProfile.fromJson tolerant (T1.3)', () {
    test('missing fields fall back without throwing', () {
      final p = UserProfile.fromJson(const {'name': 'X'});
      expect(p.id, 'u1');
      expect(p.name, 'X');
      expect(p.dailyGoalMinutes, 45);
    });
  });

  group('repositories skip-and-log unparseable records (T1.3)', () {
    test('LocalBooksRepository loads only valid records', () async {
      SharedPreferences.setMockInitialValues({
        'books_data':
            '[{"id":"1","title":"Good","author":"A","totalPages":100,"shelf":1},'
            '{"title":"NoId","author":"B","totalPages":50,"shelf":0},'
            '{"id":"3","title":"BadShelf","author":"C","totalPages":80,"shelf":99}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalBooksRepository(LocalStorageService(prefs));
      final books = await repo.list();
      // "NoId" skipped; "BadShelf" kept (shelf clamped).
      expect(books.map((b) => b.id).toList()..sort(), const ['1', '3']);
      expect(books.firstWhere((b) => b.id == '3').shelf, BookShelf.toRead);
    });

    test('LocalReadingLogsRepository skips bad-date records', () async {
      SharedPreferences.setMockInitialValues({
        'reading_logs_data':
            '[{"id":"l1","bookId":"b1","date":"2026-01-01T00:00:00.000","minutes":30,"pageAtEnd":10},'
            '{"id":"l2","bookId":"b1","date":"nope","minutes":30,"pageAtEnd":20}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalReadingLogsRepository(LocalStorageService(prefs));
      final logs = await repo.listAll();
      expect(logs.map((l) => l.id).toList(), ['l1']);
    });
  });
}
