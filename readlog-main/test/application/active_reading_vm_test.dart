import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/reading/application/active_reading_vm.dart';
import 'package:libris/shared/services/audio_recording_service.dart';

/// Records the calls made to it so we can assert pause/resume never becomes
/// stop/start (T2.1). Never constructs a real AudioRecorder.
class _FakeRecorder implements AudioRecorderPort {
  final List<String> calls = [];
  bool _rec = false;
  String? _path;

  @override
  bool get isRecording => _rec;
  @override
  String? get currentRecordingPath => _path;

  @override
  Future<bool> startRecording(String logId) async {
    calls.add('start');
    _rec = true;
    _path = '/rec/$logId.m4a';
    return true;
  }

  @override
  Future<void> pauseRecording() async => calls.add('pause');
  @override
  Future<void> resumeRecording() async => calls.add('resume');
  @override
  Future<String?> stopRecording() async {
    calls.add('stop');
    _rec = false;
    return _path;
  }

  @override
  Future<void> cancelRecording() async {
    calls.add('cancel');
    _rec = false;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('silent: elapsed accumulates across pause/resume by wall clock (T5.2)', () async {
    var t = DateTime(2026, 1, 1, 10, 0, 0);
    final vm = ActiveReadingVm(clock: () => t);
    addTearDown(vm.dispose);

    vm.startSilent();
    t = t.add(const Duration(seconds: 40));
    vm.syncTime();
    expect(vm.state.elapsed, const Duration(seconds: 40));

    await vm.pause();
    t = t.add(const Duration(minutes: 5)); // paused time must NOT count
    await vm.resume();
    t = t.add(const Duration(seconds: 20));
    vm.syncTime();
    expect(vm.state.elapsed, const Duration(seconds: 60)); // 40 + 20
  });

  test('voice: pause/resume keeps ONE recording file (T2.1)', () async {
    final t = DateTime(2026, 1, 1, 10);
    final rec = _FakeRecorder();
    final vm = ActiveReadingVm(audioService: rec, clock: () => t);
    addTearDown(vm.dispose);

    expect(await vm.startVoice(), isTrue);
    final path1 = vm.state.recordingFilePath;

    await vm.pause();
    await vm.resume();
    expect(vm.state.recordingFilePath, path1, reason: 'file path stays constant');

    final finalPath = await vm.stopRecording();
    expect(finalPath, path1);
    // The key regression: pause/resume, not stop + new start.
    expect(rec.calls, ['start', 'pause', 'resume', 'stop']);
  });

  test('voice: recordingDuration excludes paused time (T2.12)', () async {
    var t = DateTime(2026, 1, 1, 10);
    final vm = ActiveReadingVm(audioService: _FakeRecorder(), clock: () => t);
    addTearDown(vm.dispose);

    await vm.startVoice();
    t = t.add(const Duration(seconds: 30));
    vm.syncTime();
    expect(vm.state.recordingDuration, const Duration(seconds: 30));

    await vm.pause();
    t = t.add(const Duration(minutes: 2)); // paused
    await vm.resume();
    t = t.add(const Duration(seconds: 15));
    vm.syncTime();
    expect(vm.state.recordingDuration, const Duration(seconds: 45)); // 30 + 15
  });
}
