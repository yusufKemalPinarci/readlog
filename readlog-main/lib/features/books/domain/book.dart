import 'package:flutter/foundation.dart';

import '../../../shared/utils/json_parse.dart';

/// Sentinel for [Book.copyWith] so nullable fields can be explicitly cleared.
/// Omitting a field keeps the current value; passing `null` sets it to null.
const Object _unset = Object();

enum BookShelf {
  toRead,
  reading,
  read,
}

@immutable
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.totalPages,
    required this.shelf,
    this.currentPage,
    this.totalMinutes,
    this.category,
    this.readCount = 0,
    this.order = 0,
    this.coverImagePath,
    this.review,
    this.rating,
    this.finalReadingTimeMinutes,
    this.lastStartedAt,
  });

  final String id;
  final String title;
  final String author;
  final int totalPages;
  final BookShelf shelf;

  final int? currentPage;
  final int? totalMinutes;
  final String? category;
  final int readCount; // Kaç kez okundu
  final int order; // Sıralama için
  final String? coverImagePath; // Kitap kapağı resmi yolu

  // User review fields
  final String? review;
  final int? rating; // 1-5 or 1-10
  final int? finalReadingTimeMinutes; // User's manual input or final calc

  /// When the current reading pass started (set on restart). T2.7: the finish
  /// flow sums only logs on/after this so a re-read's total excludes prior
  /// passes. Null = no restart yet → include all logs (legacy behavior).
  final DateTime? lastStartedAt;

  double get progress {
    final cp = currentPage ?? 0;
    if (totalPages <= 0) return 0;
    return (cp / totalPages).clamp(0, 1);
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    int? totalPages,
    BookShelf? shelf,
    Object? currentPage = _unset,
    Object? totalMinutes = _unset,
    Object? category = _unset,
    int? readCount,
    int? order,
    Object? coverImagePath = _unset,
    Object? review = _unset,
    Object? rating = _unset,
    Object? finalReadingTimeMinutes = _unset,
    Object? lastStartedAt = _unset,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      totalPages: totalPages ?? this.totalPages,
      shelf: shelf ?? this.shelf,
      currentPage: identical(currentPage, _unset) ? this.currentPage : currentPage as int?,
      totalMinutes: identical(totalMinutes, _unset) ? this.totalMinutes : totalMinutes as int?,
      category: identical(category, _unset) ? this.category : category as String?,
      readCount: readCount ?? this.readCount,
      order: order ?? this.order,
      coverImagePath: identical(coverImagePath, _unset) ? this.coverImagePath : coverImagePath as String?,
      review: identical(review, _unset) ? this.review : review as String?,
      rating: identical(rating, _unset) ? this.rating : rating as int?,
      finalReadingTimeMinutes:
          identical(finalReadingTimeMinutes, _unset) ? this.finalReadingTimeMinutes : finalReadingTimeMinutes as int?,
      lastStartedAt:
          identical(lastStartedAt, _unset) ? this.lastStartedAt : lastStartedAt as DateTime?,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'totalPages': totalPages,
      'shelf': shelf.index,
      'currentPage': currentPage,
      'totalMinutes': totalMinutes,
      'category': category,
      'readCount': readCount,
      'order': order,
      'coverImagePath': coverImagePath,
      'review': review,
      'rating': rating,
      'finalReadingTimeMinutes': finalReadingTimeMinutes,
      'lastStartedAt': lastStartedAt?.toIso8601String(),
    };
  }

  /// Tolerant deserialization (T1.3): clamps a bad `shelf` index to [toRead],
  /// coerces numeric fields, and never throws on drifted/missing optionals.
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: asStringOrNull(json['id']) ?? '',
      title: asStringOrNull(json['title']) ?? '',
      author: asStringOrNull(json['author']) ?? '',
      totalPages: asIntOr(json['totalPages'], 0),
      shelf: enumByIndex(BookShelf.values, json['shelf'], BookShelf.toRead),
      currentPage: asIntOrNull(json['currentPage']),
      totalMinutes: asIntOrNull(json['totalMinutes']),
      category: asStringOrNull(json['category']),
      readCount: asIntOr(json['readCount'], 0),
      order: asIntOr(json['order'], 0),
      coverImagePath: asStringOrNull(json['coverImagePath']),
      review: asStringOrNull(json['review']),
      rating: asIntOrNull(json['rating']),
      finalReadingTimeMinutes: asIntOrNull(json['finalReadingTimeMinutes']),
      lastStartedAt: json['lastStartedAt'] is String
          ? DateTime.tryParse(json['lastStartedAt'] as String)
          : null,
    );
  }

  /// Returns null for unparseable records (missing/blank id) so repositories
  /// can skip-and-log instead of throwing on a single corrupt entry (T1.3).
  static Book? tryParse(Map<String, dynamic> json) {
    try {
      final id = asStringOrNull(json['id']);
      if (id == null || id.isEmpty) return null;
      return Book.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}


