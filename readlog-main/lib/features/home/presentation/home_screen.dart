import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../app/router/app_router.dart';
import '../../books/application/books_vm.dart';
import '../../books/domain/book.dart';
import '../../profile/application/profile_providers.dart';
import '../../../shared/widgets/delete_book_dialog.dart';
import '../../../shared/widgets/book_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _searchController;
  late final PageController _pageController;
  BookShelf _selectedShelf = BookShelf.toRead;
  bool _isGridView = false;
  bool _isSearching = false;
  String _searchQuery = '';
  SortOption _sortOption = SortOption.manual;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _pageController = PageController(initialPage: 0);
    
    // Query parameter'dan shelf index'i al
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final tabParam = uri.queryParameters['tab'];
      if (tabParam != null) {
        final tabIndex = int.tryParse(tabParam);
        if (tabIndex != null && tabIndex >= 0 && tabIndex < 3) {
          setState(() {
            _selectedShelf = BookShelf.values[tabIndex];
          });
          _pageController.jumpToPage(tabIndex);
        }
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedShelf = BookShelf.values[index];
      _searchQuery = '';
      _searchController.clear();
      _isSearching = false;
    });
  }

  void _animateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(booksVmProvider);
    final vm = ref.read(booksVmProvider.notifier);
    final profileAsync = ref.watch(profileProvider);

    return BookScaffold(
      appBar: AppBar(
          leading: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                )
              : Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => context.push(Routes.profile),
                    child: profileAsync.when(
                      data: (profile) => CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: profile.avatarImagePath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(profile.avatarImagePath!),
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.primary);
                                  },
                                ),
                              )
                            : Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      ),
                      loading: () => CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      ),
                      error: (_, __) => CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                ),
          titleSpacing: _isSearching ? 0 : null,
          title: _isSearching
              ? Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Kitap ara...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 15,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                )
              : const Text(
                  'Libris',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
          actions: [
            if (!_isSearching) ...[
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Ara',
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    key: ValueKey(_isGridView),
                  ),
                ),
                tooltip: _isGridView ? 'Liste Görünümü' : 'Grid Görünümü',
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
              ),
            ],

            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sırala',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.sort_by_alpha),
                            title: const Text('Başlık (A-Z)'),
                            selected: _sortOption == SortOption.title,
                            onTap: () {
                              setState(() => _sortOption = SortOption.title);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: const Text('Yazar (A-Z)'),
                            selected: _sortOption == SortOption.author,
                            onTap: () {
                              setState(() => _sortOption = SortOption.author);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.access_time),
                            title: const Text('Son Eklenenler'),
                            selected: _sortOption == SortOption.recent,
                            onTap: () {
                              setState(() => _sortOption = SortOption.recent);
                              Navigator.pop(context);
                            },
                          ),
                          if (_selectedShelf == BookShelf.reading)
                            ListTile(
                              leading: const Icon(Icons.percent),
                              title: const Text('İlerleme (Çoktan aza)'),
                              selected: _sortOption == SortOption.progress,
                              onTap: () {
                                setState(() => _sortOption = SortOption.progress);
                                Navigator.pop(context);
                              },
                            ),
                          if (_selectedShelf == BookShelf.read)
                            ListTile(
                              leading: const Icon(Icons.star),
                              title: const Text('Puana Göre'),
                              selected: _sortOption == SortOption.rating,
                              onTap: () {
                                setState(() => _sortOption = SortOption.rating);
                                Navigator.pop(context);
                              },
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.addBook),
          backgroundColor: Theme.of(context).colorScheme.primary,
          icon: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onPrimary),
          label: Text(
            'Kitap Ekle',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        body: Column(
          children: [
            // Tab-style shelf selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _ShelfTab(
                      label: 'Listem',
                      icon: Icons.bookmark_outline,
                      isSelected: _selectedShelf == BookShelf.toRead,
                      onTap: () => _animateToPage(0),
                    ),
                    _ShelfTab(
                      label: 'Okuyor',
                      icon: Icons.auto_stories_rounded,
                      isSelected: _selectedShelf == BookShelf.reading,
                      onTap: () => _animateToPage(1),
                    ),
                    _ShelfTab(
                      label: 'Biten',
                      icon: Icons.check_circle_outline_rounded,
                      isSelected: _selectedShelf == BookShelf.read,
                      onTap: () => _animateToPage(2),
                    ),
                  ],
                ),
              ),
            ),
            // Books list based on selected shelf — swipeable
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: [
                    _BooksList(
                      books: vm.byShelf(BookShelf.toRead),
                      shelf: BookShelf.toRead,
                      onMoveToShelf: (book, targetShelf) => vm.moveBookToShelf(book.id, targetShelf),
                      onReorder: (oldIndex, newIndex) => vm.reorderBooks(BookShelf.toRead, oldIndex, newIndex),
                      onTap: (b) => context.push(Routes.bookDetail(b.id)),
                      menuBuilder: (context, book) => [
                        PopupMenuItem(
                          value: _MenuAction.startReading,
                          child: Row(children: const [Icon(Icons.play_arrow), SizedBox(width: 10), Text('Kitaba Başla')]),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.edit,
                          child: Row(children: const [Icon(Icons.edit_outlined), SizedBox(width: 10), Text('Düzenle')]),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.delete,
                          child: Row(children: const [Icon(Icons.delete_outline), SizedBox(width: 10), Text('Sil')]),
                        ),
                      ],
                      onMenuSelected: (action, book) async {
                        switch (action) {
                          case _MenuAction.startReading:
                            await vm.moveBookToShelf(book.id, BookShelf.reading);
                            return;
                          case _MenuAction.edit:
                            // toRead → edit metadata screen (T1.10)
                            context.push(Routes.editBook(book.id));
                            return;
                          case _MenuAction.delete:
                            await showDialog(
                              context: context,
                              builder: (context) => DeleteBookDialog(
                                onConfirm: () => vm.deleteBook(book.id),
                              ),
                            );
                            return;
                          case _MenuAction.finishBook:
                            context.push(Routes.finishReadingFlow(book.id));
                            return;
                          case _MenuAction.finish:
                          case _MenuAction.restart:
                          case _MenuAction.continueReading:
                            return;
                        }
                      },
                      isGridView: _isGridView,
                      searchQuery: _searchQuery,
                      sortOption: _sortOption,
                    ),
                    _BooksList(
                      books: vm.byShelf(BookShelf.reading),
                      shelf: BookShelf.reading,
                      onMoveToShelf: (book, targetShelf) => vm.moveBookToShelf(book.id, targetShelf),
                      onReorder: (oldIndex, newIndex) => vm.reorderBooks(BookShelf.reading, oldIndex, newIndex),
                      onTap: (b) => context.push(Routes.bookDetail(b.id)),
                      onContinueReading: (b) => context.push(Routes.activeReadingFor(b.id)),
                      menuBuilder: (context, book) => [
                        PopupMenuItem(
                          value: _MenuAction.continueReading,
                          child: Row(children: const [Icon(Icons.play_arrow), SizedBox(width: 10), Text('Oku')]),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.edit,
                          child: Row(children: const [Icon(Icons.edit_outlined), SizedBox(width: 10), Text('Düzenle')]),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.finish,
                          child: Row(children: const [Icon(Icons.check_circle_outline), SizedBox(width: 10), Text('Kitabı Bitir')]),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.delete,
                          child: Row(children: const [Icon(Icons.delete_outline), SizedBox(width: 10), Text('Sil')]),
                        ),
                      ],
                      onMenuSelected: (action, book) async {
                        switch (action) {
                          case _MenuAction.continueReading:
                            context.push(Routes.activeReadingFor(book.id));
                            return;
                          case _MenuAction.edit:
                            // reading → edit metadata screen (T1.10)
                            context.push(Routes.editBook(book.id));
                            return;
                          case _MenuAction.finishBook:
                            context.push(Routes.finishReadingFlow(book.id));
                            return;
                          case _MenuAction.finish:
                            context.push(Routes.finishReadingFor(book.id), extra: {'isDirectFinish': true});
                            return;
                          case _MenuAction.delete:
                            await showDialog(
                              context: context,
                              builder: (context) => DeleteBookDialog(
                                onConfirm: () => vm.deleteBook(book.id),
                              ),
                            );
                            return;
                          default:
                            return;
                        }
                      },
                      isGridView: _isGridView,
                      searchQuery: _searchQuery,
                      sortOption: _sortOption,
                    ),
                    _BooksList(
                      books: vm.byShelf(BookShelf.read),
                      shelf: BookShelf.read,
                      onMoveToShelf: (book, targetShelf) => vm.moveBookToShelf(book.id, targetShelf),
                      onReorder: (oldIndex, newIndex) => vm.reorderBooks(BookShelf.read, oldIndex, newIndex),
                      onTap: (b) => context.push(Routes.bookDetail(b.id)),
                      menuBuilder: (context, book) => [
                        PopupMenuItem(
                          value: _MenuAction.edit,
                          child: Row(children: const [Icon(Icons.edit_outlined), SizedBox(width: 10), Text('Düzenle')]),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.restart,
                          child: Row(children: const [Icon(Icons.refresh), SizedBox(width: 10), Text('Tekrar Oku')]),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.delete,
                          child: Row(children: const [Icon(Icons.delete_outline), SizedBox(width: 10), Text('Kitabı Sil')]),
                        ),
                      ],
                      onMenuSelected: (action, book) async {
                        switch (action) {
                          case _MenuAction.restart:
                            await vm.restartReading(book.id);
                            return;
                          case _MenuAction.delete:
                            await showDialog(
                              context: context,
                              builder: (context) => DeleteBookDialog(
                                onConfirm: () => vm.deleteBook(book.id),
                              ),
                            );
                            return;
                          case _MenuAction.finishBook:
                            context.push(Routes.finishReadingFlow(book.id));
                            return;
                          case _MenuAction.edit:
                            context.push(Routes.editCompletedBook(book.id));
                            return;
                          case _MenuAction.finish:
                          case _MenuAction.startReading:
                          case _MenuAction.continueReading:
                            return;
                        }
                      },
                      isGridView: _isGridView,
                      searchQuery: _searchQuery,
                      sortOption: _sortOption,
                    ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

enum SortOption { manual, title, author, recent, progress, rating }
enum _MenuAction { edit, finish, finishBook, restart, delete, startReading, continueReading }

typedef _MenuBuilder = List<PopupMenuEntry<_MenuAction>> Function(BuildContext context, Book book);

class _ShelfTab extends StatelessWidget {
  const _ShelfTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kitap kapağı widget'ı oluşturur
Widget _buildBookCover(Book book, double width, double height) {
  if (book.coverImagePath != null) {
    try {
      final file = File(book.coverImagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: (width.isFinite ? width * 2 : 256).toInt(),
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultBookIcon(width, height);
            },
          ),
        );
      }
    } catch (e) {
      // Dosya erişim hatası, varsayılan ikonu göster
    }
  }
  return _buildDefaultBookIcon(width, height);
}

