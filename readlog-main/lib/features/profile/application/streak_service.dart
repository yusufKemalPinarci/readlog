import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reading/domain/reading_log.dart';

final streakServiceProvider = Provider((ref) => StreakService());

/// T2.5: step one calendar day back. `subtract(Duration(days: 1))` shifts by a
/// fixed 24h and lands on the wrong day across DST transitions (23/25h days);
/// building the date from components is DST-safe.
DateTime _prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

class StreakService {
  /// Calculate current streak (consecutive days ending today or yesterday)
  int calculateCurrentStreak(List<ReadingLog> logs) {
    if (logs.isEmpty) return 0;

    // Sort logs descending by date
    final sortedLogs = List<ReadingLog>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Get unique dates (normalized to YMD)
    final uniqueDates = _getUniqueDates(sortedLogs);
    if (uniqueDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = _prevDay(today);

    // Check if user read today or yesterday
    final lastReadDate = uniqueDates.first;
    if (lastReadDate != today && lastReadDate != yesterday) {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = lastReadDate;

    for (final date in uniqueDates) {
      if (date == checkDate) {
        streak++;
        checkDate = _prevDay(checkDate);
      } else {
        break; 
      }
    }

    return streak;
  }

  /// Calculate best streak ever
  int calculateBestStreak(List<ReadingLog> logs) {
    if (logs.isEmpty) return 0;

    // Sort logs descending by date
    final sortedLogs = List<ReadingLog>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    final uniqueDates = _getUniqueDates(sortedLogs);
    if (uniqueDates.isEmpty) return 0;

    int maxStreak = 0;
    int currentStreak = 0;
    DateTime? expectedDate;

    for (final date in uniqueDates) {
      if (expectedDate == null) {
        currentStreak = 1;
        expectedDate = _prevDay(date);
      } else {
        if (date == expectedDate) {
          currentStreak++;
          expectedDate = _prevDay(date);
        } else {
          // Break in streak
          if (currentStreak > maxStreak) maxStreak = currentStreak;
          currentStreak = 1;
          expectedDate = _prevDay(date);
        }
      }
    }
    
    if (currentStreak > maxStreak) maxStreak = currentStreak;
    
    return maxStreak;
  }

  List<DateTime> _getUniqueDates(List<ReadingLog> logs) {
    final dates = <DateTime>{};
    for (final log in logs) {
      dates.add(DateTime(log.date.year, log.date.month, log.date.day));
    }
    return dates.toList()..sort((a, b) => b.compareTo(a)); // Descending
  }
}
