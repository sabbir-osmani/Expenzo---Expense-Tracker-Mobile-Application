import '../extensions/datetime_ext.dart';

class AppDateUtils {
  AppDateUtils._();

  /// Parses a monthKey string "YYYY-MM" into a DateTime at start of that month.
  static DateTime fromMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      throw FormatException('Invalid monthKey: $monthKey');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateTime(year, month, 1);
  }

  /// Returns a sorted list of unique monthKeys from oldest to newest.
  static List<String> sortedMonthKeys(List<String> keys) {
    final unique = keys.toSet().toList();
    unique.sort();
    return unique;
  }

  /// Returns whether [dt] falls within the given [monthKey].
  static bool isInMonth(DateTime dt, String monthKey) {
    return dt.monthKey == monthKey;
  }

  /// Returns all monthKeys between [from] and [to] inclusive.
  static List<String> monthRange(DateTime from, DateTime to) {
    final result = <String>[];
    var current = DateTime(from.year, from.month, 1);
    final end = DateTime(to.year, to.month, 1);
    while (!current.isAfter(end)) {
      result.add(current.monthKey);
      current = current.addMonths(1);
    }
    return result;
  }

  /// The last moment of the last day of [monthKey].
  static DateTime endOfMonthKey(String monthKey) {
    return fromMonthKey(monthKey).endOfMonth;
  }

  /// The first moment of the first day of [monthKey].
  static DateTime startOfMonthKey(String monthKey) {
    return fromMonthKey(monthKey).startOfMonth;
  }
}