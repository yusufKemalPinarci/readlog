import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../shared/utils/duration_format.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../application/reading_providers.dart';
import '../domain/reading_log.dart';

final _editReadingLogProvider = FutureProvider.autoDispose.family<ReadingLog?, String>((ref, logId) async {
  final repo = ref.watch(readingLogsRepositoryProvider);
  return repo.getById(logId);
});

class EditReadingLogScreen extends ConsumerStatefulWidget {
  const EditReadingLogScreen({
    super.key,
    required this.logId,
  });

  final String logId;

  @override
  ConsumerState<EditReadingLogScreen> createState() => _EditReadingLogScreenState();
}

class _EditReadingLogScreenState extends ConsumerState<EditReadingLogScreen> {
  late final TextEditingController _dateCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _minutesPartCtrl;
  late final TextEditingController _secondsPartCtrl;
  late final TextEditingController _noteCtrl;
  DateTime? _selectedDate;
  int? _minutes;
  int? _durationSeconds;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController();
    _hoursCtrl = TextEditingController();
    _minutesPartCtrl = TextEditingController();
    _secondsPartCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    // Async olarak log'u yükle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final log = await ref.read(readingLogsRepositoryProvider).getById(widget.logId);
      if (log != null && mounted) {
        final totalSec = log.effectiveDurationSeconds;
        setState(() {
          _selectedDate = log.date;
          _minutes = log.minutes;
          _durationSeconds = totalSec;
          _dateCtrl.text = DateFormat('dd/MM/yyyy').format(log.date);
          _hoursCtrl.text = (totalSec ~/ 3600).toString();
          _minutesPartCtrl.text = ((totalSec % 3600) ~/ 60).toString();
          _secondsPartCtrl.text = (totalSec % 60).toString();
          _noteCtrl.text = log.note ?? '';
          _imagePath = log.noteFilePath;
        });
      }
    });
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _hoursCtrl.dispose();
    _minutesPartCtrl.dispose();
    _secondsPartCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _updateDuration() {
    final h = int.tryParse(_hoursCtrl.text) ?? 0;
    final m = int.tryParse(_minutesPartCtrl.text) ?? 0;
    final s = int.tryParse(_secondsPartCtrl.text) ?? 0;
    setState(() {
      _durationSeconds = h * 3600 + m * 60 + s;
      _minutes = _durationSeconds! ~/ 60;
    });
  }

  String _formatEditDuration(int totalSeconds) => formatSecondsHuman(totalSeconds); // T4.3

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
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
    
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source);
    if (xfile != null) {
      setState(() {
        _imagePath = xfile.path;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  Future<void> _save() async {
    if (_selectedDate == null || _minutes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    final logsRepo = ref.read(readingLogsRepositoryProvider);
    final existing = await logsRepo.getById(widget.logId);
    if (existing == null) return;

    // Resim kalıcılığı
    String? persistentImagePath = _imagePath;
    if (_imagePath != null && _imagePath != existing.noteFilePath) {
      // Yeni resim seçilmiş
      try {
        final file = File(_imagePath!);
        if (await file.exists()) {
           // Sadece resim değiştiyse kopyala.
           // Eğer persistent'a zaten kaydedilmişse (eski resim ise) kopyalamaya gerek yok ama
           // path temp ise kopyalamalıyız.
           // Basit kontrol: path cache dizininde mi? Veya sadece her zaman kopyala.
           // Güvenli olması için: AppDocumentsDir içinde değilse kopyala.
           
           final appDir = await getApplicationDocumentsDirectory();
           final isAlreadyInAppDir = p.isWithin(appDir.path, _imagePath!);
           
           if (!isAlreadyInAppDir) {
              final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(_imagePath!)}';
              final savedImage = await file.copy('${appDir.path}/$fileName');
              persistentImagePath = savedImage.path;
           }
        }
      } catch (e) {
        debugPrint('Resim kaydedilirken hata: $e');
      }
    }

    // T2.2: build from `existing` so no field (notably `title`) is silently
    // dropped; only the edited fields are overridden.
    final updated = existing.copyWith(
      date: _selectedDate!,
      minutes: _minutes!,
      durationSeconds: _durationSeconds,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      noteFilePath: persistentImagePath,
    );

    await logsRepo.update(updated);
    if (!mounted) return;
    context.pop(true);
  }

  Future<void> _deleteRecording(ReadingLog log) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Kaydı Sil?',
      message: 'Bu ses kaydını silmek istediğinize emin misiniz?',
    );
    if (ok && mounted) {
      final logsRepo = ref.read(readingLogsRepositoryProvider);
      
      // Ses kaydı dosyasını sil
      if (log.audioFilePath != null) {
        try {
          final file = File(log.audioFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Ses kaydı dosyası silinirken hata: $e');
        }
      }
      
      // Okuma kaydından ses kaydı yolunu kaldır
      final updated = log.copyWith(
        audioFilePath: null, // Ses kaydı yolunu null yap
      );
      
      await logsRepo.update(updated);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ses kaydı silindi.')),
        );
        // Sayfayı yenile
        ref.invalidate(_editReadingLogProvider(widget.logId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(_editReadingLogProvider(widget.logId));
    
    return logAsync.when(
      data: (log) {
        if (log == null) {
          return BookScaffold(
            appBar: AppBar(title: const Text('Kayıt Bulunamadı')),
            body: const Center(child: Text('Okuma kaydı bulunamadı.')),
          );
        }
        return _buildContent(context, ref, log);
      },
      loading: () => BookScaffold(
        appBar: AppBar(title: const Text('Düzenle')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => BookScaffold(
        appBar: AppBar(title: const Text('Düzenle')),
        body: Center(child: Text('Hata: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ReadingLog log) {
    return BookScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Okuma Kaydı Düzenle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(
              icon: Icons.calendar_today,
              iconColor: Theme.of(context).colorScheme.primary,
              label: 'TARİH',
              value: _dateCtrl.text,
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.access_time,
              iconColor: const Color(0xFFFF9800),
              label: 'SÜRE',
              value: _durationSeconds != null ? _formatEditDuration(_durationSeconds!) : '0 sn',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hoursCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly], // T4.6
                      decoration: const InputDecoration(
                        hintText: 'Saat',
                        suffixText: 'sa',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => _updateDuration(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutesPartCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly], // T4.6
                      decoration: const InputDecoration(
                        hintText: 'Dakika',
                        suffixText: 'dk',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => _updateDuration(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _secondsPartCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly], // T4.6
                      decoration: const InputDecoration(
                        hintText: 'Saniye',
                        suffixText: 'sn',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => _updateDuration(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (log.audioFilePath != null) ...[
              Builder(
                builder: (context) {
                  try {
                    if (File(log.audioFilePath!).existsSync()) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SES KAYDI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _AudioPlayer(
                            audioFilePath: log.audioFilePath!,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteRecording(log),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text('Kaydı Sil', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  } catch (e) {
                    // Dosya erişim hatası
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            if (_imagePath != null) ...[
              Builder(
                builder: (context) {
                  try {
                    if (File(_imagePath!).existsSync()) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.black,
                                      insetPadding: EdgeInsets.zero,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          InteractiveViewer(
                                            minScale: 0.5,
                                            maxScale: 4.0,
                                            child: Center(
                                              child: Image.file(
                                                File(_imagePath!),
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 40,
                                            right: 16,
                                            child: IconButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                              style: IconButton.styleFrom(
                                                backgroundColor: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 300,
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
                                            borderRadius: BorderRadius.circular(16),
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
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Resmi Sil?'),
                                        content: const Text('Bu resmi silmek istediğinize emin misiniz?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('İptal'),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _removeImage();
                                            },
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Sil'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    padding: const EdgeInsets.all(6),
                                    minimumSize: const Size(32, 32),
                                  ),
                                  tooltip: 'Resmi Sil',
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  } catch (e) {
                    // Dosya erişim hatası
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            const SizedBox(height: 16),
            if (_imagePath == null)
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Fotoğraf Ekle'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _noteCtrl,
                  maxLines: null,
                  minLines: 6,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Notlarınızı buraya yazın...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Değişiklikleri Kaydet'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.child,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    child ?? Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPlayer extends StatefulWidget {
  const _AudioPlayer({required this.audioFilePath});

  final String audioFilePath;

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isDragging = false;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      final file = File(widget.audioFilePath);
      if (!await file.exists()) {
        debugPrint('Ses dosyası bulunamadı: ${widget.audioFilePath}');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // setFilePath kullan
      await _audioPlayer.setFilePath(widget.audioFilePath);
      
      // Duration'ı bekle - bazen hemen yüklenmez
      _totalDuration = _audioPlayer.duration ?? Duration.zero;
      if (_totalDuration == Duration.zero) {
        // Duration henüz yüklenmediyse bekle
        await Future.delayed(const Duration(milliseconds: 200));
        _totalDuration = _audioPlayer.duration ?? Duration.zero;
      }
      
      debugPrint('Ses dosyası yüklendi: ${widget.audioFilePath}, Süre: $_totalDuration');
      
      _audioPlayer.positionStream.listen((position) {
        if (mounted && !_isDragging) {
          setState(() {
            _currentPosition = position;
          });
        }
      });
      
      _audioPlayer.playerStateStream.listen((state) async {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
          
          // T2.16: on completion, stop and reset to the start (align with the
          // detail screen). The old inverted condition auto-replayed the clip.
          if (state.processingState == ProcessingState.completed && state.playing) {
            await _audioPlayer.pause();
            await _audioPlayer.seek(Duration.zero);
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _currentPosition = Duration.zero;
              });
            }
          }
        }
      });
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ses dosyası yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } else {
        await _audioPlayer.play();
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Play/Pause hatası: $e');
    }
  }

  Future<void> _seekToPosition(Duration position) async {
    await _audioPlayer.seek(position);
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _skipForward() async {
    final newPosition = _currentPosition + const Duration(seconds: 10);
    final targetPosition = newPosition > _totalDuration ? _totalDuration : newPosition;
    await _seekToPosition(targetPosition);
  }

  void _onSliderChanged(double value) {
    setState(() {
      _dragValue = value;
      _isDragging = true;
    });
  }

  void _onSliderChangeEnd(double value) {
    final newPosition = Duration(
      seconds: (value * _totalDuration.inSeconds).round(),
    );
    _seekToPosition(newPosition);
    setState(() {
      _isDragging = false;
      _dragValue = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    if (!File(widget.audioFilePath).existsSync()) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Ses kaydı bulunamadı.')),
        ),
      );
    }

    final currentProgress = _isDragging && _dragValue != null
        ? _dragValue!
        : (_totalDuration.inSeconds > 0
            ? _currentPosition.inSeconds / _totalDuration.inSeconds
            : 0.0);

    final displayPosition = _isDragging && _dragValue != null
        ? Duration(seconds: (_dragValue! * _totalDuration.inSeconds).round())
        : _currentPosition;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Progress bar (Slider)
            Slider(
              value: currentProgress.clamp(0.0, 1.0),
              onChanged: _onSliderChanged,
              onChangeEnd: _onSliderChangeEnd,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
            // Süre bilgisi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(displayPosition),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  _formatDuration(_totalDuration),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Kontrol butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play/Pause
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    iconSize: 40,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _togglePlayPause,
                    tooltip: _isPlaying ? 'Durdur' : 'Oynat',
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(width: 24),
                // İleri 10 saniye
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.forward_10_rounded),
                    iconSize: 28,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _skipForward,
                    tooltip: 'İleri 10 saniye',
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

