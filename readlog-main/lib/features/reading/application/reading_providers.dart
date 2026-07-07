import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_logs_repository.dart';
import '../../../shared/services/local_storage_service.dart';
import '../domain/reading_log.dart';

final readingLogsRepositoryProvider = Provider<ReadingLogsRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider); 
  return LocalReadingLogsRepository(storageService);
});

class ReadingLogsNotifier extends StateNotifier<List<ReadingLog>> {
  ReadingLogsNotifier(this._repo) : super([]) {
    _loadLogs();
  }

  final ReadingLogsRepository _repo;

  Future<void> _loadLogs() async {
    // T4.13: a load failure keeps the last good state rather than throwing into
    // the provider (which would leave listeners with an unhandled error).
    try {
      state = await _repo.listAll();
    } catch (_) {
      // keep previous state
    }
  }

  Future<void> addLog(ReadingLog log) async {
    await _repo.add(log);
    await _loadLogs();
  }
  
  Future<void> deleteLog(String id) async {
    await _repo.delete(id);
    await _loadLogs();
  }

  Future<void> updateLog(ReadingLog log) async {
    await _repo.update(log);
    await _loadLogs(); 
  }
  
  Future<void> reload() async {
    await _loadLogs();
  }
}

final readingLogsProvider = StateNotifierProvider<ReadingLogsNotifier, List<ReadingLog>>((ref) {
  final repo = ref.watch(readingLogsRepositoryProvider);
  return ReadingLogsNotifier(repo);
});

/// Belirli bir okuma kaydını getiren provider
final readingLogProvider = FutureProvider.autoDispose.family<ReadingLog?, String>((ref, logId) async {
  final repo = ref.watch(readingLogsRepositoryProvider);
  return repo.getById(logId);
});