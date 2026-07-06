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

  /// Reload from the (singleton) repository — used after a backup import so the
  /// list reflects restored data without recreating the provider (T2.4).
  Future<void> reload() async {
    await _load();
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
    // T2.7: count a completion here (completing a re-read increments; abandoning
    // a restart does not). Only when transitioning INTO the read shelf.
    final newReadCount =
        current.shelf == BookShelf.read ? current.readCount : current.readCount + 1;
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
    // T2.7: do NOT increment readCount here — restarting/abandoning shouldn't
    // count; completing (markAsRead) does. Stamp lastStartedAt so the finish
    // flow sums only this pass's logs.
    await _repo.upsert(current.copyWith(
      shelf: BookShelf.reading,
      currentPage: 0,
      lastStartedAt: DateTime.now(),
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
    if (oldIndex < 0 || oldIndex >= books.length) return;

    // T1.9: ReorderableListView reports newIndex in [0, length]; when moving an
    // item downward the target shifts by one once the item is removed, and
    // newIndex == length means "drop at the end".
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= books.length) newIndex = books.length - 1;
    if (newIndex == oldIndex) return;

    final reordered = List<Book>.from(books);
    final movedBook = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, movedBook);

    // T1.9: reassign order and persist in a single batched save.
    final updated = <Book>[
      for (int i = 0; i < reordered.length; i++) reordered[i].copyWith(order: i),
    ];
    await _repo.upsertAll(updated);
    await _load();
  }
}

final booksVmProvider = StateNotifierProvider<BooksVm, BooksState>((ref) {
  final repo = ref.watch(booksRepositoryProvider);
  return BooksVm(repo);
});


