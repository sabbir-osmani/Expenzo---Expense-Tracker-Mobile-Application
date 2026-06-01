import 'package:equatable/equatable.dart';

/// Computed wallet state — never stored, always derived from transactions.
class WalletSummary extends Equatable {
  const WalletSummary({
    required this.walletId,
    required this.walletName,
    required this.balance,
    required this.totalInflow,
    required this.totalOutflow,
  });

  final String walletId;
  final String walletName;
  final double balance;
  final double totalInflow;
  final double totalOutflow;

  WalletSummary copyWith({
    String? walletId,
    String? walletName,
    double? balance,
    double? totalInflow,
    double? totalOutflow,
  }) {
    return WalletSummary(
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      balance: balance ?? this.balance,
      totalInflow: totalInflow ?? this.totalInflow,
      totalOutflow: totalOutflow ?? this.totalOutflow,
    );
  }

  @override
  List<Object?> get props =>
      [walletId, walletName, balance, totalInflow, totalOutflow];
}

/// Monthly financial summary across all wallets.
class MonthlySummary extends Equatable {
  const MonthlySummary({
    required this.monthKey,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.totalTransferred,
    required this.openingBalance,
    required this.closingBalance,
    required this.walletSummaries,
  });

  final String monthKey;
  final double totalIncome;
  final double totalExpense;
  final double totalSavings;
  final double totalTransferred;
  final double openingBalance;
  final double closingBalance;

  /// Per-wallet snapshots for this month.
  final List<WalletSummary> walletSummaries;

  double get netChange => totalIncome - totalExpense;

  @override
  List<Object?> get props => [
        monthKey,
        totalIncome,
        totalExpense,
        totalSavings,
        totalTransferred,
        openingBalance,
        closingBalance,
        walletSummaries,
      ];
}

/// Category-level spending breakdown for analytics.
class CategoryBreakdown extends Equatable {
  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.total,
    required this.percentage,
    required this.transactionCount,
  });

  final String categoryId;
  final String categoryName;
  final String colorHex;
  final double total;
  final double percentage;
  final int transactionCount;

  @override
  List<Object?> get props => [
        categoryId, categoryName, colorHex, total, percentage, transactionCount,
      ];
}