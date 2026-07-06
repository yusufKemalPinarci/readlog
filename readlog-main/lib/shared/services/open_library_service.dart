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
  final String? editionKey; // Open Library work key

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

  /// Yüksek kaliteli kapak resmi URL'i (indirme/kaydetme için)
  String? get highResCoverUrl {
    if (coverImageUrl == null) return null;
    // Open Library kapak URL'ini küçükten büyüğe yükselt: -M.jpg → -L.jpg
    return coverImageUrl!
        .replaceAll('-M.jpg', '-L.jpg')
        .replaceAll('-S.jpg', '-L.jpg');
  }

  factory OpenLibraryBook.fromOpenLibraryJson(Map<String, dynamic> json) {
    // Yazar bilgisini al
    String? author;
    final authors = json['author_name'] as List<dynamic>?;
    if (authors != null && authors.isNotEmpty) {
      author = authors[0].toString();
    }

    // Sayfa sayısını al (medyan değer - çok daha güvenilir)
    int? pageCount;
    final pages = json['number_of_pages_median'];
    if (pages != null) {
      if (pages is int && pages > 0) {
        pageCount = pages;
      } else if (pages is double && pages > 0) {
        pageCount = pages.toInt();
      }
    }

    // ISBN bilgisini al (13 haneli tercih edilir)
    String? isbn;
    final isbns = json['isbn'] as List<dynamic>?;
    if (isbns != null && isbns.isNotEmpty) {
      for (final i in isbns) {
        if (i.toString().length == 13) {
          isbn = i.toString();
          break;
        }
      }
      isbn ??= isbns.first.toString();
    }

    // Kapak resmi URL'ini al - sadece cover_i varsa (garantili fotoğraf)
    String? coverImageUrl;
    final coverId = json['cover_i'];
    if (coverId != null) {
      coverImageUrl = 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
    }

    // Open Library work key'ini al
    final workKey = (json['key'] as String?)?.replaceFirst('/works/', '');

    // Yayın yılı
    String? publishDate;
    final year = json['first_publish_year'];
    if (year != null) publishDate = year.toString();

    return OpenLibraryBook(
      title: (json['title'] as String?) ?? '',
      author: author,
      pageCount: pageCount,
      coverImageUrl: coverImageUrl,
      description: null,
      isbn: isbn,
      publishDate: publishDate,
      editionKey: workKey,
    );
  }
}

class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org';

  /// Kitap ara (Open Library Search API - API key gerektirmez)
  Future<List<OpenLibraryBook>> searchBooks(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = Uri.parse(
        '$_baseUrl/search.json?q=$encodedQuery&limit=20'
        '&fields=key,title,author_name,number_of_pages_median,isbn,cover_i,first_publish_year',
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('İstek zaman aşımına uğradı');
        },
      );

      if (response.statusCode == 200) {
        // T2.28: decode as UTF-8 explicitly — response.body uses the charset
        // from Content-Type (latin1 when absent), mangling Turkish characters.
        final jsonData = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final docs = jsonData['docs'] as List<dynamic>?;

        if (docs == null || docs.isEmpty) {
          return [];
        }

        return docs
            .map((doc) => OpenLibraryBook.fromOpenLibraryJson(doc as Map<String, dynamic>))
            .where((book) => book.title.isNotEmpty)
            .toList();
      } else {
        throw Exception('API hatası: ${response.statusCode}');
      }
    } catch (e) {
      // T2.28: don't double-wrap — the specific messages above are already
      // Exceptions; only wrap genuinely non-Exception errors.
      if (e is Exception) rethrow;
      throw Exception('Kitap arama hatası: $e');
    }
  }

  /// Sayfa sayısını çek - artık arama sonuçlarında geliyor, uyumluluk için korundu
  Future<int?> fetchPageCount(String workKey) async {
    return null;
  }
}

