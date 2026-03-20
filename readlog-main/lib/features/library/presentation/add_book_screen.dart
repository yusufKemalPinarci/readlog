import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../books/application/books_vm.dart';
import '../../books/domain/book.dart';
import '../../../shared/services/image_storage_service.dart';
import '../../../shared/services/permission_service.dart';
import '../../../shared/services/open_library_service.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../../../shared/utils/image_helper.dart';
import 'package:image_cropper/image_cropper.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController authorCtrl;
  late final TextEditingController pagesCtrl;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageStorageService _imageService = ImageStorageService();
  final OpenLibraryService _openLibraryService = OpenLibraryService();
  final TextEditingController _searchController = TextEditingController();
  String? _coverImagePath;
  File? _selectedImage;
  bool _showSearch = true;
  bool _isSearching = false;
  List<OpenLibraryBook> _searchResults = [];
  String? _searchError;
  int? _rating; // Added rating state
  BookShelf? _currentShelf; // Track current shelf to show rating if 'read'

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController();
    authorCtrl = TextEditingController();
    pagesCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.bookId;
      if (id != null) {
        final book = ref.read(booksVmProvider.notifier).byId(id);
        if (book != null) {
          titleCtrl.text = book.title;
          authorCtrl.text = book.author;
          pagesCtrl.text = book.totalPages.toString();
          _coverImagePath = book.coverImagePath;
          _rating = book.rating;
          _currentShelf = book.shelf;
          if (_coverImagePath != null) {
            try {
              final file = File(_coverImagePath!);
              if (file.existsSync()) {
                setState(() {
                  _selectedImage = file;
                });
              }
            } catch (e) {
              // Dosya erişim hatası
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    authorCtrl.dispose();
    pagesCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchBooks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _openLibraryService.searchBooks(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Arama yapılırken hata oluştu: ${e.toString()}';
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  Future<void> _selectBook(OpenLibraryBook book) async {
    // Kitap bilgilerini form alanlarına doldur
    titleCtrl.text = book.title;
    authorCtrl.text = book.author ?? '';

    // Sayfa sayısını doldur - yoksa editions API'den çek
    if (book.pageCount != null) {
      pagesCtrl.text = book.pageCount.toString();
    } else if (book.editionKey != null) {
      pagesCtrl.text = '';
      try {
        final pages = await _openLibraryService.fetchPageCount(book.editionKey!);
        if (pages != null && mounted && pagesCtrl.text.isEmpty) {
          pagesCtrl.text = pages.toString();
        }
      } catch (_) {
        // Sayfa sayısı opsiyonel, hata yoksayılır
      }
    } else {
      pagesCtrl.text = '';
    }

    // Kapak resmini indir ve kaydet
    if (book.coverImageUrl != null) {
      try {
        final response = await http.get(Uri.parse(book.coverImageUrl!));
        if (response.statusCode == 200) {
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory('${appDir.path}/book_covers');
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }

          final bookId = widget.bookId ?? DateTime.now().microsecondsSinceEpoch.toString();
          final filePath = '${imagesDir.path}/cover_$bookId.jpg';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          setState(() {
            _selectedImage = file;
            _coverImagePath = filePath;
            _showSearch = false;
          });
        }
      } catch (e) {
        // Resim indirme hatası görmezden gel, sadece bilgileri doldur
        setState(() {
          _showSearch = false;
        });
      }
    } else {
      setState(() {
        _showSearch = false;
      });
    }
  }

  void _showManualEntry() {
    setState(() {
      _showSearch = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // İzin kontrolü
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        hasPermission = await PermissionService.requestCameraPermission(context);
      } else {
        hasPermission = await PermissionService.requestPhotoLibraryPermission(context);
      }

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? 'Kamera izni gerekli'
                    : 'Galeri izni gerekli',
              ),
            ),
          );
        }
        return;
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        final croppedPath = await ImageHelper.cropImage(
          context: context,
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 2, ratioY: 3),
          lockAspectRatio: false,
        );
        
        if (croppedPath != null) {
          setState(() {
            _selectedImage = File(croppedPath);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resim seçilirken hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Kameradan Çek'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Resmi Kaldır', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _coverImagePath = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = titleCtrl.text.trim();
    final author = authorCtrl.text.trim();
    final pages = int.tryParse(pagesCtrl.text.trim()) ?? 0;

    if (title.isEmpty || author.isEmpty || pages <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
        );
      }
      return;
    }

    final vm = ref.read(booksVmProvider.notifier);
    final id = widget.bookId ?? DateTime.now().microsecondsSinceEpoch.toString();

    // Resmi kaydet
    String? savedImagePath;
    if (_selectedImage != null) {
      savedImagePath = await _imageService.saveImage(id, _selectedImage!.path);
    } else if (_coverImagePath == null && widget.bookId != null) {
      // Eğer resim kaldırıldıysa (edit modunda), eski resmi sil
      await _imageService.deleteImage(id);
    }

    if (widget.bookId == null) {
      await vm.addBook(
        title: title,
        author: author,
        totalPages: pages,
        coverImagePath: savedImagePath,
      );
    } else {
      await vm.updateBook(
        id: id,
        title: title,
        author: author,
        totalPages: pages,
        coverImagePath: savedImagePath,
        rating: _rating,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bookId != null;
    
    // Eğer düzenleme modundaysa direkt formu göster
    if (isEdit) {
      return _buildForm(context, isEdit);
    }

    // Arama ekranı veya form ekranı
    if (_showSearch) {
      return _buildSearchScreen(context);
    }

    return _buildForm(context, isEdit);
  }

  Future<void> _scanBarcode() async {
    // Mobilde çalışacak, emülatörde test etmek zor olabilir.
    // İzinler BarcodeScannerScreen içinde yönetiliyor (MobileScanner).
    final result = await context.push(Routes.scanner);
    if (result != null && result is String) {
      _searchController.text = result;
      _searchBooks();
    }
  }

  Widget _buildSearchScreen(BuildContext context) {
    return BookScaffold(
      appBar: AppBar(
        title: const Text('Kitap Ara', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Kitap adı, yazar veya ISBN...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _searchError = null;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                    ),
                    onSubmitted: (_) => _searchBooks(),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.icon(
                    onPressed: _isSearching ? null : _searchBooks,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isSearching ? 'Aranıyor...' : 'Ara'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: OutlinedButton.icon(
                  onPressed: _showManualEntry,
                  icon: const Icon(Icons.edit),
                  label: const Text('Kendi Ekle'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _searchError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Sonuç bulunamadı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Farklı bir arama terimi deneyin',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Kitap ara',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kitap adı veya yazar adı ile arama yapın',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _buildBookResultCard(book);
      },
    );
  }

  Widget _buildBookResultCard(OpenLibraryBook book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectBook(book),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Kitap kapağı
              if (book.coverImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    book.coverImageUrl!,
                    width: 60,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.menu_book, color: Colors.grey),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.grey),
                ),
              const SizedBox(width: 16),
              // Kitap bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.author != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.author!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (book.pageCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${book.pageCount} sayfa',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isEdit) {
    return BookScaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Kitabı Düzenle' : 'Yeni Kitap Ekle',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kitap Kapağı Seçimi
          Center(
            child: GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: 160,
                height: 240,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _selectedImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              _selectedImage!,
                              width: 160,
                              height: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholder(context);
                              },
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                                onPressed: _showImageSourceDialog,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildPlaceholder(context),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _TextFieldCard(
            label: 'Kitap Adı',
            hintText: 'Örn. Suç ve Ceza',
            icon: Icons.menu_book_outlined,
            controller: titleCtrl,
          ),
          const SizedBox(height: 12),
          _TextFieldCard(
            label: 'Yazar Adı',
            hintText: 'Örn. Fyodor Dostoyevski',
            icon: Icons.person_outline,
            controller: authorCtrl,
          ),
          const SizedBox(height: 12),
          _TextFieldCard(
            label: 'Sayfa Sayısı',
            hintText: 'Örn. 350',
            icon: Icons.numbers,
            keyboardType: TextInputType.number,
            controller: pagesCtrl,
          ),
          if (_currentShelf == BookShelf.read) ...[
            const SizedBox(height: 24),
            Text(
              'Puanın',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isFilled = _rating != null && starIndex <= _rating!;
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _rating = starIndex;
                    });
                  },
                  icon: Icon(
                    isFilled ? Icons.star : Icons.star_border,
                    size: 40,
                    color: isFilled ? Colors.amber : Colors.grey,
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.add),
            label: Text(isEdit ? 'Değişiklikleri Kaydet' : 'Kitap Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Kitap Kapağı\nEkle',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hintText,
                  border: InputBorder.none,

                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


