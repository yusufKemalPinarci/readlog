import '../domain/user_profile.dart';
import '../../../shared/services/local_storage_service.dart';

abstract class ProfileRepository {
  Future<UserProfile> getCurrent();
  Future<void> update(UserProfile profile);
}

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._storage);

  final LocalStorageService _storage;

  static const _defaultProfile = UserProfile(
    id: 'u1',
    name: 'Okuyucu',
    username: 'okuyucu',
    dailyGoalMinutes: 30,
  );

  @override
  Future<UserProfile> getCurrent() async {
    final json = _storage.loadProfile();
    if (json != null) {
      return UserProfile.fromJson(json);
    }
    return _defaultProfile;
  }

  @override
  Future<void> update(UserProfile profile) async {
    await _storage.saveProfile(profile.toJson());
  }
}

