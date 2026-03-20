import 'package:flutter/foundation.dart';

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
  });

  final String id;
  final String title;
  final String author;
  final int totalPages;
  final BookShelf shelf;

  // Basit metrikler (ileride Firebase ile genişletilecek)
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
    int? currentPage,
    int? totalMinutes,
    String? category,
    int? readCount,
    int? order,
    String? coverImagePath,
    String? review,
    int? rating,
    int? finalReadingTimeMinutes,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      totalPages: totalPages ?? this.totalPages,
      shelf: shelf ?? this.shelf,
      currentPage: currentPage ?? this.currentPage,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      category: category ?? this.category,
      readCount: readCount ?? this.readCount,
      order: order ?? this.order,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      review: review ?? this.review,
      rating: rating ?? this.rating,
      finalReadingTimeMinutes: finalReadingTimeMinutes ?? this.finalReadingTimeMinutes,
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
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      totalPages: json['totalPages'] as int,
      shelf: BookShelf.values[json['shelf'] as int],
      currentPage: json['currentPage'] as int?,
      totalMinutes: json['totalMinutes'] as int?,
      category: json['category'] as String?,
      readCount: json['readCount'] as int? ?? 0,
      order: json['order'] as int? ?? 0,
      coverImagePath: json['coverImagePath'] as String?,
      review: json['review'] as String?,
      rating: json['rating'] as int?,
      finalReadingTimeMinutes: json['finalReadingTimeMinutes'] as int?,
    );
  }
}


