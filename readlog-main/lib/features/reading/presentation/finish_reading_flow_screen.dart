import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/image_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../books/application/books_vm.dart';
import '../application/finish_reading_vm.dart';
import '../../../app/router/app_router.dart';
import '../../../shared/widgets/book_loading_widget.dart';
import '../../../shared/widgets/book_scaffold.dart';

class FinishReadingFlowScreen extends ConsumerStatefulWidget {
  const FinishReadingFlowScreen({
    super.key,
    required this.bookId,
    this.initialMinutes,
    this.initialDurationSeconds,
    this.recordingPath,
    this.isDirectFinish = false,
  });

  final String bookId;
  final int? initialMinutes;
  final int? initialDurationSeconds;
  final String? recordingPath;
  final bool isDirectFinish;

  @override
  ConsumerState<FinishReadingFlowScreen> createState() => _FinishReadingFlowScreenState();
}

class _FinishReadingFlowScreenState extends ConsumerState<FinishReadingFlowScreen> {
  late final PageController _pageController;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _pageCtrl;
  FinishReadingResult? _lastResult;
  int _currentPageIndex = 0;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    // Manuel bitirmede direkt Review adımına git (index 0)
    // Normal okuma oturumunda NoteStep'ten başla (index 0)
    _pageController = PageController(
      initialPage: widget.isDirectFinish ? 0 : 0, // Her iki durumda da 0, çünkü PageView'deki sıralama değişti
    );
    _pageController.addListener(() {
      if (_pageController.hasClients && _pageController.page != null) {
        setState(() {
          _currentPageIndex = _pageController.page!.round();
        });
      }
    });
    _noteCtrl = TextEditingController();
    _titleCtrl = TextEditingController();
    _pageCtrl = TextEditingController();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = ref.read(finishReadingVmProvider(widget.bookId).notifier);
      if (widget.initialDurationSeconds != null) {
        vm.setDurationSeconds(widget.initialDurationSeconds!);
      } else if (widget.initialMinutes != null) {
        vm.setMinutes(widget.initialMinutes!);
      }
      // Ses kaydı dosya yolunu ayarla
      if (widget.recordingPath != null) {
        vm.setAudioFilePath(widget.recordingPath);
        // Varsayılan başlık
        _titleCtrl.text = "Sesli Okuma Oturumu";
        vm.setTitle(_titleCtrl.text);
      } else {
         // Varsayılan başlık
         _titleCtrl.text = "Okuma Oturumu";
         vm.setTitle(_titleCtrl.text);
      }
      
