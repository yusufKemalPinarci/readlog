import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libris/shared/services/local_storage_service.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';

void main() {
  group('LocalStorageService corruption handling (T1.4)', () {
    test('corrupt blob throws and is preserved to .corrupt.bak (not wiped)', () async {
      const corrupt = 'not valid json{';
      SharedPreferences.setMockInitialValues({'books_data': corrupt});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      expect(() => storage.loadBooks(), throwsA(isA<StorageCorruptionException>()));
      // Raw blob preserved for recovery.
      expect(prefs.getString('books_data.corrupt.bak'), corrupt);
      // Original still present (not replaced with []).
      expect(prefs.getString('books_data'), corrupt);
    });

    test('absent key returns empty (not treated as corrupt)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      expect(storage.loadBooks(), isEmpty);
    });

    test('save rolls the previous blob into .bak', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      await storage.saveBooks([{'id': '1', 'title': 'First'}]);
      await storage.saveBooks([{'id': '2', 'title': 'Second'}]);

      final bak = prefs.getString('books_data.bak');
      expect(bak, contains('First'));
      expect(storage.loadBooks().single['id'], '2');
    });
  });

  group('LocalBooksRepository read-only on corruption (T1.4)', () {
    test('does not overwrite corrupt storage on save', () async {
      const corrupt = '[{"id":"1" BROKEN';
      SharedPreferences.setMockInitialValues({'books_data': corrupt});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final repo = LocalBooksRepository(storage);

      expect(repo.isCorrupt, isTrue);

      await repo.upsert(const Book(
        id: '99', title: 'New', author: 'A', totalPages: 10, shelf: BookShelf.toRead,
      ));

      // The corrupt blob must be untouched — no silent wipe/overwrite.
      expect(prefs.getString('books_data'), corrupt);
    });
  });
}
