import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  /// Mikrofon iznini kontrol et ve iste
  Future<bool> requestMicrophonePermission() async {
    // Önce record paketinin kendi izin kontrolünü kullan
    if (await _recorder.hasPermission()) {
      return true;
    }
    
    // Eğer record paketi izin vermiyorsa, permission_handler ile kontrol et ve iste
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      // permission_handler'a göre izin var ama record paketi izin vermiyor
      // Bu durumda record paketinin kontrolünü tekrar yap
      // Bazen izin verildikten sonra record paketinin güncellenmesi gerekebilir
      return await _recorder.hasPermission();
    }
    
    if (status.isDenied) {
      // İzin henüz istenmemiş, iste
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        // İzin verildi, record paketinin kontrolünü yap
        return await _recorder.hasPermission();
      }
      return false;
    }
    
    if (status.isPermanentlyDenied) {
      // İzin kalıcı olarak reddedilmiş, ayarlara yönlendir
      return false;
    }
    
    // Diğer durumlar (limited, restricted vb.)
    return false;
  }

  /// Depolama iznini kontrol et ve iste
  /// NOT: getApplicationDocumentsDirectory() kullandığımız için Android 13+ için depolama izni GEREKMEZ
  /// Bu metod artık kullanılmıyor, sadece geriye dönük uyumluluk için bırakıldı
  @Deprecated('getApplicationDocumentsDirectory() kullandığımız için depolama izni gerekmez')
  Future<bool> requestStoragePermission() async {
    // getApplicationDocumentsDirectory() uygulama özel dizinini kullanır
    // Bu yüzden Android 13+ için depolama izni gerekmez
    return true;
  }

  /// Ses kaydını başlat
  Future<bool> startRecording(String logId) async {
    if (_isRecording) {
      return false;
    }

    // NOT: Depolama izni kontrolü kaldırıldı
    // getApplicationDocumentsDirectory() kullandığımız için Android 13+ için depolama izni gerekmez
    // Uygulama özel dizinini kullandığımız için herhangi bir izin gerekmez

    try {
      // Uygulama dizinini al
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Dosya adını oluştur
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recording_${logId}_$timestamp.m4a';
      _currentRecordingPath = '${recordingsDir.path}/$fileName';

      // Önce izin kontrolü yap
      if (!await _recorder.hasPermission()) {
        // İzin yok, permission_handler ile kontrol et ve iste
        final micPermission = await requestMicrophonePermission();
        if (!micPermission) {
          return false;
        }
      }

      // Kaydı başlat - record paketi kendi izin kontrolünü de yapar
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      return true;
    } catch (e) {
      // Hata oluştu, kayıt başlatılamadı
      // İzin hatası olabilir veya başka bir sorun
      _currentRecordingPath = null;
      _isRecording = false;
      return false;
    }
  }

  /// Kaydı geçici olarak duraklat (dosyayı kapatmadan). T2.1: böylece devam
  /// ettirildiğinde aynı dosyaya yazılır ve segmentler kaybolmaz.
  Future<void> pauseRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.pause();
    } catch (_) {
      // Duraklatma başarısız olursa kayıt durumunu bozma
    }
  }

  /// Duraklatılmış kaydı aynı dosyaya devam ettir (T2.1).
  Future<void> resumeRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.resume();
    } catch (_) {}
  }

  /// Ses kaydını durdur
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      final savedPath = _currentRecordingPath;
      _currentRecordingPath = null;
      return savedPath ?? path;
    } catch (e) {
      _isRecording = false;
      _currentRecordingPath = null;
      return null;
    }
  }

  /// Kaydı iptal et (dosyayı sil)
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
    
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Dosya silme hatası görmezden gel
      }
      _currentRecordingPath = null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}

