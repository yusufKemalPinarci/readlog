import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/application/books_vm.dart';
import '../domain/reading_log.dart';
import 'reading_providers.dart';

@immutable
class FinishReadingState {
  final int minutes;
  final int? durationSeconds;
  final int? pageAtEnd;
  final String? note;
  final String? audioFilePath;
  final String? noteFilePath;
  final String? title;
  final bool isSaving;
  final String? error;
  final String? bookReview;
  final String? finalTotalHours;
  final int? rating; // 1-5 stars

  const FinishReadingState({
    this.minutes = 0,
    this.durationSeconds,
    this.pageAtEnd,
    this.note,
    this.audioFilePath,
    this.noteFilePath,
    this.title,
    this.isSaving = false,
    this.error,
    this.bookReview,
    this.finalTotalHours,
    this.rating,
  });

  FinishReadingState copyWith({
    int? minutes,
    int? durationSeconds,
    int? pageAtEnd,
    String? note,
    String? audioFilePath,
    String? noteFilePath,
    String? title,
    bool? isSaving,
    String? error,
    String? bookReview,
    String? finalTotalHours,
    int? rating,
  }) {
    return FinishReadingState(
      minutes: minutes ?? this.minutes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pageAtEnd: pageAtEnd ?? this.pageAtEnd,
      note: note ?? this.note,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      noteFilePath: noteFilePath ?? this.noteFilePath,
      title: title ?? this.title,
      isSaving: isSaving ?? this.isSaving,
      error: error ?? this.error,
      bookReview: bookReview ?? this.bookReview,
      finalTotalHours: finalTotalHours ?? this.finalTotalHours,
      rating: rating ?? this.rating,
    );
  }
}

class FinishReadingVm extends AutoDisposeFamilyNotifier<FinishReadingState, String> {
  @override
  FinishReadingState build(String arg) {
    final booksVm = ref.read(booksVmProvider.notifier);
    final book = booksVm.byId(arg);
    return FinishReadingState(
      minutes: 0, // Default value
      pageAtEnd: book?.currentPage ?? 0, // Set initial page from book
    );
  }

  void setNote(String value) => state = state.copyWith(note: value);
  void setMinutes(int value) => state = state.copyWith(minutes: value);
  void setDurationSeconds(int value) => state = state.copyWith(
    durationSeconds: value,
    minutes: value ~/ 60,
  );
  void setPageAtEnd(int value) => state = state.copyWith(pageAtEnd: value);
  void setAudioFilePath(String? path) => state = state.copyWith(audioFilePath: path);
  void setNoteFilePath(String? path) => state = state.copyWith(noteFilePath: path);
  void setTitle(String title) => state = state.copyWith(title: title);
  void setBookReview(String review) => state = state.copyWith(bookReview: review);
  void setFinalTotalHours(String hours) => state = state.copyWith(finalTotalHours: hours);
  void setRating(int? rating) => state = state.copyWith(rating: rating);

  /// Kitaba ait tüm okuma loglarının sürelerini toplar ve state'e yazar
  Future<void> loadTotalMinutesForBook() async {
    final repo = ref.read(readingLogsRepositoryProvider);
    final logs = await repo.listByBookId(arg);
    final totalSeconds = logs.fold<int>(0, (sum, log) => sum + log.effectiveDurationSeconds);
    if (totalSeconds > 0) {
      state = state.copyWith(minutes: totalSeconds ~/ 60, durationSeconds: totalSeconds);
    }
  }