/// Varsayılan kitap ikonu widget'ı
Widget _buildDefaultBookIcon(double width, double height) {
  final iconSize = width > 60 ? 36.0 : 28.0;
  return Builder(
    builder: (context) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      final alpha1 = width > 60 ? 0.15 : 0.2;
      final alpha2 = width > 60 ? 0.08 : 0.1;
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withValues(alpha: alpha1),
              primaryColor.withValues(alpha: alpha2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.menu_book_outlined,
          color: primaryColor,
          size: iconSize,
        ),
      );
    },
  );
}

class _BooksList extends StatefulWidget {
  const _BooksList({
    required this.books,
    required this.shelf,
    required this.onMoveToShelf,
    required this.onReorder,
    required this.menuBuilder,
    required this.onMenuSelected,
    this.onTap,
    this.onContinueReading,
    this.isGridView = false,
    this.searchQuery = '',
    this.sortOption = SortOption.recent,
  });

  final List<Book> books;
  final BookShelf shelf;
  final void Function(Book book, BookShelf targetShelf) onMoveToShelf;
  final void Function(int oldIndex, int newIndex) onReorder;
  final _MenuBuilder menuBuilder;
  final Future<void> Function(_MenuAction action, Book book) onMenuSelected;
  final void Function(Book book)? onTap;
  final void Function(Book book)? onContinueReading;
  final bool isGridView;
  final String searchQuery;
  final SortOption sortOption;

