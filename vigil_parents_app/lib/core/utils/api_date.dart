/// Parses a timestamp from an API payload into a local [DateTime].
///
/// The collector reads Android's SMS and call-log tables, whose `date` columns
/// hold epoch **milliseconds**, and those reach us as numbers or numeric
/// strings. `DateTime.tryParse` only understands ISO-8601 and returns null for
/// them, which silently turned every timestamp into "no date at all".
///
/// That is worse than a cosmetic problem: [DayWindow.includes] deliberately
/// excludes undated entries, so a "Last 2 days" filter dropped the entire list
/// while the counters above it — which read the unfiltered data — still showed
/// hundreds of rows.
DateTime? parseApiDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is num) return _fromEpoch(value.toInt());

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  // ISO first: a date-only form like "20240115" is a valid ISO string and must
  // not be mistaken for an epoch value.
  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso.toLocal();

  final epoch = int.tryParse(raw);
  return epoch == null ? null : _fromEpoch(epoch);
}

/// Epoch values arrive in seconds, milliseconds or microseconds depending on
/// which table they came from, and magnitude is the only thing that tells them
/// apart. Current values are ~1.7e9 / ~1.7e12 / ~1.7e15 respectively, so the
/// thresholds sit an order of magnitude clear of each.
DateTime? _fromEpoch(int value) {
  if (value <= 0) return null;
  if (value < 100000000000) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  if (value < 100000000000000) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.fromMicrosecondsSinceEpoch(value);
}
