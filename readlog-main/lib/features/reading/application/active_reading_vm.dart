import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/audio_recording_service.dart';

enum ReadingMode { silent, voice }

enum ReadingStatus { idle, active, paused, recording }

class ActiveReadingState {
  final Duration elapsed;
  final ReadingMode mode;
  final ReadingStatus status;
  final Duration? recordingDuration;
  final String? recordingFilePath;

  const ActiveReadingState({
    this.elapsed = Duration.zero,
    this.mode = ReadingMode.silent,
    this.status = ReadingStatus.idle,
    this.recordingDuration,
    this.recordingFilePath,
  });

  ActiveReadingState copyWith({
    Duration? elapsed,
    ReadingMode? mode,
    ReadingStatus? status,
    Duration? recordingDuration,
    String? recordingFilePath,
    bool? clearRecordingDuration,
    bool? clearRecordingFilePath,
  }) {
    return ActiveReadingState(
      elapsed: elapsed ?? this.elapsed,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      recordingDuration: clearRecordingDuration == true
          ? null
          : (recordingDuration ?? this.recordingDuration),
      recordingFilePath: clearRecordingFilePath == true
          ? null
          : (recordingFilePath ?? this.recordingFilePath),
    );
  }
}

class ActiveReadingVm extends StateNotifier<ActiveReadingState> {
  ActiveReadingVm() : super(const ActiveReadingState()) {
    _audioService = AudioRecordingService();
  }

  late final AudioRecordingService _audioService;
  Timer? _timer;
  Timer? _recordingTimer;
  DateTime? _startTime;
  Duration _pausedElapsed = Duration.zero;
  String? _logId; // Kayıt için log ID

  @override
  void dispose() {
    _timer?.cancel();
    _recordingTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  /// Log ID'yi ayarla (ses kaydı için)
  void setLogId(String logId) {
    _logId = logId;
  }

  void startSilent() {
    if (state.status == ReadingStatus.active) return;
    _startTime = DateTime.now();
    _pausedElapsed = state.elapsed;
    state = state.copyWith(
      mode: ReadingMode.silent,
      status: ReadingStatus.active,
    );
    _startTimer();
  }

  Future<bool> startVoice() async {
    if (state.status == ReadingStatus.recording) return false;
    
    // Log ID yoksa oluştur
    if (_logId == null) {
      _logId = DateTime.now().microsecondsSinceEpoch.toString();
    }
    
    // Ses kaydını başlat
    final recordingStarted = await _audioService.startRecording(_logId!);
    if (!recordingStarted) {
      return false; // İzin reddedildi veya hata oluştu
    }
    
    _startTime = DateTime.now();
    _pausedElapsed = state.elapsed;
    state = state.copyWith(
      mode: ReadingMode.voice,
      status: ReadingStatus.recording,
      recordingDuration: Duration.zero,
      recordingFilePath: _audioService.currentRecordingPath,
    );
    _startTimer();
    _startRecordingTimer();
    return true;
  }

  Future<void> pause() async {
    if (state.status != ReadingStatus.active &&
        state.status != ReadingStatus.recording) {
      return;
    }
    _timer?.cancel();
    _recordingTimer?.cancel();
    if (_startTime != null) {
      _pausedElapsed += DateTime.now().difference(_startTime!);
      _startTime = null;
    }
    
    // Eğer kayıt yapılıyorsa, kaydı durdur
    if (state.status == ReadingStatus.recording && _audioService.isRecording) {
      await _audioService.stopRecording();
    }
    
    state = state.copyWith(status: ReadingStatus.paused);
  }

  Future<bool> resume() async {
    if (state.status != ReadingStatus.paused) return false;
    
    _startTime = DateTime.now();
    
    // Eğer sesli okuma modundaysa, kaydı tekrar başlat
    if (state.mode == ReadingMode.voice) {
      final recordingStarted = await _audioService.startRecording(_logId ?? DateTime.now().microsecondsSinceEpoch.toString());
      if (!recordingStarted) {
        return false; // İzin reddedildi
      }
      state = state.copyWith(
        status: ReadingStatus.recording,
        recordingFilePath: _audioService.currentRecordingPath,
      );
      _startRecordingTimer();
    } else {
      state = state.copyWith(status: ReadingStatus.active);
    }
    
    _startTimer();
    return true;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_startTime != null) {
      final now = DateTime.now();
      final newElapsed = _pausedElapsed + now.difference(_startTime!);
      state = state.copyWith(elapsed: newElapsed);
    }
  }

  /// Uygulama arkaplandan döndüğünde süreyi hemen güncellemek için
  void syncTime() {
    _tick();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    Duration recElapsed = state.recordingDuration ?? Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      recElapsed = recElapsed + const Duration(seconds: 1);
      if (mounted) {
        state = state.copyWith(recordingDuration: recElapsed);
      }
    });
  }

  void reset() async {
    _timer?.cancel();
    _recordingTimer?.cancel();
    _startTime = null;
    _pausedElapsed = Duration.zero;
    
    // Eğer kayıt yapılıyorsa, kaydı iptal et
    if (_audioService.isRecording) {
      await _audioService.cancelRecording();
    }
    
    state = const ActiveReadingState();
    _logId = null;
  }

  /// Ses kaydını durdur ve dosya yolunu döndür
  Future<String?> stopRecording() async {
    // Durdur ve state'i güncelle
    await pause();
    return state.recordingFilePath;
  }

  Duration get totalMinutes => state.elapsed;
  String? get recordingFilePath => state.recordingFilePath;
}

