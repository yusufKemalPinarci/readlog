import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/reading/domain/reading_log.dart';

void main() {
  group('ReadingLog', () {
    final now = DateTime(2024, 6, 15, 14, 30);
    final log = ReadingLog(
      id: 'log-1',
      bookId: 'book-1',
      date: now,
      minutes: 45,
      pageAtEnd: 120,
      title: 'Öğlen okuma',
      note: 'İlginç bölüm',
      audioFilePath: '/audio/rec1.m4a',
      noteFilePath: '/notes/note1.txt',
    );

    test('tüm alanlar atanır', () {
      expect(log.id, 'log-1');
      expect(log.bookId, 'book-1');
      expect(log.date, now);
      expect(log.minutes, 45);
      expect(log.pageAtEnd, 120);
      expect(log.title, 'Öğlen okuma');
      expect(log.note, 'İlginç bölüm');
      expect(log.audioFilePath, '/audio/rec1.m4a');
      expect(log.noteFilePath, '/notes/note1.txt');
    });

    test('copyWith alanları günceller', () {
      final updated = log.copyWith(
        minutes: 60,
        pageAtEnd: 150,
        note: 'Güncellendi',
      );
      expect(updated.minutes, 60);
      expect(updated.pageAtEnd, 150);
      expect(updated.note, 'Güncellendi');
      // Değişmeyen alanlar korunur
      expect(updated.id, 'log-1');
      expect(updated.bookId, 'book-1');
      expect(updated.date, now);
      expect(updated.title, 'Öğlen okuma');
    });

    test('toJson doğru map üretir', () {
      final json = log.toJson();
      expect(json['id'], 'log-1');
      expect(json['bookId'], 'book-1');
      expect(json['date'], now.toIso8601String());
      expect(json['minutes'], 45);
      expect(json['pageAtEnd'], 120);
      expect(json['title'], 'Öğlen okuma');
      expect(json['note'], 'İlginç bölüm');
      expect(json['audioFilePath'], '/audio/rec1.m4a');
      expect(json['noteFilePath'], '/notes/note1.txt');
    });

    test('fromJson doğru ReadingLog üretir', () {
      final json = log.toJson();
      final parsed = ReadingLog.fromJson(json);
      expect(parsed.id, log.id);
      expect(parsed.bookId, log.bookId);
      expect(parsed.date, log.date);
      expect(parsed.minutes, log.minutes);
      expect(parsed.pageAtEnd, log.pageAtEnd);
      expect(parsed.title, log.title);
      expect(parsed.note, log.note);
      expect(parsed.audioFilePath, log.audioFilePath);
      expect(parsed.noteFilePath, log.noteFilePath);
    });

    test('fromJson null opsiyonel alanlarla çalışır', () {
      final json = {
        'id': 'x',
        'bookId': 'y',
        'date': '2024-01-01T00:00:00.000',
        'minutes': 10,
        'pageAtEnd': 5,
      };
      final parsed = ReadingLog.fromJson(json);
      expect(parsed.title, isNull);
      expect(parsed.note, isNull);
      expect(parsed.audioFilePath, isNull);
      expect(parsed.noteFilePath, isNull);
    });

    test('toJson -> fromJson roundtrip', () {
      final reconstructed = ReadingLog.fromJson(log.toJson());
      expect(reconstructed.id, log.id);
      expect(reconstructed.minutes, log.minutes);
      expect(reconstructed.pageAtEnd, log.pageAtEnd);
      expect(reconstructed.date.toIso8601String(), log.date.toIso8601String());
    });
  });
}
