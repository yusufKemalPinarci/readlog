/// Type-tolerant readers for decoding persisted/imported JSON.
///
/// Stored data (SharedPreferences, backup files) may have drifted types across
/// app versions or been hand-edited. These helpers coerce leniently instead of
/// throwing, so a single odd field can't crash deserialization (see T1.3).
library;

/// Reads an int from an int/double/num/numeric-string, else null.
int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) {
    final i = int.tryParse(v.trim());
    if (i != null) return i;
    final d = double.tryParse(v.trim().replaceAll(',', '.'));
    if (d != null) return d.round();
  }
  return null;
}

/// Reads an int, falling back to [fallback] when absent/unparseable.
int asIntOr(Object? v, int fallback) => asIntOrNull(v) ?? fallback;

/// Reads a String, coercing non-string scalars via toString(); null stays null.
String? asStringOrNull(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

/// Parses an ISO-8601 date string, falling back to [fallback] on failure.
DateTime asDateOr(Object? v, DateTime fallback) {
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return d;
  }
  return fallback;
}

/// Returns `values[index]` when index is a valid in-range int, else [fallback].
/// Guards enum indices that drifted out of range (e.g. shelf: 7).
T enumByIndex<T>(List<T> values, Object? index, T fallback) {
  final i = asIntOrNull(index);
  if (i == null || i < 0 || i >= values.length) return fallback;
  return values[i];
}
