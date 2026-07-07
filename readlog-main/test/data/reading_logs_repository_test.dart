import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/reading/domain/reading_log.dart';
import 'package:libris/features/reading/data/reading_logs_repository.dart';

ReadingLog _log(DateTime date, {String id = 'l1', String bookId = 'b1'}) =>
    ReadingLog(id: id, bookId: bookId, date: date, minutes: 30, pageAtEnd: 10);

void main() {
  group('hasCompletedReadingToday midnight boundary (T2.6)', () {
    test('a log dated exactly at today midnight counts as today', () async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final repo = InMemoryReadingLogsRepository(seed: [_log(midnight)]);
      expect(await repo.hasCompletedReadingToday(), isTrue,
          reason: 'isAfter(todayStart) wrongly excluded a midnight log; !isBefore includes it');
    });

    test('a log from yesterday does not count as today', () async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 23, 59);
      final repo = InMemoryReadingLogsRepository(seed: [_log(yesterday)]);
      expect(await repo.hasCompletedReadingToday(), isFalse);
    });

    test('a log later today counts', () async {
      final now = DateTime.now();
      final laterToday = DateTime(now.year, now.month, now.day, 12);
      final repo = InMemoryReadingLogsRepository(seed: [_log(laterToday)]);
      expect(await repo.hasCompletedReadingToday(), isTrue);
    });
  });
}
