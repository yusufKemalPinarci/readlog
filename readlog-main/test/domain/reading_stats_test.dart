import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/reading/domain/reading_log.dart';
import 'package:libris/shared/utils/reading_stats.dart';

ReadingLog _log(DateTime date, int pageAtEnd, {String id = 'l'}) =>
    ReadingLog(id: '$id$date', bookId: 'b', date: date, minutes: 10, pageAtEnd: pageAtEnd);

void main() {
  group('pagesReadOnDay (T2.9)', () {
    test('mid-book day counts only that day\'s progress', () {
      // Read to p20 yesterday, to p50 today -> 30 pages today.
      final logs = [
        _log(DateTime(2026, 1, 1), 20),
        _log(DateTime(2026, 1, 2, 9), 50),
      ];
      expect(pagesReadOnDay(logs, DateTime(2026, 1, 2)), 30);
    });

    test('first-ever day counts from zero', () {
      final logs = [_log(DateTime(2026, 1, 2), 40)];
      expect(pagesReadOnDay(logs, DateTime(2026, 1, 2)), 40);
    });

    test('multi-session day uses the highest page reached', () {
      final logs = [
        _log(DateTime(2026, 1, 1), 20),
        _log(DateTime(2026, 1, 2, 9), 35),
        _log(DateTime(2026, 1, 2, 20), 60),
      ];
      expect(pagesReadOnDay(logs, DateTime(2026, 1, 2)), 40); // 60 - 20
    });

    test('re-read (page drops below prior max) counts from the day', () {
      final logs = [
        _log(DateTime(2026, 1, 1), 300), // finished
        _log(DateTime(2026, 1, 5, 9), 25), // restarted
      ];
      expect(pagesReadOnDay(logs, DateTime(2026, 1, 5)), 25);
    });

    test('no logs on the day -> 0', () {
      final logs = [_log(DateTime(2026, 1, 1), 20)];
      expect(pagesReadOnDay(logs, DateTime(2026, 1, 3)), 0);
    });
  });
}
