class AppConstants {
  AppConstants._();

  static const String appName = 'Expenzo';
  static const String appVersion = '1.0.0';
  static const int backupVersion = 1;

  static const String dbName = 'expenzo.db';
  static const int dbVersion = 1;

  static const String currencySymbol = '৳';
  static const String currencyCode = 'BDT';

  static const int maxNoteLength = 300;
  static const int maxTitleLength = 60;
  static const double maxTransactionAmount = 9999999.99;
  static const int recentTransactionCount = 5;

  static const String backupFilePrefix = 'expenzo_backup';
  static const String backupFileExtension = 'json';
}