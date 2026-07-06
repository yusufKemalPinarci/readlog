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
  ActiveReadingVm({AudioRecordingService? audioService, DateTime Function()? clock})
      : _audioService = audioService ?? AudioRecordingService(),
        _now = clock ?? DateTime.now,
        super(const ActiveReadingState());

  final AudioRecordingService _audioService;
  final DateTime Function() _now;
  Timer? _timer;
  Timer? _recordingTimer;
  DateTime? _startTime;
  Duration _pausedElapsed = Duration.zero;
  // T2.12: recording duration is derived from wall-clock timestamps (like
  // `elapsed`) rather than counting timer ticks, so it stays accurate across
  // pauses and when the app is backgrounded and later re-synced.
  DateTime? _recordingStartTime;
  Duration _recordingPausedElapsed = Duration.zero;
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
    _startTime = _now();
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
    _logId ??= _now().microsecondsSinceEpoch.toString();
    
    // Ses kaydını başlat
    final recordingStarted = await _audioService.startRecording(_logId!);
    if (!recordingStarted) {
      return false; // İzin reddedildi veya hata oluştu
    }
    
    _startTime = _now();
    _pausedElapsed = state.elapsed;
    _recordingStartTime = _now();
    _recordingPausedElapsed = Duration.zero;
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
    final now = _now();
    if (_startTime != null) {
      _pausedElapsed += now.difference(_startTime!);
      _startTime = null;
    }
    if (_recordingStartTime != null) {
      _recordingPausedElapsed += now.difference(_recordingStartTime!);
      _recordingStartTime = null;
    }

    // T2.1: pause the recording natively (keep the file open) instead of
    // stopping it, so resume() appends to the same recording.
    if (state.status == ReadingStatus.recording && _audioService.isRecording) {
      await _audioService.pauseRecording();
    }

    state = state.copyWith(status: ReadingStatus.paused, elapsed: _pausedElapsed);
  }

  Future<bool> resume() async {
    if (state.status != ReadingStatus.paused) return false;
    
    _startTime = _now();

    // T2.1: resume the SAME recording (native resume) rather than starting a new
    // file — the recordingFilePath stays constant so no segment is discarded.
    if (state.mode == ReadingMode.voice) {
      await _audioService.resumeRecording();
      _recordingStartTime = _now();
      state = state.copyWith(status: ReadingStatus.recording);
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
      final now = _now();
      final newElapsed = _pausedElapsed + now.difference(_startTime!);
      state = state.copyWith(elapsed: newElapsed);
    }
  }

  /// Uygulama arkaplandan döndüğünde süreleri hemen senkronize et (T2.12).
  void syncTime() {
    _tick();
    _recordingTick();
  }

  void _recordingTick() {
    if (_recordingStartTime != null && mounted) {
      final now = _now();
      state = state.copyWith(
        recordingDuration: _recordingPausedElapsed + now.difference(_recordingStartTime!),
      );
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) => _recordingTick());
  }

  Future<void> reset() async {
    _timer?.cancel();
    _recordingTimer?.cancel();
    _startTime = null;
    _pausedElapsed = Duration.zero;
    _recordingStartTime = null;
    _recordingPausedElapsed = Duration.zero;

    // Eğer kayıt yapılıyorsa, kaydı iptal et
    if (_audioService.isRecording) {
      await _audioService.cancelRecording();
    }

    state = const ActiveReadingState();
    _logId = null;
  }

  /// Ses kaydını sonlandır (dosyayı kapatır) ve dosya yolunu döndür.
  /// Duraklatılmış ya da aktif kayıttan çağrılabilir; her iki durumda da
  /// kaydı kalıcı olarak sonlandırır (T2.1).
  Future<String?> stopRecording() async {
    _timer?.cancel();
    _recordingTimer?.cancel();
    final now = _now();
    if (_startTime != null) {
      _pausedElapsed += now.difference(_startTime!);
      _startTime = null;
    }
    if (_recordingStartTime != null) {
      _recordingPausedElapsed += now.difference(_recordingStartTime!);
      _recordingStartTime = null;
    }

    String? path = state.recordingFilePath;
    if (_audioService.isRecording) {
      final finalized = await _audioService.stopRecording();
      path = finalized ?? path;
    }
    state = state.copyWith(
      status: ReadingStatus.paused,
      elapsed: _pausedElapsed,
      recordingDuration: _recordingPausedElapsed,
    );
    return path;
  }

  Duration get totalMinutes => state.elapsed;
  String? get recordingFilePath => state.recordingFilePath;
}

