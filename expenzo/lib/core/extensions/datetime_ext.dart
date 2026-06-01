import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  /// Returns a month key in the format "YYYY-MM". Used for indexing.
  String get monthKey => DateFormat('yyyy-MM').format(this);

  /// Returns a human-readable month label e.g. "January 2025".
  String get monthLabel => DateFormat('MMMM yyyy').format(this);

  /// Returns a short month label e.g. "Jan 2025".
  String get shortMonthLabel => DateFormat('MMM yyyy').format(this);

  /// Returns a display date string e.g. "15 Jan 2025".
  String get displayDate => DateFormat('d MMM yyyy').format(this);

  /// Returns a display date+time string e.g. "15 Jan 2025, 3:45 PM".
  String get displayDateTime => DateFormat('d MMM yyyy, h:mm a').format(this);

  /// Returns a short time string e.g. "3:45 PM".
  String get displayTime => DateFormat('h:mm a').format(this);

  /// Returns the first moment of the month.
  DateTime get startOfMonth => DateTime(year, month, 1, 0, 0, 0);

  /// Returns the last moment of the month.
  DateTime get endOfMonth =>
      DateTime(year, month + 1, 0, 23, 59, 59, 999);

  /// Returns the same date at midnight.
  DateTime get startOfDay => DateTime(year, month, day, 0, 0, 0);

  /// Returns true if this date is in the same month/year as [other].
  bool isSameMonth(DateTime other) =>
      year == other.year && month == other.month;

  /// Returns a new DateTime with the month incremented by [months].
  DateTime addMonths(int months) {
    final newMonth = month + months;
    final yearOffset = (newMonth - 1) ~/ 12;
    final adjustedMonth = ((newMonth - 1) % 12) + 1;
    return DateTime(year + yearOffset, adjustedMonth, 1);
  }

  /// Returns a new DateTime with the month decremented by [months].
  DateTime subtractMonths(int months) => addMonths(-months);
}