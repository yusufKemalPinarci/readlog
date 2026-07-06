// Canonical duration formatters (T2.8), so every screen renders time the same
// way and sub-minute sessions never disappear.

/// Human-readable Turkish duration: "45 sn", "12 dk", "12 dk 30 sn", "1 sa 5 dk".
String formatDurationHuman(Duration d) {
  final totalSeconds = d.inSeconds;
  if (totalSeconds < 60) return '$totalSeconds sn';
  if (totalSeconds < 3600) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return sec == 0 ? '$min dk' : '$min dk $sec sn';
  }
  final hrs = totalSeconds ~/ 3600;
  final min = (totalSeconds % 3600) ~/ 60;
  return min == 0 ? '$hrs sa' : '$hrs sa $min dk';
}

/// Same as [formatDurationHuman] but from a raw seconds count.
String formatSecondsHuman(int totalSeconds) =>
    formatDurationHuman(Duration(seconds: totalSeconds));

/// Clock-style timer: MM:SS, or HH:MM:SS once an hour is reached (T2.8 — the old
/// MM:SS timer wrapped and hid whole hours past 60 minutes).
String formatDurationClock(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
