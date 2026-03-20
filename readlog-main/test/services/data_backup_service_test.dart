import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:berber/shared/services/local_storage_service.dart';
import 'package:berber/shared/services/data_backup_service.dart';

void main() {
  group('DataBackupService', () {
    late DataBackupService service;
    late LocalStorageService localStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      localStorage = LocalStorageService(prefs);
      service = DataBackupService(localStorage);
    });

    test('instance oluşturulabilir', () {
      expect(service, isNotNull);
    });

    test('boş veri ile sorunsuz çalışır', () {
      expect(localStorage.loadBooks(), isEmpty);
      expect(localStorage.loadReadingLogs(), isEmpty);
    });

    test('veri hazırlama doğru çalışır', () async {
      // Export edilecek verileri ekle
      await localStorage.saveBooks([
        {'id': '1', 'title': 'Test Kitap', 'author': 'Yazar'},
      ]);
      await localStorage.saveReadingLogs([
        {'id': 'log1', 'bookId': '1', 'minutes': 30},
      ]);

      final books = localStorage.loadBooks();
      final logs = localStorage.loadReadingLogs();

      expect(books.length, 1);
      expect(books[0]['title'], 'Test Kitap');
      expect(logs.length, 1);
      expect(logs[0]['minutes'], 30);
    });
  });
}
