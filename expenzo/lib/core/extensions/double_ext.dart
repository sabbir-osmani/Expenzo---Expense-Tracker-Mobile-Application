import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

extension DoubleExt on double {
  /// Always full number, never shortened. Handles any size gracefully.
  /// Uses compact suffix only beyond 10 crore (100,000,000) to prevent UI break.
  String get toCurrency {
    final abs = this.abs();
    String formatted;

    if (abs >= 10000000) {
      // 1 crore+ : show as X.XX Cr to prevent layout overflow
      formatted = '${(this / 10000000).toStringAsFixed(2)} Cr';
    } else {
      // Full number with commas: ৳ 1,25,000.00 (BD format) or standard
      formatted = NumberFormat('#,##0.00').format(this);
    }

    return '${AppConstants.currencySymbol} $formatted';
  }

  /// Same as toCurrency — no compact shortening below 1 crore.
  String get toCompactCurrency => toCurrency;

  bool get isValidAmount =>
      this > 0 && this <= AppConstants.maxTransactionAmount;

  double get rounded => double.parse(toStringAsFixed(2));
}