  Future<FinishReadingResult> saveAndMarkRead() async {
    if (state.isSaving) {
      return const FinishReadingResult(shouldShowCongrats: false, shouldShowStreak: false, isBookCompleted: false);
    }
    state = state.copyWith(isSaving: true, error: null);

    try {
      final booksVm = ref.read(booksVmProvider.notifier);
      final book = booksVm.byId(arg); // arg is the bookId in FamilyNotifier
      if (book == null) {
        state = state.copyWith(isSaving: false);
        return const FinishReadingResult(shouldShowCongrats: false, shouldShowStreak: false, isBookCompleted: false);
      }

      final pageAtEnd = (state.pageAtEnd ?? book.currentPage ?? 0).clamp(0, book.totalPages);
      final isBookCompleted = pageAtEnd >= book.totalPages;

      // Bugün ilk defa kayıt alınıyor mu kontrol et (kaydı eklemeden önce)
      final logsRepo = ref.read(readingLogsRepositoryProvider);
      final hasOtherToday = await logsRepo.hasCompletedReadingToday();
      final shouldShowStreak = !hasOtherToday;

      String? persistentImagePath;
      if (state.noteFilePath != null) {
        try {
          final file = File(state.noteFilePath!);
          if (await file.exists()) {
            final appDir = await getApplicationDocumentsDirectory();
            final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(state.noteFilePath!)}';
            final savedImage = await file.copy('${appDir.path}/$fileName');
            persistentImagePath = savedImage.path;
          }
        } catch (e) {
          debugPrint('Resim kaydedilirken hata: $e');
          // Hata olsa bile devam et, belki temp dosyası hala duruyordur
          persistentImagePath = state.noteFilePath;
        }
      }

      // Okuma kaydı ekle
      final logId = DateTime.now().microsecondsSinceEpoch.toString();
      final log = ReadingLog(
        id: logId,
        bookId: arg, // arg is bookId
        date: DateTime.now(),
        minutes: state.minutes,
        durationSeconds: state.durationSeconds,
        pageAtEnd: pageAtEnd,
        note: (state.note?.trim().isNotEmpty ?? false) ? state.note!.trim() : null,
        audioFilePath: state.audioFilePath,
        noteFilePath: persistentImagePath, // Use persistent path
        title: state.title,
      );
      
      // Use notifier to add log so UI updates immediately
      await ref.read(readingLogsProvider.notifier).addLog(log);
      
      // Provider'ları invalidate et ki yeni kayıt görünsün
      ref.invalidate(readingLogsProvider);
      
      // readingLogProvider'ı invalidate et (family provider olduğu için logId ile)
      ref.invalidate(readingLogProvider(logId));
      
      // _readingLogProvider'ı invalidate et (family provider olduğu için logId ile)
      // Not: reading_log_detail_screen.dart'da tanımlı, burada import edemeyiz
      // Ama repository'yi invalidate edersek _readingLogProvider otomatik yenilenecek
      // Ancak bu yeni instance oluşturur, bu yüzden önce storage'a yazılmasını bekliyoruz
      // _save() zaten await edildi, bu yüzden güvenli
      ref.invalidate(readingLogsRepositoryProvider);

      // Kitabın currentPage'ini güncelle
      await booksVm.updateCurrentPage(arg, pageAtEnd);

      // Eğer kitap tamamlandıysa, kitabı okunduya al ve review bilgilerini kaydet
      if (isBookCompleted) {
        
        // Varsa review ve total minutes bilgilerini de güncelle
        int? finalMinutes;
        if (state.finalTotalHours != null && state.finalTotalHours!.isNotEmpty) {
           final hours = double.tryParse(state.finalTotalHours!.replaceAll(',', '.'));
           if (hours != null) {
             finalMinutes = (hours * 60).round();
           }
        }
        // Timer'dan gelen süreyi fallback olarak kullan
        finalMinutes ??= state.minutes > 0 ? state.minutes : null;
        
        // Kitabı okundu olarak işaretle ve review bilgilerini kaydet
        await booksVm.markAsRead(
          arg, 
          review: state.bookReview, 
          finalMinutes: finalMinutes,
          rating: state.rating,
        );

        state = state.copyWith(isSaving: false);
        return FinishReadingResult(
          shouldShowCongrats: true,
          shouldShowStreak: shouldShowStreak,
          isBookCompleted: true,
        );
      }

      // Kitap tamamlanmadıysa ama ilk kayıt ise streak göster
      state = state.copyWith(isSaving: false);
      return FinishReadingResult(
        shouldShowCongrats: false,
        shouldShowStreak: shouldShowStreak,
        isBookCompleted: false,
      );
    } catch (e) {
      // Hata durumunda state'i resetle
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}

@immutable
class FinishReadingResult {
  const FinishReadingResult({
    required this.shouldShowCongrats,
    required this.shouldShowStreak,
    required this.isBookCompleted,
  });

  final bool shouldShowCongrats;
  final bool shouldShowStreak;
  final bool isBookCompleted;
}

final finishReadingVmProvider =
    NotifierProvider.autoDispose.family<FinishReadingVm, FinishReadingState, String>(FinishReadingVm.new);


