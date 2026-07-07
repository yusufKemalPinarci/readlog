import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libris/shared/services/local_storage_service.dart';
import 'package:libris/shared/services/data_backup_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_import_test');
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> writeJson(Map<String, dynamic> data) async {
    final f = File('${tempDir.path}/backup.json');
    await f.writeAsString(jsonEncode(data));
    return f;
  }

  test('invalid record rejects the whole import; existing data untouched (T1.5)',
      () async {
    SharedPreferences.setMockInitialValues({
      'books_data': jsonEncode([
        {'id': 'existing', 'title': 'Keep', 'author': 'A', 'totalPages': 100, 'shelf': 1}
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final service = DataBackupService(storage);
    final before = prefs.getString('books_data');

    // One valid book, one log with an unparseable date -> reject-all.
    final badFile = await writeJson({
      'version': 2,
      'books': [
        {'id': 'b1', 'title': 'X', 'author': 'A', 'totalPages': 50, 'shelf': 0}
      ],
      'readingLogs': [
        {'id': 'l1', 'bookId': 'b1', 'date': 'GARBAGE', 'minutes': 10, 'pageAtEnd': 5}
      ],
    });

    await expectLater(
      () => service.importFromFile(badFile, replaceExisting: true),
      throwsA(isA<Exception>()),
    );
    expect(prefs.getString('books_data'), before,
        reason: 'a rejected import must not modify existing storage');
  });

  test('valid JSON backup restores books, logs, profile and theme (T1.5/T1.6)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final service = DataBackupService(storage);

    final file = await writeJson({
      'version': 2,
      'books': [
        {'id': 'b1', 'title': 'Imported', 'author': 'A', 'totalPages': 120, 'shelf': 2}
      ],
      'readingLogs': [
        {'id': 'l1', 'bookId': 'b1', 'date': '2026-01-01T00:00:00.000', 'minutes': 30, 'pageAtEnd': 60}
      ],
      'profile': {'id': 'u1', 'name': 'Neo', 'username': 'neo', 'dailyGoalMinutes': 60},
      'settings': {'themeMode': 'dark'},
    });

    await service.importFromFile(file, replaceExisting: true);

    expect(storage.loadBooks().single['title'], 'Imported');
    expect(storage.loadReadingLogs().single['id'], 'l1');
    expect(storage.loadProfile()!['name'], 'Neo');
    expect(storage.loadThemeModeString(), 'dark');
  });

  test('relative media paths are nulled in the JSON path (no archive) (T1.5)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final service = DataBackupService(storage);

    final file = await writeJson({
      'version': 2,
      'books': [
        {'id': 'b1', 'title': 'X', 'author': 'A', 'totalPages': 10, 'shelf': 0,
         'coverImagePath': 'book_covers/cover_b1.jpg'}
      ],
      'readingLogs': [],
    });

    await service.importFromFile(file, replaceExisting: true);
    expect(storage.loadBooks().single['coverImagePath'], isNull);
  });
}
