import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../books/application/books_vm.dart';
import '../../books/domain/book.dart';
import '../application/reading_providers.dart';
import '../domain/reading_log.dart';

class ReadingLogDetailScreen extends ConsumerWidget {
  const ReadingLogDetailScreen({
    super.key,
    required this.logId,
  });

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(readingLogProvider(logId));
    final booksVm = ref.watch(booksVmProvider.notifier);
    
    return logAsync.when(
      data: (log) {
        if (log == null) {
          return BookScaffold(
            appBar: AppBar(title: const Text('Kayıt Bulunamadı')),
            body: const Center(child: Text('Okuma kaydı bulunamadı.')),
          );
        }
        
        final book = booksVm.byId(log.bookId);
        if (book == null) {
          return BookScaffold(
            appBar: AppBar(title: const Text('Kitap Bulunamadı')),
            body: const Center(child: Text('Kitap bulunamadı.')),
          );
        }
        
        return _buildContent(context, ref, log, book, logId);
      },
      loading: () => BookScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Okuma Kaydı Detayı'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => BookScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Okuma Kaydı Detayı'),
        ),
        body: Center(child: Text('Hata: $err')),
      ),
    );
  }
}

Widget _buildContent(BuildContext context, WidgetRef ref, ReadingLog log, Book book, String logId) {
  return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Okuma Kaydı Detayı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final shouldRefresh = await context.push<bool>(Routes.editReadingLog(logId));
              if (shouldRefresh == true) {
                ref.invalidate(readingLogProvider(logId));
                ref.read(readingLogsProvider.notifier).reload();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _handleDelete(context, ref, logId),
          ),
        ],
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
              value: _formatDate(log.date),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.access_time,
              iconColor: Theme.of(context).colorScheme.primary,
              label: 'SÜRE',
              value: _formatDuration(log.minutes),
            ),
            const SizedBox(height: 24),
            if (log.audioFilePath != null) ...[
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
              const SizedBox(height: 24),
            ],
            const Text(
              'NOTLAR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.noteFilePath != null && log.noteFilePath!.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          try {
                            if (File(log.noteFilePath!).existsSync()) {
                              return GestureDetector(
                                onTap: () {
                                  // Tam ekranda resmi göster
                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.black87,
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
                                                File(log.noteFilePath!),
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
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 300,
                                        ),
                                        child: Image.file(
                                          File(log.noteFilePath!),
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
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.zoom_in,
                                        color: Colors.white.withValues(alpha: 0.7),
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            // Dosya erişim hatası
                          }
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
                                Text('Görsel bulunamadı', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
                      if (log.note != null && log.note!.isNotEmpty)
                        const SizedBox(height: 16),
                    ],
                    if (log.note != null && log.note!.isNotEmpty)
                      Text(
                        log.note!,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      )
                    else if (log.noteFilePath == null || log.noteFilePath!.isEmpty)
                      Text(
                        'Not eklenmemiş.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

String _formatDate(DateTime date) {
  try {
    return DateFormat('d MMM yyyy, EEEE', 'tr_TR').format(date);
  } catch (e) {
    return DateFormat('d MMM yyyy, EEEE').format(date);
  }
}

String _formatDuration(int minutes) {
  if (minutes < 1) {
    // 1 dakikadan küçükse saniye göster
    final seconds = (minutes * 60).round();
    return '$seconds sn';
  } else if (minutes < 60) {
    // 1 saatten küçükse sadece dakika göster
    return '$minutes dk';
  } else {
    // 60 dakikadan büyükse saat ve dakika göster
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '$hours sa';
    } else {
      return '$hours sa $mins dk';
    }
  }
}

Future<void> _handleDelete(BuildContext context, WidgetRef ref, String logId) async {
  final ok = await showConfirmDialog(
    context: context,
    title: 'Okuma Kaydını Sil?',
    message: 'Bu okuma kaydını silmek istediğinize emin misiniz?\nBu işlem geri alınamaz.',
  );
  if (ok && context.mounted) {
    await ref.read(readingLogsRepositoryProvider).delete(logId);

    // T2.4: refresh the per-log detail provider and the list notifier; do NOT
    // invalidate the singleton repository.
    ref.invalidate(readingLogProvider(logId));
    await ref.read(readingLogsProvider.notifier).reload();

    if (context.mounted) {
      context.pop();
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
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
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          
          // Bittiğinde dur
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
      if (_currentPosition >= _totalDuration && _totalDuration > Duration.zero) {
        // Bitti ise başa sar ve oynat
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _currentPosition = Duration.zero;
          });
        }
      } else if (_isPlaying) {
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

  Future<void> _skipBackward() async {
    final newPosition = _currentPosition - const Duration(seconds: 5);
    final targetPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
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

    final isCompleted = _currentPosition >= _totalDuration && _totalDuration > Duration.zero;
    final showReplay = isCompleted && !_isPlaying;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress bar (Slider)
            Slider(
              value: currentProgress.clamp(0.0, 1.0),
              onChanged: _onSliderChanged,
              onChangeEnd: _onSliderChangeEnd,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Colors.grey[300],
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
                // Geri 5 saniye
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.replay_5_rounded),
                    iconSize: 28,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _skipBackward,
                    tooltip: 'Geri 5 saniye',
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 24),
                // Play/Pause/Replay
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(showReplay ? Icons.replay_rounded : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
                    iconSize: 40,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _togglePlayPause,
                    tooltip: showReplay ? 'Tekrar Oynat' : (_isPlaying ? 'Durdur' : 'Oynat'),
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

