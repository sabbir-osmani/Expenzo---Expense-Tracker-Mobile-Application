class WalletConstants {
  WalletConstants._();

  static const String cashWalletId = 'wallet_cash';
  static const String bkashWalletId = 'wallet_bkash';
  static const String savingsWalletId = 'wallet_savings';

  static const String cashWalletName = 'Cash';
  static const String bkashWalletName = 'bKash';
  static const String savingsWalletName = 'Savings';

  static const List<String> defaultWalletIds = [
    cashWalletId,
    bkashWalletId,
    savingsWalletId,
  ];
}