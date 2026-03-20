import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import '../../../shared/services/local_storage_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return LocalProfileRepository(storage);
});

final profileProvider = FutureProvider<UserProfile>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getCurrent();
});

