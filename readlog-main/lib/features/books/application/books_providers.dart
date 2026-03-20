import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/books_repository.dart';
import '../../../shared/services/local_storage_service.dart';

export 'books_vm.dart';

final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return LocalBooksRepository(storage);
});


