import '../../core/enums/transaction_type.dart';
import '../../data/models/transaction_model.dart';
import '../entities/wallet_summary.dart';

/// Single source of truth for ALL money calculations in Expenzo.
/// Every screen, provider, and widget must use this service.
/// No screen calculates balances independently.
class BalanceService {
  const BalanceService();

  // ── Core ──────────────────────────────────────────────────────────────────

  /// Wallet balance from ALL transactions.
  double computeWalletBalance(
    String walletId,
    List<TransactionModel> transactions,
  ) {
    // Use integer-safe accumulation to avoid floating-point drift.
    int paise = 0;
    for (final t in transactions) {
      paise += _contributionPaise(walletId, t);
    }
    return _fromPaise(paise);
  }

  /// Wallet balance up to [upTo] datetime (for opening balance calculation).
  double computeWalletBalanceUpTo(
    String walletId,
    List<TransactionModel> transactions,
    DateTime upTo,
  ) {
    int paise = 0;
    for (final t in transactions) {
      if (!t.dateTime.isAfter(upTo)) {
        paise += _contributionPaise(walletId, t);
      }
    }
    return _fromPaise(paise);
  }

  /// Spendable balance, optionally excluding a transaction being edited.
  double availableBalance({
    required String walletId,
    required List<TransactionModel> allTransactions,
    String? excludeTransactionId,
  }) {
    final txns = excludeTransactionId != null
        ? allTransactions.where((t) => t.id != excludeTransactionId).toList()
        : allTransactions;
    return computeWalletBalance(walletId, txns);
  }

  /// True if wallet can afford [amount] (optionally excluding one transaction).
  bool canAfford({
    required String walletId,
    required double amount,
    required List<TransactionModel> allTransactions,
    String? excludeTransactionId,
  }) {
    return availableBalance(
          walletId: walletId,
          allTransactions: allTransactions,
          excludeTransactionId: excludeTransactionId,
        ) >=
        amount - 0.001; // tiny epsilon for float comparison
  }

  // ── Core contribution (integer paise to avoid float drift) ────────────────

  /// Returns contribution of transaction [t] to [walletId] in paise (1/100 BDT).
  int _contributionPaise(String walletId, TransactionModel t) {
    final amountPaise = _toPaise(t.amount);
    switch (t.type) {
      case TransactionType.income:
        // Income credits the source wallet.
        return t.sourceWalletId == walletId ? amountPaise : 0;

      case TransactionType.expense:
        // Expense debits the source wallet.
        return t.sourceWalletId == walletId ? -amountPaise : 0;

      case TransactionType.transfer:
      case TransactionType.savings:
        // Transfer: source debited, destination credited.
        // The stored amount is EXACTLY what the destination receives.
        // Any charge is stored as a SEPARATE expense record.
        int c = 0;
        if (t.sourceWalletId == walletId) c -= amountPaise;
        if (t.destinationWalletId == walletId) c += amountPaise;
        return c;
    }
  }

  // ── Integer paise helpers ─────────────────────────────────────────────────

  static int _toPaise(double bdt) => (bdt * 100).round();
  static double _fromPaise(int paise) => paise / 100.0;

  /// Round to exactly 2 decimal places — use for ALL money values before storing.
  static double round2(double value) {
    return (value * 100).round() / 100.0;
  }

  /// Calculate charge amount from principal and rate.
  static double calcCharge(double amount, double rate) {
    return round2(amount * rate);
  }

  // ── Monthly wallet summary ────────────────────────────────────────────────

  WalletSummary buildWalletSummaryForMonth(
    String walletId,
    String walletName,
    List<TransactionModel> allTransactions,
    List<TransactionModel> monthTransactions,
    DateTime monthStart,
  ) {
    final openingBalance = computeWalletBalanceUpTo(
      walletId,
      allTransactions,
      monthStart.subtract(const Duration(milliseconds: 1)),
    );

    int inflowPaise = 0;
    int outflowPaise = 0;

    for (final t in monthTransactions) {
      final c = _contributionPaise(walletId, t);
      if (c > 0) {
        inflowPaise += c;
      } else {
        outflowPaise += c.abs();
      }
    }

    return WalletSummary(
      walletId: walletId,
      walletName: walletName,
      balance: round2(openingBalance +
          _fromPaise(inflowPaise) -
          _fromPaise(outflowPaise)),
      totalInflow: _fromPaise(inflowPaise),
      totalOutflow: _fromPaise(outflowPaise),
    );
  }

  // ── Aggregates ─────────────────────────────────────────────────────────────

  double totalIncome(List<TransactionModel> transactions) =>
      _fromPaise(transactions
          .where((t) => t.type == TransactionType.income)
          .fold(0, (s, t) => s + _toPaise(t.amount)));

  double totalExpense(List<TransactionModel> transactions) =>
      _fromPaise(transactions
          .where((t) => t.type == TransactionType.expense)
          .fold(0, (s, t) => s + _toPaise(t.amount)));

  double totalSavings(List<TransactionModel> transactions) =>
      _fromPaise(transactions
          .where((t) => t.type == TransactionType.savings)
          .fold(0, (s, t) => s + _toPaise(t.amount)));

  double totalTransfer(List<TransactionModel> transactions) =>
      _fromPaise(transactions
          .where((t) => t.type == TransactionType.transfer)
          .fold(0, (s, t) => s + _toPaise(t.amount)));

  double netForMonth(List<TransactionModel> transactions) =>
      round2(totalIncome(transactions) - totalExpense(transactions));
}