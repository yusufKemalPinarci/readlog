import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libris/features/profile/application/profile_providers.dart';
import 'package:libris/features/profile/domain/user_profile.dart';
import 'package:libris/features/profile/presentation/daily_goal_screen.dart';

Widget _wrap(UserProfile profile) {
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith((ref) async => profile),
    ],
    child: const MaterialApp(home: DailyGoalScreen()),
  );
}

void main() {
  testWidgets('fresh profile (goal 0) does not crash the slider and clamps to 5 (T1.11)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const UserProfile(id: 'u1', name: '', username: '', dailyGoalMinutes: 0),
    ));
    await tester.pumpAndSettle();

    // Slider requires value >= min(5); a stored 0 must be clamped, not crash.
    expect(tester.takeException(), isNull);
    expect(find.text('5 dk'), findsWidgets);
  });

  testWidgets('profile goal 45 is preselected (T1.11)', (tester) async {
    await tester.pumpWidget(_wrap(
      const UserProfile(id: 'u1', name: 'X', username: 'x', dailyGoalMinutes: 45),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('45 dk'), findsWidgets);
  });
}
