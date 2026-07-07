import 'package:flutter/foundation.dart';

import '../../../shared/utils/json_parse.dart';

/// Sentinel for [ReadingLog.copyWith] so nullable fields can be explicitly
/// cleared. Omitting a field keeps the current value; passing `null` sets null.
const Object _unset = Object();

@immutable
class ReadingLog {
  const ReadingLog({
    required this.id,
    required this.bookId,
    required this.date,
    required this.minutes,
    required this.pageAtEnd,
    this.durationSeconds,
    this.title, // Oturum başlığı
    this.note,
    this.audioFilePath,
    this.noteFilePath, // Not dosya yolu (telefon hafızasında)
  });

  final String id;
  final String bookId;
  final DateTime date;
  final int minutes;
  final int? durationSeconds; // Toplam süre saniye cinsinden (null = eski veri)
  final int pageAtEnd;
  final String? title;
  final String? note; // Geçici not (UI için)
  final String? audioFilePath; // Ses kaydı dosya yolu
  final String? noteFilePath; // Not dosya yolu (telefon hafızasında)

  /// Gerçek süreyi saniye cinsinden döndürür (eski veri için minutes * 60)
  int get effectiveDurationSeconds => durationSeconds ?? (minutes * 60);

  ReadingLog copyWith({
    String? id,
    String? bookId,
    DateTime? date,
    int? minutes,
    int? pageAtEnd,
    Object? durationSeconds = _unset,
    Object? title = _unset,
    Object? note = _unset,
    Object? audioFilePath = _unset,
    Object? noteFilePath = _unset,
  }) {
    return ReadingLog(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
      minutes: minutes ?? this.minutes,
      pageAtEnd: pageAtEnd ?? this.pageAtEnd,
      durationSeconds: identical(durationSeconds, _unset) ? this.durationSeconds : durationSeconds as int?,
      title: identical(title, _unset) ? this.title : title as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      audioFilePath: identical(audioFilePath, _unset) ? this.audioFilePath : audioFilePath as String?,
      noteFilePath: identical(noteFilePath, _unset) ? this.noteFilePath : noteFilePath as String?,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'date': date.toIso8601String(),
      'minutes': minutes,
      'durationSeconds': durationSeconds,
      'pageAtEnd': pageAtEnd,
      'title': title,
      'note': note,
      'audioFilePath': audioFilePath,
      'noteFilePath': noteFilePath,
    };
  }

  /// Tolerant deserialization (T1.3): DateTime.tryParse with fallback and
  /// coerced numeric fields; never throws on drifted/missing optionals.
  factory ReadingLog.fromJson(Map<String, dynamic> json) {
    return ReadingLog(
      id: asStringOrNull(json['id']) ?? '',
      bookId: asStringOrNull(json['bookId']) ?? '',
      date: asDateOr(json['date'], DateTime.fromMillisecondsSinceEpoch(0)),
      minutes: asIntOr(json['minutes'], 0),
      durationSeconds: asIntOrNull(json['durationSeconds']),
      pageAtEnd: asIntOr(json['pageAtEnd'], 0),
      title: asStringOrNull(json['title']),
      note: asStringOrNull(json['note']),
      audioFilePath: asStringOrNull(json['audioFilePath']),
      noteFilePath: asStringOrNull(json['noteFilePath']),
    );
  }

  /// Returns null for unparseable records (missing/blank id or bookId, or an
  /// unparseable date) so repositories can skip-and-log instead of throwing (T1.3).
  static ReadingLog? tryParse(Map<String, dynamic> json) {
    try {
      final id = asStringOrNull(json['id']);
      final bookId = asStringOrNull(json['bookId']);
      if (id == null || id.isEmpty || bookId == null || bookId.isEmpty) {
        return null;
      }
      if (json['date'] is! String || DateTime.tryParse(json['date'] as String) == null) {
        return null;
      }
      return ReadingLog.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}


