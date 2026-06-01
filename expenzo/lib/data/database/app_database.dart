import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/category_defaults.dart';
import '../../core/constants/wallet_constants.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/enums/wallet_type.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  Database get db => _db;

  static Future<AppDatabase> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );

    return AppDatabase._(db);
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Create tables.
    batch.execute(WalletModel.createTableSql);
    batch.execute(CategoryModel.createTableSql);
    batch.execute(TransactionModel.createTableSql);

    // Indices.
    batch.execute(
      'CREATE INDEX idx_transactions_month_key '
      'ON ${TransactionModel.tableName} (${TransactionModel.colMonthKey})',
    );
    batch.execute(
      'CREATE INDEX idx_transactions_datetime '
      'ON ${TransactionModel.tableName} (${TransactionModel.colDateTime})',
    );
    batch.execute(
      'CREATE INDEX idx_transactions_source_wallet '
      'ON ${TransactionModel.tableName} (${TransactionModel.colSourceWalletId})',
    );

    await batch.commit(noResult: true);

    await _seedWallets(db);
    await _seedCategories(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Guard future migrations with version checks.
    // if (oldVersion < 2) { ... }
  }

  static Future<void> _seedWallets(Database db) async {
    final wallets = [
      WalletModel(
        id: WalletConstants.cashWalletId,
        name: WalletConstants.cashWalletName,
        type: WalletType.cash,
        isActive: true,
      ),
      WalletModel(
        id: WalletConstants.bkashWalletId,
        name: WalletConstants.bkashWalletName,
        type: WalletType.mobileBanking,
        isActive: true,
      ),
      WalletModel(
        id: WalletConstants.savingsWalletId,
        name: WalletConstants.savingsWalletName,
        type: WalletType.savings,
        isActive: true,
      ),
    ];

    final batch = db.batch();
    for (final w in wallets) {
      batch.insert(WalletModel.tableName, w.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _seedCategories(Database db) async {
    final batch = db.batch();

    // Seed all default user-facing categories.
    for (final c in CategoryDefaults.all) {
      final model = CategoryModel(
        id: c.id,
        name: c.name,
        type: c.type,
        iconName: c.iconName,
        colorHex: c.colorHex,
        isDefault: true,
        isActive: true,
        sortOrder: c.sortOrder,
      );
      batch.insert(CategoryModel.tableName, model.toMap());
    }

    // Seed the internal transfer category used by the transfer screen.
    // This is not user-facing — it's hidden from category pickers.
    batch.insert(
      CategoryModel.tableName,
      const CategoryModel(
        id: 'cat_transfer_internal',
        name: 'Transfer',
        type: TransactionType.transfer,
        iconName: 'swap_horiz',
        colorHex: '#1E88E5',
        isDefault: true,
        isActive: true,
        sortOrder: 0,
      ).toMap(),
    );

    await batch.commit(noResult: true);
  }

  Future<void> close() => _db.close();
}