  @override
  State<_BooksList> createState() => _BooksListState();
}

class _BooksListState extends State<_BooksList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Filter books based on search query
    final filteredBooks = widget.searchQuery.isEmpty
        ? widget.books.toList() // Copy
        : widget.books.where((book) {
            final title = book.title.toLowerCase();
            final author = book.author.toLowerCase();
            final category = (book.category ?? '').toLowerCase();
            final query = widget.searchQuery;
            return title.contains(query) || author.contains(query) || category.contains(query);
          }).toList();

    // Sort books
    switch (widget.sortOption) {
      case SortOption.manual:
        filteredBooks.sort((a, b) => a.order.compareTo(b.order));
        break;
      case SortOption.title:
        filteredBooks.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.author:
        filteredBooks.sort((a, b) => a.author.compareTo(b.author));
        break;
      case SortOption.recent:
        // Use ID (timestamp) or explicit field
        filteredBooks.sort((a, b) => b.id.compareTo(a.id));
        break;
      case SortOption.progress:
        filteredBooks.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case SortOption.rating:
        filteredBooks.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
    }

    if (filteredBooks.isEmpty) {
      final isSearchEmpty = widget.searchQuery.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSearchEmpty ? Icons.search_off_rounded : Icons.menu_book_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isSearchEmpty
                    ? 'Sonuç bulunamadı'
                    : widget.shelf == BookShelf.reading 
                        ? 'Henüz okuduğunuz bir kitap yok.' 
                        : 'İlk kitabını ekle!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearchEmpty
                    ? 'Aradığınız kitap bulunamadı.\nFarklı bir arama terimi deneyin.'
                    : widget.shelf == BookShelf.reading
                        ? 'Okumaya başlamak için bir kitap seçin'
                        : 'Okumak istediğin kitapları buraya ekleyerek\nokuma yolculuğuna başla',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              if (widget.shelf == BookShelf.toRead && !isSearchEmpty)
                Builder(
                  builder: (context) {
                    return FilledButton.icon(
                      onPressed: () => context.push(Routes.addBook),
                      icon: const Icon(Icons.add_rounded, size: 24),
                      label: const Text('Kitap Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    // Grid view
    if (widget.isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 100,
        ),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: filteredBooks.length,
        itemBuilder: (context, index) {
          return _buildGridBookCard(context, filteredBooks[index], index);
        },
      );
    }

    // List view (original).
    // T1.9: reorderBooks operates on the unfiltered, order-sorted shelf list, so
    // dragging is only coherent in manual sort with no active search. Disable the
    // built-in long-press handles and expose an explicit handle only in that mode
    // (see _buildBookCard) — otherwise displayed indices wouldn't map back.
    final canReorder =
        widget.sortOption == SortOption.manual && widget.searchQuery.isEmpty;
    return ReorderableListView(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 100,
      ),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      buildDefaultDragHandles: false,
      onReorder: canReorder ? widget.onReorder : (_, __) {},
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 8,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
      children: [
        for (int index = 0; index < filteredBooks.length; index++)
          _buildBookCard(context, filteredBooks[index], index),
      ],
    );
  }

  Widget _buildBookCard(BuildContext context, Book book, int index) {
    return RepaintBoundary(
      key: ValueKey(book.id),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 350 + (index * 40)),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (16 * (1 - value)).toDouble()),
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: widget.onTap != null ? () => widget.onTap!(book) : null,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Drag Handle (only in manual sort with no active search)
                    if (widget.sortOption == SortOption.manual && widget.searchQuery.isEmpty) ...[
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.25),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Card Content
                    Expanded(
                      child: _buildCardContent(context, book, false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildCardContent(BuildContext context, Book book, bool isFeedback) {
    return Row(
      children: [
        _buildBookCover(book, 64, 96),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                book.author,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (book.shelf == BookShelf.read && book.rating != null && book.rating! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < book.rating! ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ),
              if (!isFeedback) ...[
                  if (widget.shelf == BookShelf.reading) ...[
                      const SizedBox(height: 8),
                         ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (book.totalPages > 0) ? (book.currentPage ?? 0) / book.totalPages : 0,
                              minHeight: 6,
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                             '%${((book.totalPages > 0 ? (book.currentPage ?? 0) / book.totalPages : 0) * 100).round()}',
                             style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: widget.onContinueReading != null ? () => widget.onContinueReading!(book) : null,
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: const Text('Oku', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                          ),
                  ] else if (widget.shelf == BookShelf.toRead) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                            onPressed: () async {
                                await widget.onMenuSelected(_MenuAction.startReading, book);
                            },
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('Kitaba Başla', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: BorderSide(color: Theme.of(context).colorScheme.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ),
                    ),
                  ],
              ],
            ],
          ),
        ),
        if (!isFeedback)
        PopupMenuButton<_MenuAction>(
        icon: Icon(Icons.more_vert, color: Colors.grey[600]),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
        ),
        itemBuilder: (context) => widget.menuBuilder(context, book),
        onSelected: (a) => widget.onMenuSelected(a, book),
        ),
      ],
    );
  }



  Widget _buildGridBookCard(BuildContext context, Book book, int index) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (16 * (1 - value)).toDouble()),
            child: child,
          ),
        );
      },
      child: _buildGridCardContent(context, book),
    ),
    );
  }

  Widget _buildGridCardContent(BuildContext context, Book book) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap != null ? () => widget.onTap!(book) : null,
          borderRadius: BorderRadius.circular(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Book cover
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                   Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildBookCover(book, double.infinity, double.infinity),
                  ),
                  if (book.shelf == BookShelf.read)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<_MenuAction>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.more_horiz, size: 16, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => widget.menuBuilder(context, book),
                        onSelected: (a) => widget.onMenuSelected(a, book),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Book info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.author,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Buttons and progress
                    if (widget.shelf == BookShelf.reading) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (book.totalPages > 0) ? (book.currentPage ?? 0) / book.totalPages : 0,
                              minHeight: 4,
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '%${((book.totalPages > 0 ? (book.currentPage ?? 0) / book.totalPages : 0) * 100).round()}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: OutlinedButton(
                              onPressed: widget.onContinueReading != null ? () => widget.onContinueReading!(book) : null,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Oku', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (widget.shelf == BookShelf.toRead) ...[
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: OutlinedButton(
                              onPressed: () async {
                                await widget.onMenuSelected(_MenuAction.startReading, book);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Başla', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}


