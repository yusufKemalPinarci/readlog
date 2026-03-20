import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../shared/widgets/book_scaffold.dart';
import '../../../shared/utils/image_helper.dart';
import '../../books/application/books_vm.dart';
import '../../books/domain/book.dart';
import '../../../shared/services/image_storage_service.dart';

final _bookProvider = FutureProvider.autoDispose.family<Book?, String>((ref, bookId) async {
  final vm = ref.watch(booksVmProvider.notifier);
  return vm.byId(bookId);
});

class EditCompletedBookScreen extends ConsumerStatefulWidget {
  const EditCompletedBookScreen({
    super.key,
    required this.bookId,
  });

  final String bookId;

  @override
  ConsumerState<EditCompletedBookScreen> createState() => _EditCompletedBookScreenState();
}

class _EditCompletedBookScreenState extends ConsumerState<EditCompletedBookScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _pagesCtrl;
  late final TextEditingController _reviewCtrl;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageStorageService _imageService = ImageStorageService();
  
  String? _coverImagePath;
  File? _selectedImage;
  int? _rating;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _authorCtrl = TextEditingController();
    _pagesCtrl = TextEditingController();
    _reviewCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _pagesCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  void _loadBookData(Book book) {
    _titleCtrl.text = book.title;
    _authorCtrl.text = book.author;
    _pagesCtrl.text = book.totalPages.toString();
    _reviewCtrl.text = book.review ?? '';
    _rating = book.rating;
    _coverImagePath = book.coverImagePath;
    
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile == null) return;

      if (!mounted) return;
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
    final title = _titleCtrl.text.trim();
    final author = _authorCtrl.text.trim();
    final pages = int.tryParse(_pagesCtrl.text.trim()) ?? 0;
    final review = _reviewCtrl.text.trim().isEmpty ? null : _reviewCtrl.text.trim();

    if (title.isEmpty || author.isEmpty || pages <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final vm = ref.read(booksVmProvider.notifier);

    // Resmi kaydet
    String? savedImagePath;
    if (_selectedImage != null) {
      savedImagePath = await _imageService.saveImage(widget.bookId, _selectedImage!.path);
    } else if (_coverImagePath == null) {
      // Eğer resim kaldırıldıysa, eski resmi sil
      await _imageService.deleteImage(widget.bookId);
    } else {
      savedImagePath = _coverImagePath;
    }

    await vm.updateBook(
      id: widget.bookId,
      title: title,
      author: author,
      totalPages: pages,
      coverImagePath: savedImagePath,
      rating: _rating,
      review: review,
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(_bookProvider(widget.bookId));

    return bookAsync.when(
      data: (book) {
        if (book == null) {
          return BookScaffold(
            appBar: AppBar(title: const Text('Kitap Bulunamadı')),
            body: const Center(child: Text('Kitap bulunamadı.')),
          );
        }

        // Sadece biten kitaplar için bu ekranı göster
        if (book.shelf != BookShelf.read) {
          return BookScaffold(
            appBar: AppBar(title: const Text('Hata')),
            body: const Center(child: Text('Bu ekran sadece biten kitaplar için kullanılabilir.')),
          );
        }

        // İlk yüklemede verileri doldur
        if (_titleCtrl.text.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadBookData(book);
          });
        }

        return BookScaffold(
          appBar: AppBar(
            title: const Text('Kitabı Düzenle', style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _save,
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kitap Kapağı
                Center(
                  child: GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: 120,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kapak Ekle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Başlık
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Kitap Adı *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Yazar
                TextField(
                  controller: _authorCtrl,
                  decoration: InputDecoration(
                    labelText: 'Yazar *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Sayfa Sayısı
                TextField(
                  controller: _pagesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Toplam Sayfa *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Puan
                Text(
                  'PUANLA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    final isFilled = starIndex <= (_rating ?? 0);
                    return IconButton(
                      onPressed: () {
                        setState(() {
                          _rating = starIndex == _rating ? null : starIndex;
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
                const SizedBox(height: 24),

                // Review
                Text(
                  'KİTAP HAKKINDA DÜŞÜNCELERİN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _reviewCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Bu kitap sana ne hissettirdi? En sevdiğin bölüm neydi?',
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Kaydet Butonu
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Kaydet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => BookScaffold(
        appBar: AppBar(title: const Text('Kitabı Düzenle')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => BookScaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: Center(child: Text('Hata: $err')),
      ),
    );
  }
}
