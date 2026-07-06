import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';
import 'package:libris/features/books/application/books_providers.dart';
import 'package:libris/features/reading/domain/reading_log.dart';
import 'package:libris/features/profile/presentation/calendar_day_detail_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  testWidgets('lists a session from an UNFINISHED book (T1.12)', (tester) async {
    const book = Book(
      id: 'b1', title: 'Yarım Kitap', author: 'A', totalPages: 300,
      shelf: BookShelf.reading, currentPage: 50,
    );
    final log = ReadingLog(
      id: 'l1', bookId: 'b1', date: DateTime(2026, 1, 15, 10),
      minutes: 30, pageAtEnd: 50, title: 'Sabah Oturumu',
    );

    final container = ProviderContainer(overrides: [
      booksRepositoryProvider.overrideWithValue(InMemoryBooksRepository(seed: [book])),
    ]);
    addTearDown(container.dispose);
    // Pre-load BooksVm on the REAL event loop (runAsync) so byId() has the book
    // by the time the screen builds — the screen watches the notifier, not state.
    await tester.runAsync(() async {
      container.read(booksVmProvider.notifier);
      for (var i = 0; i < 100 && container.read(booksVmProvider).items.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: CalendarDayDetailScreen(date: DateTime(2026, 1, 15), logs: [log]),
      ),
    ));
    await tester.pumpAndSettle();

    // The unfinished book's session must appear (old code hid non-'read' books).
    expect(find.text('Yarım Kitap'), findsWidgets);
    expect(find.text('Sabah Oturumu'), findsWidgets);
  });

  testWidgets('lists a session whose book was deleted, as a placeholder (T1.12)',
      (tester) async {
    final log = ReadingLog(
      id: 'l1', bookId: 'gone', date: DateTime(2026, 1, 15, 10),
      minutes: 30, pageAtEnd: 50, title: 'Akşam Oturumu',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        booksRepositoryProvider.overrideWithValue(InMemoryBooksRepository(seed: const [])),
      ],
      child: MaterialApp(
        home: CalendarDayDetailScreen(date: DateTime(2026, 1, 15), logs: [log]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Silinmiş kitap'), findsWidgets);
    expect(find.text('Akşam Oturumu'), findsWidgets);
  });
}
