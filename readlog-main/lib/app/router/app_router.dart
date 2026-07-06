import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/page_turn_transition.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/library/presentation/add_book_screen.dart';
import '../../features/library/presentation/barcode_scanner_screen.dart';
import '../../features/library/presentation/edit_completed_book_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/daily_goal_screen.dart';
import '../../features/reading/presentation/active_reading_screen.dart';
import '../../features/reading/presentation/finish_reading_flow_screen.dart';
import '../../features/reading/presentation/reading_log_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/reading/presentation/book_reading_logs_screen.dart';
import '../../features/reading/presentation/edit_reading_log_screen.dart';
import '../../features/stats/presentation/streak_screen.dart';
import '../../shared/services/local_storage_service.dart';
import '../../features/profile/presentation/calendar_day_detail_screen.dart';
import '../../features/reading/domain/reading_log.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final storage = ref.read(localStorageServiceProvider);
      final isFirstLaunch = storage.getIsFirstLaunch();

      // İlk açılışta onboarding'e yönlendir
      if (isFirstLaunch && state.fullPath != Routes.onboarding) {
        return Routes.onboarding;
      }

      // Onboarding tamamlandıysa home'a yönlendir
      if (!isFirstLaunch && state.fullPath == Routes.onboarding) {
        return Routes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.home,
        pageBuilder: (context, state) => PageTurnTransition(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: Routes.addBook,
        pageBuilder: (context, state) => PageTurnTransition(
          key: state.pageKey,
          child: AddBookScreen(
            bookId: state.uri.queryParameters['bookId'],
          ),
        ),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.dailyGoal,
        builder: (context, state) => const DailyGoalScreen(),
      ),
      GoRoute(
        path: '/active-reading/:bookId',
        builder: (context, state) => ActiveReadingScreen(
          bookId: state.pathParameters['bookId']!,
        ),
      ),
      GoRoute(
        path: '/finish/:bookId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final minutes = extra?['minutes'] as int?;
          final durationSeconds = extra?['durationSeconds'] as int?;
          final recordingPath = extra?['recordingPath'] as String?;
          final isDirectFinish = extra?['isDirectFinish'] as bool? ?? false;
          return FinishReadingFlowScreen(
            bookId: state.pathParameters['bookId']!,
            initialMinutes: minutes,
            initialDurationSeconds: durationSeconds,
            recordingPath: recordingPath,
            isDirectFinish: isDirectFinish,
          );
        },
      ),
      GoRoute(
        path: '/reading-log/:logId',
        builder: (context, state) => ReadingLogDetailScreen(
          logId: state.pathParameters['logId']!,
        ),
      ),
      GoRoute(
        path: '/edit-reading-log/:logId',
        builder: (context, state) => EditReadingLogScreen(
          logId: state.pathParameters['logId']!,
        ),
      ),
      GoRoute(
        path: '/book-reading-logs/:bookId',
        builder: (context, state) => BookReadingLogsScreen(
          bookId: state.pathParameters['bookId']!,
        ),
      ),
      GoRoute(
        path: '/book-detail/:bookId',
        builder: (context, state) => BookReadingLogsScreen(
          bookId: state.pathParameters['bookId']!,
        ),
      ),
      GoRoute(
        path: '/edit-completed-book/:bookId',
        builder: (context, state) => EditCompletedBookScreen(
          bookId: state.pathParameters['bookId']!,
        ),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.streak,
        builder: (context, state) => const StreakScreen(),
      ),
      GoRoute(
        name: 'calendar_day_detail',
        path: '/calendar-day-detail',
        builder: (context, state) {
          // T2.18: tolerate a missing/malformed extra instead of crashing.
          final extra = state.extra as Map<String, dynamic>?;
          final date = extra?['date'];
          final logs = extra?['logs'];
          if (date is! DateTime || logs is! List<ReadingLog>) {
            return _RouterErrorScreen(error: Exception('Geçersiz gün detayı verisi'));
          }
          return CalendarDayDetailScreen(date: date, logs: logs);
        },
      ),
      GoRoute(
        path: Routes.scanner,
        builder: (context, state) => const BarcodeScannerScreen(),
      ),
    ],
    errorBuilder: (context, state) => _RouterErrorScreen(error: state.error),
  );
});

abstract final class Routes {
  static const home = '/home';
  static const addBook = '/add-book';
  static String editBook(String id) => '/add-book?bookId=$id';
  static String editCompletedBook(String id) => '/edit-completed-book/$id';
  static const profile = '/profile';
  static String activeReadingFor(String bookId) => '/active-reading/$bookId';
  static String finishReadingFor(String bookId) => '/finish/$bookId';
  static String finishReadingFlow(String bookId) => '/finish/$bookId';
  static String readingLogDetail(String logId) => '/reading-log/$logId';
  static String editReadingLog(String logId) => '/edit-reading-log/$logId';
  static String bookReadingLogs(String bookId) => '/book-reading-logs/$bookId';
  static String bookDetail(String bookId) => '/book-detail/$bookId';
  static const editProfile = '/edit-profile';
  static const dailyGoal = '/daily-goal';
  static const settings = '/settings';
  static const scanner = '/scanner';
  static const onboarding = '/onboarding';
  static const streak = '/streak';
}

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Sayfa bulunamadı.\n${error ?? ''}'),
        ),
      ),
    );
  }
}


