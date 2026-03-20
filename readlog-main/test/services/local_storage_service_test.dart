import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libris/shared/services/local_storage_service.dart';

void main() {
  group('LocalStorageService', () {
    late LocalStorageService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = LocalStorageService(prefs);
    });

    group('Books', () {
      test('boş durumda loadBooks boş liste döner', () {
        expect(service.loadBooks(), isEmpty);
      });

      test('saveBooks ve loadBooks çalışır', () async {
        final books = [
          {'id': '1', 'title': 'Kitap A', 'author': 'Yazar A'},
          {'id': '2', 'title': 'Kitap B', 'author': 'Yazar B'},
        ];
        await service.saveBooks(books);
        final loaded = service.loadBooks();
        expect(loaded.length, 2);
        expect(loaded[0]['id'], '1');
        expect(loaded[0]['title'], 'Kitap A');
        expect(loaded[1]['id'], '2');
      });

      test('saveBooks üzerine yazarak günceller', () async {
        await service.saveBooks([{'id': '1', 'title': 'Eski'}]);
        await service.saveBooks([{'id': '2', 'title': 'Yeni'}]);
        final loaded = service.loadBooks();
        expect(loaded.length, 1);
        expect(loaded[0]['title'], 'Yeni');
      });
    });

    group('ReadingLogs', () {
      test('boş durumda loadReadingLogs boş liste döner', () {
        expect(service.loadReadingLogs(), isEmpty);
      });

      test('saveReadingLogs ve loadReadingLogs çalışır', () async {
        final logs = [
          {'id': '1', 'bookId': 'b1', 'minutes': 30},
          {'id': '2', 'bookId': 'b1', 'minutes': 45},
        ];
        await service.saveReadingLogs(logs);
        final loaded = service.loadReadingLogs();
        expect(loaded.length, 2);
        expect(loaded[0]['minutes'], 30);
        expect(loaded[1]['minutes'], 45);
      });
    });

    group('ThemeMode', () {
      test('varsayılan tema light (false)', () {
        expect(service.loadThemeMode(), false);
      });

      test('dark tema kaydedilir ve yüklenir', () async {
        await service.saveThemeMode(true);
        expect(service.loadThemeMode(), true);
      });

      test('light tema kaydedilir', () async {
        await service.saveThemeMode(true);
        await service.saveThemeMode(false);
        expect(service.loadThemeMode(), false);
      });
    });

    group('FirstLaunch', () {
      test('ilk açılış varsayılan true', () {
        expect(service.getIsFirstLaunch(), true);
      });

      test('false olarak ayarlanabilir', () async {
        await service.setIsFirstLaunch(false);
        expect(service.getIsFirstLaunch(), false);
      });
    });

    group('clearAll', () {
      test('tüm verileri temizler', () async {
        await service.saveBooks([{'id': '1', 'title': 'Test'}]);
        await service.saveReadingLogs([{'id': '1', 'bookId': '1'}]);
        await service.saveThemeMode(true);
        await service.setIsFirstLaunch(false);

        await service.clearAll();

        expect(service.loadBooks(), isEmpty);
        expect(service.loadReadingLogs(), isEmpty);
        expect(service.loadThemeMode(), false);
        expect(service.getIsFirstLaunch(), true);
      });
    });
  });
}
