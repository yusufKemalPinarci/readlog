import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/books_repository.dart';
import '../domain/book.dart';
import 'books_providers.dart';
import '../../../shared/services/image_storage_service.dart';

@immutable
class BooksState {
  const BooksState({required this.items, this.isLoading = false});

  final List<Book> items;
  final bool isLoading;

  BooksState copyWith({List<Book>? items, bool? isLoading}) {
    return BooksState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading);
  }
}

class BooksVm extends StateNotifier<BooksState> {
  BooksVm(this._repo) : super(const BooksState(items: [], isLoading: true)) {
    _load();
  }

  final BooksRepository _repo;

  Future<void> _load() async {
    final items = await _repo.list();
    state = state.copyWith(items: items, isLoading: false);
  }

  List<Book> byShelf(BookShelf shelf) {
    final books = state.items.where((b) => b.shelf == shelf).toList();
    books.sort((a, b) => a.order.compareTo(b.order));
    return books;
  }

  Book? byId(String id) {
    for (final b in state.items) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<void> addBook({
    required String title,
    required String author,
    required int totalPages,
    String? coverImagePath,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    // Yeni kitabın order değerini belirle
    final toReadBooks = state.items.where((b) => b.shelf == BookShelf.toRead).toList();
    final maxOrder = toReadBooks.isEmpty 
        ? 0 
        : toReadBooks.map((b) => b.order).reduce((a, b) => a > b ? a : b);
    final book = Book(
      id: id,
      title: title,
      author: author,
      totalPages: totalPages,
      shelf: BookShelf.toRead,
      order: maxOrder + 1,
      coverImagePath: coverImagePath,
    );
    await _repo.upsert(book);
    await _load();
  }

  Future<void> updateBook({
    required String id,
    required String title,
    required String author,
    required int totalPages,
    String? coverImagePath,
    int? rating,
    String? review,
  }) async {
    final current = await _repo.getById(id);
    if (current == null) return;
    await _repo.upsert(
      current.copyWith(
        title: title,
        author: author,
        totalPages: totalPages,
        coverImagePath: coverImagePath,
        rating: rating ?? current.rating,
        review: review ?? current.review,
      ),
    );
    await _load();
  }

  Future<void> deleteBook(String id) async {
    // NOT: Okuma kayıtlarını silmiyoruz - streak korunması için
    // Loglar silinmeyecek, sadece kitap ve ilgili dosyalar silinecek
    
    // Kitabın kapağını sil
    final imageService = ImageStorageService();
    await imageService.deleteImage(id);
    
    // Kitabı sil
    await _repo.delete(id);
    await _load();
  }

  Future<void> markAsRead(String id, {String? review, int? finalMinutes, int? rating}) async {
    final current = await _repo.getById(id);
    if (current == null) return;
    // İlk kez okunduğunda readCount'u 1 yap
    final newReadCount = current.readCount == 0 ? 1 : current.readCount;
    await _repo.upsert(current.copyWith(
      shelf: BookShelf.read,
      currentPage: current.totalPages,
      readCount: newReadCount,
      review: review ?? current.review,
      totalMinutes: finalMinutes ?? current.totalMinutes,
      rating: rating ?? current.rating,
    ));
    await _load();
  }

  Future<void> restartReading(String id) async {
    final current = await _repo.getById(id);
    if (current == null) return;
    // Eğer kitap daha önce okunduysa (read shelf'indeyse), readCount'u artır
    final newReadCount = current.shelf == BookShelf.read 
        ? current.readCount + 1 
        : current.readCount;
    await _repo.upsert(current.copyWith(
      shelf: BookShelf.reading,
      currentPage: 0,
      readCount: newReadCount,
    ));
    await _load();
  }

  Future<void> updateCurrentPage(String id, int page) async {
    final current = await _repo.getById(id);
    if (current == null) return;
    await _repo.upsert(current.copyWith(currentPage: page));
    await _load();
  }

  Future<void> moveBookToShelf(String id, BookShelf targetShelf) async {
    final current = await _repo.getById(id);
    if (current == null) return;
    
    // Eğer aynı rafa taşınıyorsa işlem yapma
    if (current.shelf == targetShelf) return;
    
    // Raf değişikliğine göre currentPage'i ayarla
    int? newCurrentPage = current.currentPage;
    if (targetShelf == BookShelf.reading && current.shelf == BookShelf.toRead) {
      // Okuyacağım -> Okuyorum: sayfa 0'dan başla
      newCurrentPage = 0;
    } else if (targetShelf == BookShelf.read && current.shelf == BookShelf.reading) {
      // Okuyorum -> Okudum: kitabı tamamla
      newCurrentPage = current.totalPages;
    }
    
    // Yeni raftaki maksimum order değerini bul
    final targetShelfBooks = state.items.where((b) => b.shelf == targetShelf).toList();
    final maxOrder = targetShelfBooks.isEmpty 
        ? 0 
        : targetShelfBooks.map((b) => b.order).reduce((a, b) => a > b ? a : b);
    
    await _repo.upsert(current.copyWith(
      shelf: targetShelf,
      currentPage: newCurrentPage,
      order: maxOrder + 1,
    ));
    await _load();
  }

  Future<void> reorderBooks(BookShelf shelf, int oldIndex, int newIndex) async {
    final books = byShelf(shelf);
    if (oldIndex < 0 || oldIndex >= books.length || newIndex < 0 || newIndex >= books.length) {
      return;
    }
    
    final movedBook = books[oldIndex];
    final otherBooks = List<Book>.from(books)..removeAt(oldIndex);
    otherBooks.insert(newIndex, movedBook);
    
    // Order değerlerini güncelle
    for (int i = 0; i < otherBooks.length; i++) {
      await _repo.upsert(otherBooks[i].copyWith(order: i));
    }
    
    await _load();
  }
}

final booksVmProvider = StateNotifierProvider<BooksVm, BooksState>((ref) {
  final repo = ref.watch(booksRepositoryProvider);
  return BooksVm(repo);
});


