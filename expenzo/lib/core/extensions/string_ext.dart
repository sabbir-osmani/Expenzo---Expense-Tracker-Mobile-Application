extension StringExt on String {
  /// Capitalises the first letter of each word.
  String get toTitleCase {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Returns true if the string is null or empty after trimming.
  bool get isNullOrEmpty => trim().isEmpty;

  /// Truncates to [maxLength] and appends '…' if needed.
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}…';
  }

  /// Parses a hex colour string like '#FF5722' or 'FF5722' into an int.
  int get colorValue {
    final hex = replaceAll('#', '');
    if (hex.length == 6) {
      return int.parse('FF$hex', radix: 16);
    } else if (hex.length == 8) {
      return int.parse(hex, radix: 16);
    }
    throw FormatException('Invalid hex colour: $this');
  }
}