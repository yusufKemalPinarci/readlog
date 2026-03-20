import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../application/active_reading_vm.dart';

final activeReadingVmProvider =
    StateNotifierProvider.autoDispose<ActiveReadingVm, ActiveReadingState>(
  (ref) => ActiveReadingVm(),
);

class ActiveReadingScreen extends ConsumerStatefulWidget {
  const ActiveReadingScreen({
    super.key,
    required this.bookId,
  });

  final String bookId;

  @override
  ConsumerState<ActiveReadingScreen> createState() => _ActiveReadingScreenState();
}

class _ActiveReadingScreenState extends ConsumerState<ActiveReadingScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama öne geldiğinde sayacı senkronize et
      ref.read(activeReadingVmProvider.notifier).syncTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeReadingVmProvider);
    final vm = ref.read(activeReadingVmProvider.notifier);
    final isActive = state.status != ReadingStatus.idle;

    return PopScope(
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (isActive) {
          final shouldStop = await showConfirmDialog(
            context: context,
            title: 'Okumayı Sonlandır?',
            message: 'Okuma oturumunu sonlandırıp çıkmak istediğinize emin misiniz? Süre kaydedilmeyecek.',
            confirmText: 'Çık',
            cancelText: 'Devam Et',
            isDangerous: true,
          );

          if (shouldStop && context.mounted) {
             vm.pause();
             context.pop();
          }
        }
      },
      child: BookScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (!isActive) {
                context.pop();
                return;
              }
              final shouldStop = await showConfirmDialog(
                context: context,
                title: 'Okumayı Sonlandır?',
                message: 'Okuma oturumunu sonlandırıp çıkmak istediğinize emin misiniz? Süre kaydedilmeyecek.',
                confirmText: 'Çık',
                cancelText: 'Devam Et',
                isDangerous: true,
              );
              if (shouldStop && context.mounted) {
                 context.pop();
              }
            },
          ),
          title: const Text('Aktif Okuma'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _TimerDisplay(
                elapsed: state.elapsed,
                status: state.status,
                mode: state.mode,
                recordingDuration: state.recordingDuration,
              ),
              const SizedBox(height: 32),
              _StatusIndicator(
                status: state.status,
                mode: state.mode,
              ),
              const Spacer(flex: 3),
              _QuoteText(mode: state.mode),
              const Spacer(flex: 2),
              _ActionButtons(
                state: state,
                onStartSilent: vm.startSilent,
                onStartVoice: () async {
                  final started = await vm.startVoice();
                  if (!started && context.mounted) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ses kaydı başlatılamadı. Lütfen mikrofon iznini kontrol edin.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                onPause: vm.pause,
                onResume: () async {
                  final resumed = await vm.resume();
                  if (!resumed && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ses kaydı devam ettirilemedi. Lütfen mikrofon iznini kontrol edin.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                onFinish: () async {
                  final durationSeconds = vm.totalMinutes.inSeconds;
                  final recordingPath = await vm.stopRecording();
                  if (context.mounted) {
                    context.push(
                      Routes.finishReadingFor(widget.bookId),
                      extra: {
                        'minutes': durationSeconds ~/ 60,
                        'durationSeconds': durationSeconds,
                        'recordingPath': recordingPath,
                        'isDirectFinish': false,
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({
    required this.elapsed,
    required this.status,
    required this.mode,
    this.recordingDuration,
  });

  final Duration elapsed;
  final ReadingStatus status;
  final ReadingMode mode;
  final Duration? recordingDuration;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final displayDuration = status == ReadingStatus.recording && recordingDuration != null
        ? recordingDuration!
        : elapsed;

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(displayDuration),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'OKUMA SÜRESİ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.status,
    required this.mode,
  });

  final ReadingStatus status;
  final ReadingMode mode;

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    IconData? icon;

    switch (status) {
      case ReadingStatus.idle:
        return const SizedBox.shrink();
      case ReadingStatus.active:
        text = 'Sessiz Okuma Başladı';
        color = Theme.of(context).colorScheme.primary;
        icon = Icons.book_outlined;
        break;
      case ReadingStatus.recording:
        text = 'Kayıt Yapılıyor...';
        color = Colors.red;
        icon = Icons.graphic_eq;
        break;
      case ReadingStatus.paused:
        text = 'Durduruldu';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteText extends StatelessWidget {
  const _QuoteText({required this.mode});

  final ReadingMode mode;

  @override
  Widget build(BuildContext context) {
    final quote = mode == ReadingMode.voice
        ? 'Bir kitap okumak, başka birinin zihninde seyahat etmektir.'
        : 'Sessizlik, ruhun düşünmek için ihtiyaç duyduğu alandır.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        '"$quote"',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.state,
    required this.onStartSilent,
    required this.onStartVoice,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final ActiveReadingState state;
  final VoidCallback onStartSilent;
  final VoidCallback onStartVoice;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final isIdle = state.status == ReadingStatus.idle;
    final isPaused = state.status == ReadingStatus.paused;

    if (isIdle) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStartVoice,
              icon: const Icon(Icons.mic),
              label: const Text('Sesli Okuma'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onStartSilent,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('Sessiz Okuma'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isPaused) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Devam Ettir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.stop),
              label: const Text('Okumayı Bitir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // isActive (active veya recording durumunda)
    // isActive (active veya recording durumunda)
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onPause();
            },
            icon: const Icon(Icons.pause),
            label: Text(
              state.mode == ReadingMode.voice
                  ? 'Ses Kaydını Durdur'
                  : 'Durdur',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onFinish();
            },
            icon: const Icon(Icons.stop),
            label: const Text('Okumayı Bitir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

