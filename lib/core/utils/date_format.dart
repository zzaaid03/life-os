/// Shared, unambiguous date formatting.
///
/// Never render a date as `M/D/YYYY`. Zaid reads dates in Germany, where
/// `1/9/2026` means 9 January to a US reader and 1 September to him — there
/// is no way to tell from the string which one a screen meant. A named
/// month cannot be read two ways, so every screen should format through
/// [formatDay] or [formatDayTime] instead of rolling its own slash format.
library;

const _kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a date as "18 Aug".
String formatDay(DateTime date) {
  return '${date.day} ${_kMonths[date.month - 1]}';
}

/// Formats a date and time as "18 Aug at 14:05".
String formatDayTime(DateTime dt) {
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${formatDay(dt)} at ${dt.hour}:$minute';
}
