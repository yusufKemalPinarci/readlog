import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/page_turn_transition.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';

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
import '../../features/auth/application/auth_service.dart'; // Assuming authProvider is here

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final storage = ref.read(localStorageServiceProvider);
      final isFirstLaunch = storage.getIsFirstLaunch();

      // If first launch and not already on onboarding
      if (isFirstLaunch && state.fullPath != Routes.onboarding) {
        return Routes.onboarding; // Go to onboarding
      }

      // If verifying onboarding but first launch is false (user finished onboarding),
      // redirect away from onboarding.
      if (!isFirstLaunch && state.fullPath == Routes.onboarding) {
        return Routes.login; // Or Home, but let auth logic decide
      }

      // Auth logic
      final isAuthenticated = ref.read(authProvider).user != null;
      final isLoggingIn = state.fullPath == Routes.login || state.fullPath == '/login/register';

      if (!isAuthenticated && !isLoggingIn && state.fullPath != Routes.onboarding) {
        return Routes.login;
      }

      if (isAuthenticated && isLoggingIn) {
        return Routes.home;
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'register',
            builder: (context, state) => const RegisterScreen(),
          ),
        ],
      ),
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
          final extra = state.extra as Map<String, dynamic>;
          return CalendarDayDetailScreen(
            date: extra['date'] as DateTime,
            logs: extra['logs'] as List<ReadingLog>,
          );
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
  static const login = '/login';
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


