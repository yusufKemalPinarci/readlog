import 'package:flutter/foundation.dart';

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
    int? durationSeconds,
    String? title,
    String? note,
    String? audioFilePath,
    String? noteFilePath,
  }) {
    return ReadingLog(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
      minutes: minutes ?? this.minutes,
      pageAtEnd: pageAtEnd ?? this.pageAtEnd,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      title: title ?? this.title,
      note: note ?? this.note,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      noteFilePath: noteFilePath ?? this.noteFilePath,
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

  factory ReadingLog.fromJson(Map<String, dynamic> json) {
    return ReadingLog(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      date: DateTime.parse(json['date'] as String),
      minutes: json['minutes'] as int,
      durationSeconds: json['durationSeconds'] as int?,
      pageAtEnd: json['pageAtEnd'] as int,
      title: json['title'] as String?,
      note: json['note'] as String?,
      audioFilePath: json['audioFilePath'] as String?,
      noteFilePath: json['noteFilePath'] as String?,
    );
  }
}


