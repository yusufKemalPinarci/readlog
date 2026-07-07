import 'package:flutter_test/flutter_test.dart';
import 'package:libris/features/books/domain/book.dart';
import 'package:libris/features/books/data/books_repository.dart';
import 'package:libris/features/books/application/books_vm.dart';

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('re-read accounting (T2.7)', () {
    late BooksVm vm;

    setUp(() async {
      vm = BooksVm(InMemoryBooksRepository(seed: [
        const Book(id: 'b', title: 'T', author: 'A', totalPages: 100, shelf: BookShelf.reading),
      ]));
      await _settle();
    });

    test('completing increments readCount; restarting does not', () async {
      expect(vm.byId('b')!.readCount, 0);

      await vm.markAsRead('b');
      await _settle();
      expect(vm.byId('b')!.readCount, 1);
      expect(vm.byId('b')!.shelf, BookShelf.read);

      // Restart (re-read) must NOT count and must stamp lastStartedAt.
      await vm.restartReading('b');
      await _settle();
      expect(vm.byId('b')!.readCount, 1, reason: 'abandoning/restarting must not count');
      expect(vm.byId('b')!.shelf, BookShelf.reading);
      expect(vm.byId('b')!.lastStartedAt, isNotNull);

      // Completing the re-read counts.
      await vm.markAsRead('b');
      await _settle();
      expect(vm.byId('b')!.readCount, 2);
    });

    test('re-marking an already-read book does not double count', () async {
      await vm.markAsRead('b');
      await _settle();
      await vm.markAsRead('b');
      await _settle();
      expect(vm.byId('b')!.readCount, 1);
    });
  });
}
