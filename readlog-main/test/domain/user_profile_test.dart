import 'package:flutter_test/flutter_test.dart';
import 'package:berber/features/profile/domain/user_profile.dart';

void main() {
  group('UserProfile', () {
    const profile = UserProfile(
      id: 'u1',
      name: 'Ali Veli',
      username: 'aliveli',
      email: 'ali@test.com',
      avatarUrl: 'https://example.com/avatar.jpg',
      avatarImagePath: '/local/avatar.jpg',
      dailyGoalMinutes: 60,
    );

    test('tüm alanlar atanır', () {
      expect(profile.id, 'u1');
      expect(profile.name, 'Ali Veli');
      expect(profile.username, 'aliveli');
      expect(profile.email, 'ali@test.com');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.avatarImagePath, '/local/avatar.jpg');
      expect(profile.dailyGoalMinutes, 60);
    });

    test('varsayılan dailyGoalMinutes 45', () {
      const p = UserProfile(id: 'x', name: 'Y', username: 'z');
      expect(p.dailyGoalMinutes, 45);
    });

    test('opsiyonel alanlar null olabilir', () {
      const p = UserProfile(id: 'x', name: 'Y', username: 'z');
      expect(p.email, isNull);
      expect(p.avatarUrl, isNull);
      expect(p.avatarImagePath, isNull);
    });

    test('copyWith alanları günceller', () {
      final updated = profile.copyWith(
        name: 'Ayşe',
        dailyGoalMinutes: 90,
      );
      expect(updated.name, 'Ayşe');
      expect(updated.dailyGoalMinutes, 90);
      // Değişmeyenler korunur
      expect(updated.id, 'u1');
      expect(updated.username, 'aliveli');
      expect(updated.email, 'ali@test.com');
    });

    test('copyWith parametresiz aynı değerleri korur', () {
      final copied = profile.copyWith();
      expect(copied.id, profile.id);
      expect(copied.name, profile.name);
      expect(copied.username, profile.username);
      expect(copied.email, profile.email);
      expect(copied.dailyGoalMinutes, profile.dailyGoalMinutes);
    });
  });
}
