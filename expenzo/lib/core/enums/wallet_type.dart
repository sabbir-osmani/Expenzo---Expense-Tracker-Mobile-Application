enum WalletType {
  cash,
  mobileBanking,
  savings;

  String get label {
    switch (this) {
      case WalletType.cash:
        return 'Cash';
      case WalletType.mobileBanking:
        return 'Mobile Banking';
      case WalletType.savings:
        return 'Savings';
    }
  }

  String get dbValue => name;

  static WalletType fromString(String value) {
    return WalletType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown WalletType: $value'),
    );
  }
}