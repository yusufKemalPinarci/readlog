import '../../features/reading/domain/reading_log.dart';

/// Pages read for a book on [day] = the highest `pageAtEnd` reached on that day
/// minus the highest `pageAtEnd` reached before that day (clamped to >= 0).
///
/// T2.9: this mirrors the profile screen's period math and, unlike the old
/// first/last-of-day diff, is correct for multi-session days, mid-book days
/// (where reading started on a prior day), and re-reads (where the day's page
/// count drops below the prior maximum).
///
/// [bookLogs] must be all logs for a single book (any dates); other books'
/// logs, if present, are ignored only insofar as the caller passes them.
int pagesReadOnDay(List<ReadingLog> bookLogs, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);

  int? maxOnDay;
  int maxBefore = 0;
  for (final log in bookLogs) {
    if (!log.date.isBefore(dayStart) && log.date.isBefore(dayEnd)) {
      maxOnDay = (maxOnDay == null || log.pageAtEnd > maxOnDay)
          ? log.pageAtEnd
          : maxOnDay;
    } else if (log.date.isBefore(dayStart)) {
      if (log.pageAtEnd > maxBefore) maxBefore = log.pageAtEnd;
    }
  }

  if (maxOnDay == null) return 0;
  // Re-read: the day's page is below the prior max → treat as a fresh start.
  if (maxOnDay < maxBefore) return maxOnDay;
  return maxOnDay - maxBefore;
}
