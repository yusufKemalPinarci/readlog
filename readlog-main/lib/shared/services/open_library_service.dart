import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenLibraryBook {
  final String title;
  final String? author;
  final int? pageCount;
  final String? coverImageUrl;
  final String? description;
  final String? isbn;
  final String? publishDate;
  final String? editionKey;

  OpenLibraryBook({
    required this.title,
    this.author,
    this.pageCount,
    this.coverImageUrl,
    this.description,
    this.isbn,
    this.publishDate,
    this.editionKey,
  });

  factory OpenLibraryBook.fromJson(Map<String, dynamic> json) {
    // Yazar bilgisini al
    String? author;
    if (json['author_name'] != null && json['author_name'] is List) {
      final authors = json['author_name'] as List;
      if (authors.isNotEmpty) {
        author = authors[0].toString();
      }
    }

    // Sayfa sayısını al
    int? pageCount;
    if (json['number_of_pages_median'] != null) {
      pageCount = json['number_of_pages_median'] as int?;
    } else if (json['number_of_pages'] != null) {
      pageCount = json['number_of_pages'] as int?;
    }

    // Kapak resmi URL'ini al
    String? coverImageUrl;
    if (json['cover_i'] != null) {
      coverImageUrl = 'https://covers.openlibrary.org/b/id/${json['cover_i']}-L.jpg';
    } else if (json['isbn'] != null && json['isbn'] is List && (json['isbn'] as List).isNotEmpty) {
      final isbn = (json['isbn'] as List).first.toString();
      coverImageUrl = 'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg';
    }

    // Edition key'i al (sayfa sayısı yoksa detay çekmek için)
    String? editionKey;
    if (json['edition_key'] != null && json['edition_key'] is List) {
      final editions = json['edition_key'] as List;
      if (editions.isNotEmpty) {
        editionKey = editions.first.toString();
      }
    }

    return OpenLibraryBook(
      title: (json['title'] as String?) ?? '',
      author: author,
      pageCount: pageCount,
      coverImageUrl: coverImageUrl,
      description: json['first_sentence'] != null && json['first_sentence'] is List
          ? (json['first_sentence'] as List).first.toString()
          : null,
      isbn: json['isbn'] != null && json['isbn'] is List && (json['isbn'] as List).isNotEmpty
          ? (json['isbn'] as List).first.toString()
          : null,
      publishDate: json['first_publish_year']?.toString(),
      editionKey: editionKey,
    );
  }
}

class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org';

  /// Kitap ara
  Future<List<OpenLibraryBook>> searchBooks(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = Uri.parse('$_baseUrl/search.json?q=$encodedQuery&limit=20');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('İstek zaman aşımına uğradı');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final docs = jsonData['docs'] as List<dynamic>?;
        
        if (docs == null || docs.isEmpty) {
          return [];
        }

        return docs
            .map((doc) => OpenLibraryBook.fromJson(doc as Map<String, dynamic>))
            .where((book) => book.title.isNotEmpty)
            .toList();
      } else {
        throw Exception('API hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Kitap arama hatası: $e');
    }
  }

  /// Edition key ile sayfa sayısını çek
  Future<int?> fetchPageCount(String editionKey) async {
    try {
      final url = Uri.parse('$_baseUrl/books/$editionKey.json');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('İstek zaman aşımına uğradı');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        if (jsonData['number_of_pages'] != null) {
          return jsonData['number_of_pages'] as int?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