      // Eğer direkt bitirme ise sayfa sayısını sona ayarla ve başlığı son kayıt olarak ayarla
      if (widget.isDirectFinish) {
        final book = ref.read(booksVmProvider.notifier).byId(widget.bookId);
        if (book != null) {
          vm.setPageAtEnd(book.totalPages);
          // Direkt bitirme için özel başlık
          _titleCtrl.text = "Son Kayıt";
          vm.setTitle(_titleCtrl.text);
        }
        // Eski okuma loglarından toplam süreyi çek
        await vm.loadTotalMinutesForBook();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _noteCtrl.dispose();
    _titleCtrl.dispose();
    _pageCtrl.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    await _pageController.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  void _shareBookCompletion(String bookReview) {
      SharePlus.instance.share(ShareParams(text: 'Libris ile bir kitabı daha bitirdim! İşte düşüncelerim: $bookReview'));
  }

  @override
  Widget build(BuildContext context) {
    final bookId = widget.bookId;
    final book = ref.watch(booksVmProvider.notifier).byId(bookId);
    final state = ref.watch(finishReadingVmProvider(bookId));
    final vm = ref.read(finishReadingVmProvider(bookId).notifier);

    final totalPages = book?.totalPages ?? 0;
    final initialPage = state.pageAtEnd ?? 0;
    if (_pageCtrl.text.isEmpty && totalPages > 0) {
      _pageCtrl.text = initialPage.toString();
    }

    return PopScope(
      canPop: !state.isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && state.isSaving) {
          // Kayıt sırasında geri dönmeye çalışıldı, iptal et
        }
      },
      child: BookScaffold(
        appBar: AppBar(
          leading: state.isSaving
              ? null
              : IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
          title: const Text('Okumayı Bitir', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(widget.isDirectFinish ? 1 : 3, (index) {
                  // Manuel bitirmede: sadece Review adımı (PageView index 0)
                  // Normal okuma oturumunda: Note (0), Page (1), Review (2)
                  final isActive = widget.isDirectFinish 
                      ? (_currentPageIndex == 0) // Manuel bitirmede sadece Review adımı aktif
                      : (_currentPageIndex == index && _currentPageIndex < 3); // Normal okuma oturumunda ilk 3 adım
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      body: state.isSaving
          ? const BookLoadingWidget(message: 'Kaydediliyor...')
          : Stack(
            children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
                  children: [
          // Normal okuma oturumunda: Oturum özeti adımı göster
          // Manuel bitirmede: Bu adımı atla, direkt Review adımına git
          if (!widget.isDirectFinish)
            _NoteStep(
              noteController: _noteCtrl,
              titleController: _titleCtrl,
              imagePath: state.noteFilePath,
              onImageSelected: (path) => vm.setNoteFilePath(path),
              isDirectFinish: false,
              onAction: () async {
                FocusScope.of(context).unfocus();
                vm.setNote(_noteCtrl.text);
                vm.setTitle(_titleCtrl.text);
                // Oturum özetinde süre girişi yok, sadece oturumdan gelen süreyi kullan
                // Eğer initialMinutes varsa zaten ayarlanmış, yoksa 0 olarak kalacak
                // Sayfa adımına geç
                _next();
              },
            ),
          if (!widget.isDirectFinish)
            _PageStep(
              totalPages: totalPages,
              controller: _pageCtrl,
              bookId: bookId,
              onSave: () async {
              FocusScope.of(context).unfocus();
              final page = int.tryParse(_pageCtrl.text) ?? 0;
              vm.setPageAtEnd(page);
              
              if (page >= totalPages) {
                // Kitap bitiyor, Review adımına geç
                _next();
              } else {
                // Kitap bitmiyor, kaydet ve çık
                try {
                  final result = await vm.saveAndMarkRead();
                  if (!context.mounted) return;

                  setState(() {
                    _lastResult = result;
                  });

                  // T2.13: replace the stack so back-nav can't reach the stale
                  // (already-saved) ActiveReadingScreen.
                  if (result.shouldShowStreak) {
                    context.go(Routes.streak);
                  } else {
                    context.go('${Routes.home}?tab=1');
                  }
                } catch (e) {
                   if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e')),
                    );
                  }
                }
              }
            },
          ),
          // Review Step (Kitap bitirme adımı)
          // Normal okuma oturumunda: Sadece rating ve süre (review yok)
          // Manuel bitirmede: Rating, süre ve review (kitap hakkında düşünceler)
          _ReviewStep(
             isDirectFinish: widget.isDirectFinish,
             onSave: () async {
               try {
                  final result = await vm.saveAndMarkRead();
                  if (!context.mounted) return;

                  setState(() {
                    _lastResult = result;
                  });

                  if (result.isBookCompleted) {
                     _confettiController.play();
                     
                     // Show Share Dialog
                     await showDialog(
                       context: context,
                       builder: (context) => AlertDialog(
                         title: const Text('Tebrikler! 🎉'),
                         content: const Text('Bir kitabı daha bitirdin! Başarını paylaşmak ister misin?'),
                         actions: [
                           TextButton(
                             onPressed: () => Navigator.pop(context),
                             child: const Text('Hayır'),
                            ),
                           FilledButton(
                             onPressed: () {
                               Navigator.pop(context);
                               _shareBookCompletion(state.bookReview ?? '');
                             },
                             child: const Text('Paylaş'),
                           ),
                         ],
                       ),
                     );
                  }

                  // Bitirme sonrası yönlendirme.
                  // T2.13: replace the stack (go) instead of pop()+push() so the
                  // now-saved ActiveReadingScreen underneath can't be reached via
                  // back-nav and re-saved (duplicate logs).
                  if (context.mounted) {
                    if (result.shouldShowStreak) {
                      context.go(Routes.streak);
                    } else {
                      context.go('${Routes.home}?tab=1');
                    }
                  }
               } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e')),
                    );
                  }
               }
             },
             onReviewChanged: vm.setBookReview,
             onNoteChanged: vm.setNote,
             onImageSelected: vm.setNoteFilePath,
             imagePath: state.noteFilePath,
             onHoursChanged: vm.setFinalTotalMinutes,
             onRatingChanged: vm.setRating,
             initialMinutes: state.minutes,
             showTimeInput: widget.isDirectFinish,
          ),
          _CongratsStep(
            totalPages: totalPages,
            result: _lastResult,
            onDone: () {
              // Önce finish flow sayfasını stack'ten kaldır
              if (context.canPop()) {
                context.pop();
              }
              
              // Eğer streak gösterilmeli ise streak sayfasına git
              if (_lastResult?.shouldShowStreak == true) {
                context.push(Routes.streak);
              } else {
                // Devam Eden sekmesine git (home'a git, tab index 1)
                context.go('${Routes.home}?tab=1');
              }
            },
          ),
        ],
      ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _ReviewStep extends StatefulWidget {
  const _ReviewStep({
    required this.onSave,
    required this.onReviewChanged,
    this.onNoteChanged,
    this.onImageSelected,
    this.imagePath,
    required this.onHoursChanged,
    required this.onRatingChanged,
    required this.initialMinutes,
    this.isDirectFinish = false,
    this.showTimeInput = true,
  });

  final Future<void> Function() onSave;
  final ValueChanged<String> onReviewChanged;
  final ValueChanged<String>? onNoteChanged;
  final ValueChanged<String?>? onImageSelected;
  final String? imagePath;
  final ValueChanged<String> onHoursChanged;
  final ValueChanged<int> onRatingChanged;
  final int initialMinutes;
  final bool isDirectFinish;
  final bool showTimeInput;

  @override
  State<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<_ReviewStep> {
  late final TextEditingController _reviewCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _minutesCtrl;
  bool _isLoading = false;
  int _selectedRating = 0;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _reviewCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _imagePath = widget.imagePath;
    
    final h = widget.initialMinutes ~/ 60;
    final m = widget.initialMinutes % 60;
    
    _hoursCtrl = TextEditingController(text: h > 0 ? h.toString() : '');
    _minutesCtrl = TextEditingController(text: m > 0 ? m.toString() : '');
    _reviewCtrl.addListener(() => widget.onReviewChanged(_reviewCtrl.text));
    _noteCtrl.addListener(() => widget.onNoteChanged?.call(_noteCtrl.text));
    // Combine hours and minutes for the callback
    void updateHoursCallback() {
      final hours = int.tryParse(_hoursCtrl.text) ?? 0;
      final minutes = int.tryParse(_minutesCtrl.text) ?? 0;
      final totalMinutes = (hours * 60) + minutes;
      widget.onHoursChanged(totalMinutes.toString());
    }
    _hoursCtrl.addListener(updateHoursCallback);
    _minutesCtrl.addListener(updateHoursCallback);

    // Timer'dan gelen süreyi otomatik bildir (süre alanı gizli ise)
    if (!widget.showTimeInput && widget.initialMinutes > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onHoursChanged(widget.initialMinutes.toString());
      });
    }
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    _noteCtrl.dispose();
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return;
    
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source);
      if (xfile != null && mounted) {
        // Cropping opsiyonel - kullanıcı iptal ederse veya hata olursa orijinal resmi kullan
        String? finalPath = xfile.path;
        try {
          final croppedPath = await ImageHelper.cropImage(
            context: context,
            sourcePath: xfile.path,
          );
          if (croppedPath != null) {
            finalPath = croppedPath;
          }
        } catch (e) {
          debugPrint('Crop error, using original: $e');
        }
        
        if (mounted) {
          setState(() {
            _imagePath = finalPath;
          });
          widget.onImageSelected?.call(finalPath);
        }
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    await widget.onSave();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Kitabı Bitirdin!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Son rutuşları yapalım...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            
            // Son Oturum Süresi Input (Sadece manuel bitirmede gösterilir)
            if (widget.showTimeInput) ...[
              Text(
                'SON OTURUM SÜRESİ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _hoursCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          suffixText: 'Saat',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _minutesCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          suffixText: 'Dakika',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Rating Input
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
                final isFilled = starIndex <= _selectedRating;
                return IconButton(
                  onPressed: () {
                     setState(() {
                       _selectedRating = starIndex;
                     });
                     widget.onRatingChanged(starIndex);
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

            // Review Input (Sadece manuel bitirmede göster)
            if (widget.isDirectFinish) ...[
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
            ],
            
            // Not Input (Sadece manuel bitirmede göster)
            if (widget.isDirectFinish) ...[
              Text(
                'NOT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toolbar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            _imagePath != null ? Icons.image : Icons.add_photo_alternate_outlined,
                            color: _imagePath != null ? Theme.of(context).colorScheme.primary : null,
                          ),
                          onPressed: _pickImage,
                          tooltip: 'Fotoğraf Ekle',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Text Field
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 5,
                      minLines: 3,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Notunuzu buraya yazın...',
                      ),
                    ),
                    // Image Preview
                    if (_imagePath != null) ...[
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 250,
                              ),
                              child: Image.file(
                                File(_imagePath!),
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                                        SizedBox(height: 4),
                                        Text('Görsel yüklenemedi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                padding: const EdgeInsets.all(6),
                                minimumSize: const Size(32, 32),
                              ),
                              onPressed: () {
                                setState(() {
                                  _imagePath = null;
                                });
                                widget.onImageSelected?.call(null);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Kaydet ve Bitir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _NoteStep extends StatelessWidget {
  const _NoteStep({
    required this.noteController,
    required this.titleController,
    required this.onAction,
    this.isDirectFinish = false,
    this.imagePath,
    this.onImageSelected,
  });

  final TextEditingController noteController;
  final TextEditingController titleController;
  final VoidCallback onAction;
  final bool isDirectFinish;
  final String? imagePath;
  final ValueChanged<String?>? onImageSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Oturum Özeti',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  
                   // Title Input
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                     decoration: BoxDecoration(
                       color: Theme.of(context).cardColor,
                       borderRadius: BorderRadius.circular(16),
                       boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                     ),
                     child: TextField(
                       controller: titleController,
                       style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                       decoration: const InputDecoration(
                         border: InputBorder.none,
                         hintText: 'Oturum Başlığı',
                         icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                       ),
                     ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Note Editor Area
                  Container(
                    height: 350, // Sabit ama makul bir yükseklik
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _NoteEditor(
                          controller: noteController,
                          imagePath: imagePath,
                          onImageSelected: onImageSelected,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Bottom Action Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAction,
              icon: Icon(isDirectFinish ? Icons.check : Icons.arrow_forward),
              label: Text(
                isDirectFinish ? 'Kaydet ve Bitir' : 'Devam Et',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.controller,
    this.imagePath,
    this.onImageSelected,
  });

  final TextEditingController controller;
  final String? imagePath;
  final ValueChanged<String?>? onImageSelected;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return;
    
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source);
      if (xfile != null && mounted) {
        // Cropping opsiyonel - kullanıcı iptal ederse veya hata olursa orijinal resmi kullan
        String? finalPath = xfile.path;
        try {
          final croppedPath = await ImageHelper.cropImage(
            context: context,
            sourcePath: xfile.path,
          );
          if (croppedPath != null) {
            finalPath = croppedPath;
          }
        } catch (e) {
          debugPrint('Crop error, using original: $e');
        }
        
        if (mounted) {
          widget.onImageSelected?.call(finalPath);
        }
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          // T4.15: the bold/italic toggles only restyled the whole input field
          // and never persisted (notes are plain text), so they're removed
          // rather than pretending to offer rich-text formatting.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ToolbarButton(
                icon: Icons.add_photo_alternate_outlined,
                isActive: widget.imagePath != null,
                onPressed: _pickImage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Scrollable Content: Image and Text
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (widget.imagePath != null) ...[
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: Image.file(
                          File(widget.imagePath!),
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () => widget.onImageSelected?.call(null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: widget.controller,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  hintText: 'Aklında kalan bir cümle, bir düşünce ya da bir his...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    fontSize: 16,
                    height: 1.8,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 20,
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
      ),
      style: IconButton.styleFrom(
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _CongratsStep extends StatelessWidget {
  const _CongratsStep({
    required this.totalPages,
    required this.onDone,
    this.result,
  });

  final int totalPages;
  final VoidCallback onDone;
  final FinishReadingResult? result;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.celebration_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Tebrikler!',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Kitabı başarıyla bitirdin!\nOkuma yolculuğuna yeni bir başarı daha ekledin.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'TAMAMLANAN  $totalPages Sayfa',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                child: const Text('Ana Ekrana Dön'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _PageStep extends ConsumerStatefulWidget {
  const _PageStep({
    required this.totalPages,
    required this.controller,
    required this.onSave,
    required this.bookId,
  });

  final int totalPages;
  final TextEditingController controller;
  final VoidCallback onSave;
  final String bookId;

  @override
  ConsumerState<_PageStep> createState() => _PageStepState();
}

class _PageStepState extends ConsumerState<_PageStep> {
  // T2.20: create the wheel controller once. It used to be rebuilt inline on
  // every rebuild, leaking controllers and snapping the wheel back mid-fling.
  late final FixedExtentScrollController _wheelController;

  @override
  void initState() {
    super.initState();
    _wheelController = FixedExtentScrollController(
      initialItem: (int.tryParse(widget.controller.text) ?? 0).clamp(0, widget.totalPages),
    );
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.totalPages;
    final controller = widget.controller;
    final onSave = widget.onSave;
    final bookId = widget.bookId;
    final state = ref.watch(finishReadingVmProvider(bookId));
    final isSaving = state.isSaving;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          final current = int.tryParse(value.text.trim()) ?? 0;
                          final progress = totalPages <= 0 ? 0.0 : (current / totalPages).clamp(0.0, 1.0);
                          
                          return Column(
                            children: [
                              Text(
                                'TOPLAM KİTAP SAYFASI',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$totalPages',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Kaçıncı Sayfadasın?',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: ListWheelScrollView.useDelegate(
                                  controller: _wheelController,
                                  itemExtent: 50,
                                  perspective: 0.005,
                                  diameterRatio: 1.5,
                                  physics: const FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: (index) {
                                    if (controller.text != index.toString()) {
                                      controller.text = index.toString();
                                    }
                                  },
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: totalPages + 1,
                                    builder: (context, index) {
                                      return Center(
                                        child: Text(
                                          '$index',
                                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: LinearProgressIndicator(
                                        value: progress.toDouble(),
                                        minHeight: 12,
                                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '%${(progress * 100).round()}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Harika gidiyorsun, devam et!',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
