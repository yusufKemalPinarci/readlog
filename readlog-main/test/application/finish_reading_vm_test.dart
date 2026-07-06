import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';
import 'package:libris/features/books/application/books_providers.dart';
import 'package:libris/features/reading/data/reading_logs_repository.dart';
import 'package:libris/features/reading/domain/reading_log.dart';
import 'package:libris/features/reading/application/reading_providers.dart';
import 'package:libris/features/reading/application/finish_reading_vm.dart';

/// Pumps microtasks so async provider loads (BooksVm._load, notifier ctors) settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ProviderContainer _makeContainer({
  required List<Book> books,
  List<ReadingLog> logs = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      booksRepositoryProvider.overrideWithValue(
        InMemoryBooksRepository(seed: books),
      ),
      readingLogsRepositoryProvider.overrideWithValue(
        InMemoryReadingLogsRepository(seed: logs),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('FinishReadingVm — minutes math (T1.1)', () {
    test('90-minute manual final entry stores 90 minutes, not 5400', () async {
      final container = _makeContainer(
        books: [
          const Book(
            id: 'b1',
            title: 'Test',
            author: 'A',
            totalPages: 100,
            shelf: BookShelf.reading,
            currentPage: 0,
          ),
        ],
      );

      // Keep the books VM alive and let its async load finish.
      container.listen(booksVmProvider, (_, __) {}, fireImmediately: true);
      await _settle();

      final vm = container.read(finishReadingVmProvider('b1').notifier);
      // Keep the auto-dispose family notifier alive.
      container.listen(finishReadingVmProvider('b1'), (_, __) {});

      vm.setPageAtEnd(100); // completes the book
      vm.setFinalTotalMinutes('90'); // screen sends MINUTES, not hours

      await vm.saveAndMarkRead();
      await _settle();

      final book = container.read(booksVmProvider.notifier).byId('b1');
      expect(book, isNotNull);
      expect(book!.totalMinutes, 90,
          reason: 'Manual "90 min" entry must not be inflated 60x to 5400.');
      expect(book.shelf, BookShelf.read);
    });
  });

  group('FinishReadingVm — direct finish no double count (T1.2)', () {
    test('direct finish does not re-save historical total as a new log', () async {
      // Book already has 300 minutes across 5 logs.
      final existingLogs = List<ReadingLog>.generate(
        5,
        (i) => ReadingLog(
          id: 'log$i',
          bookId: 'b1',
          date: DateTime(2026, 1, 1 + i),
          minutes: 60,
          pageAtEnd: (i + 1) * 10,
        ),
      );
      final container = _makeContainer(
        books: [
          const Book(
            id: 'b1',
            title: 'Test',
            author: 'A',
            totalPages: 100,
            shelf: BookShelf.reading,
            currentPage: 50,
          ),
        ],
        logs: existingLogs,
      );

      container.listen(booksVmProvider, (_, __) {}, fireImmediately: true);
      await _settle();

      final vm = container.read(finishReadingVmProvider('b1').notifier);
      container.listen(finishReadingVmProvider('b1'), (_, __) {});

      // Direct finish: prefill historical total, complete the book, no new session.
      await vm.loadTotalMinutesForBook();
      vm.setPageAtEnd(100);
      await vm.saveAndMarkRead();
      await _settle();

      final logs = await container
          .read(readingLogsRepositoryProvider)
          .listByBookId('b1');
      final totalMinutes =
          logs.fold<int>(0, (sum, l) => sum + l.effectiveDurationSeconds) ~/ 60;
      expect(totalMinutes, 300,
          reason:
              'Existing 300 min must not double to 600; final marker adds 0 new minutes.');
    });
  });
}
