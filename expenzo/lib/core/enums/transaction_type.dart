enum TransactionType {
  income,
  expense,
  transfer,
  savings;

  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.savings:
        return 'Savings';
    }
  }

  String get dbValue => name;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown TransactionType: $value'),
    );
  }

  bool get isTransfer =>
      this == TransactionType.transfer || this == TransactionType.savings;

  bool get affectsTwoWallets => isTransfer;
}