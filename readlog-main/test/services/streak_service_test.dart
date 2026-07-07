import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/profile/application/streak_service.dart';
import 'package:libris/features/reading/domain/reading_log.dart';

ReadingLog _log(DateTime date, {String bookId = 'b1', int minutes = 30}) {
  return ReadingLog(
    id: '${date.toIso8601String()}-$bookId',
    bookId: bookId,
    date: date,
    minutes: minutes,
    pageAtEnd: 10,
  );
}

void main() {
  late StreakService service;

  setUp(() {
    service = StreakService();
  });

  group('calculateCurrentStreak', () {
    test('boş liste ile 0 döner', () {
      expect(service.calculateCurrentStreak([]), 0);
    });

    test('bugün okuduysa streak 1', () {
      final today = DateTime.now();
      final logs = [_log(today)];
      expect(service.calculateCurrentStreak(logs), 1);
    });

    test('bugün ve dün okuduysa streak 2', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final yesterday = today.subtract(const Duration(days: 1));
      final logs = [_log(today), _log(yesterday)];
      expect(service.calculateCurrentStreak(logs), 2);
    });

    test('ardışık 5 gün ile streak 5', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final logs = List.generate(5, (i) => _log(today.subtract(Duration(days: i))));
      expect(service.calculateCurrentStreak(logs), 5);
    });

    test('arada boşluk varsa streak kırılır', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final logs = [
        _log(today),
        _log(today.subtract(const Duration(days: 1))),
        // 2 gün önce yok
        _log(today.subtract(const Duration(days: 3))),
      ];
      expect(service.calculateCurrentStreak(logs), 2);
    });

    test('dün okuduysa ama bugün okumadıysa streak devam eder', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      final twoDaysAgo = yesterday.subtract(const Duration(days: 1));
      final logs = [_log(yesterday), _log(twoDaysAgo)];
      expect(service.calculateCurrentStreak(logs), 2);
    });

    test('2 gün önceden beri okumamışsa streak 0', () {
      final now = DateTime.now();
      final twoDaysAgo = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 2));
      final logs = [_log(twoDaysAgo)];
      expect(service.calculateCurrentStreak(logs), 0);
    });

    test('aynı gün birden fazla log streak i etkilemez', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final logs = [
        _log(today),
        _log(today.add(const Duration(hours: 2)), bookId: 'b2'),
        _log(today.subtract(const Duration(days: 1))),
      ];
      expect(service.calculateCurrentStreak(logs), 2);
    });
  });

  group('calculateBestStreak', () {
    test('boş liste ile 0 döner', () {
      expect(service.calculateBestStreak([]), 0);
    });

    test('tek gün ile best streak 1', () {
      final now = DateTime.now();
      final logs = [_log(now)];
      expect(service.calculateBestStreak(logs), 1);
    });

    test('ardışık 7 gün ile best streak 7', () {
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      final logs = List.generate(7, (i) => _log(base.subtract(Duration(days: i))));
      expect(service.calculateBestStreak(logs), 7);
    });

    test('kırık streak ile en uzunu döner', () {
      // 3 gün + boşluk + 5 gün ardışık
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      final logs = [
        // Son 3 gün
        _log(base),
        _log(base.subtract(const Duration(days: 1))),
        _log(base.subtract(const Duration(days: 2))),
        // Boşluk (3. gün yok)
        // Daha eski 5 gün ardışık
        _log(base.subtract(const Duration(days: 4))),
        _log(base.subtract(const Duration(days: 5))),
        _log(base.subtract(const Duration(days: 6))),
        _log(base.subtract(const Duration(days: 7))),
        _log(base.subtract(const Duration(days: 8))),
      ];
      expect(service.calculateBestStreak(logs), 5);
    });

    test('aynı gün çoklu log best streak i etkilemez', () {
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      final logs = [
        _log(base),
        _log(base.add(const Duration(hours: 1)), bookId: 'b2'),
        _log(base.add(const Duration(hours: 3)), bookId: 'b3'),
      ];
      expect(service.calculateBestStreak(logs), 1);
    });

    // T5.5: DST-boundary dates. With the old `subtract(Duration(days:1))`,
    // stepping across a 23h/25h day landed off-midnight and broke the streak;
    // calendar-day stepping (_prevDay) is correct. These pass on every host and
    // specifically exercise the fix where the local TZ observes US DST.
    test('spring-forward days stay consecutive (T5.5)', () {
      // 2026-03-08 is the US spring-forward date.
      final logs = [
        _log(DateTime(2026, 3, 7, 9)),
        _log(DateTime(2026, 3, 8, 9)),
        _log(DateTime(2026, 3, 9, 9)),
        _log(DateTime(2026, 3, 10, 9)),
      ];
      expect(service.calculateBestStreak(logs), 4);
    });

    test('fall-back days stay consecutive (T5.5)', () {
      // 2026-11-01 is the US fall-back date.
      final logs = [
        _log(DateTime(2026, 10, 31, 9)),
        _log(DateTime(2026, 11, 1, 9)),
        _log(DateTime(2026, 11, 2, 9)),
      ];
      expect(service.calculateBestStreak(logs), 3);
    });
  });
}
