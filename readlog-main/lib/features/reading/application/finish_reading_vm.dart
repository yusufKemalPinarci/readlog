import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/application/books_vm.dart';
import '../domain/reading_log.dart';
import 'reading_providers.dart';

/// Sentinel for [FinishReadingState.copyWith] so nullable fields can be cleared.
const Object _unset = Object();

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

  /// Book's cumulative total reading time in MINUTES (as entered/prefilled).
  /// Despite historical naming, this has always held minutes — the finish
  /// screen sends `(hours * 60) + minutes` here.
  final String? finalTotalMinutes;
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
    this.finalTotalMinutes,
    this.rating,
  });

  FinishReadingState copyWith({
    int? minutes,
    Object? durationSeconds = _unset,
    Object? pageAtEnd = _unset,
    Object? note = _unset,
    Object? audioFilePath = _unset,
    Object? noteFilePath = _unset,
    Object? title = _unset,
    bool? isSaving,
    Object? error = _unset,
    Object? bookReview = _unset,
    Object? finalTotalMinutes = _unset,
    Object? rating = _unset,
  }) {
    return FinishReadingState(
      minutes: minutes ?? this.minutes,
      durationSeconds: identical(durationSeconds, _unset) ? this.durationSeconds : durationSeconds as int?,
      pageAtEnd: identical(pageAtEnd, _unset) ? this.pageAtEnd : pageAtEnd as int?,
      note: identical(note, _unset) ? this.note : note as String?,
      audioFilePath: identical(audioFilePath, _unset) ? this.audioFilePath : audioFilePath as String?,
      noteFilePath: identical(noteFilePath, _unset) ? this.noteFilePath : noteFilePath as String?,
      title: identical(title, _unset) ? this.title : title as String?,
      isSaving: isSaving ?? this.isSaving,
      error: identical(error, _unset) ? this.error : error as String?,
      bookReview: identical(bookReview, _unset) ? this.bookReview : bookReview as String?,
      finalTotalMinutes: identical(finalTotalMinutes, _unset) ? this.finalTotalMinutes : finalTotalMinutes as String?,
      rating: identical(rating, _unset) ? this.rating : rating as int?,
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
  void setFinalTotalMinutes(String minutes) => state = state.copyWith(finalTotalMinutes: minutes);
  void setRating(int? rating) => state = state.copyWith(rating: rating);

  /// Kitaba ait tüm okuma loglarının sürelerini toplar ve "toplam süre" alanına
  /// (finalTotalMinutes) ön-değer olarak yazar.
  ///
  /// T1.2: Bu toplamı `minutes`/`durationSeconds` alanlarına YAZMAZ; aksi halde
  /// direkt bitirmede bu tarihsel toplam yeni bir log olarak tekrar kaydedilip
  /// çift sayıma yol açardı. Yeni log yalnızca bu oturumun süresini taşır.
  Future<void> loadTotalMinutesForBook() async {
    final repo = ref.read(readingLogsRepositoryProvider);
    var logs = await repo.listByBookId(arg);
    // T2.7: on a re-read, only sum logs from the current pass (>= lastStartedAt).
    final book = ref.read(booksVmProvider.notifier).byId(arg);
    final since = book?.lastStartedAt;
    if (since != null) {
      logs = logs.where((log) => !log.date.isBefore(since)).toList();
    }
    final totalSeconds = logs.fold<int>(0, (sum, log) => sum + log.effectiveDurationSeconds);
    final totalMinutes = totalSeconds ~/ 60;
    if (totalMinutes > 0) {
      state = state.copyWith(finalTotalMinutes: totalMinutes.toString());
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
      
      // Use notifier to add log so UI updates immediately. The notifier reloads
      // from the singleton repository, so no provider invalidation is needed.
      await ref.read(readingLogsProvider.notifier).addLog(log);

      // T2.4: never invalidate the repository/list providers — that would rebuild
      // a fresh repo from storage and drop any in-flight in-memory state
      // (lost-update / resurrection class). Only refresh the specific per-log
      // detail view, which reads from the same singleton repo.
      ref.invalidate(readingLogProvider(logId));

      // Kitabın currentPage'ini güncelle
      await booksVm.updateCurrentPage(arg, pageAtEnd);

      // Eğer kitap tamamlandıysa, kitabı okunduya al ve review bilgilerini kaydet
      if (isBookCompleted) {
        
        // Varsa review ve total minutes bilgilerini de güncelle.
        // T1.1: finalTotalMinutes ekrandan zaten DAKİKA olarak gelir; burada
        // 60 ile çarpmak 60x şişmeye yol açıyordu. Doğrudan dakika olarak oku.
        int? finalMinutes;
        if (state.finalTotalMinutes != null && state.finalTotalMinutes!.trim().isNotEmpty) {
           final parsed = double.tryParse(state.finalTotalMinutes!.replaceAll(',', '.'));
           if (parsed != null) {
             finalMinutes = parsed.round();
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


