import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';

class TransactionDao {
  const TransactionDao(this._db);

  final Database _db;

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> insert(TransactionModel transaction) async {
    await _db.insert(
      TransactionModel.tableName,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(TransactionModel transaction) async {
    await _db.update(
      TransactionModel.tableName,
      transaction.toMap(),
      where: '${TransactionModel.colId} = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> delete(String id) async {
    await _db.delete(
      TransactionModel.tableName,
      where: '${TransactionModel.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete(TransactionModel.tableName);
  }

  Future<void> insertBatch(List<TransactionModel> transactions) async {
    final batch = _db.batch();
    for (final t in transactions) {
      batch.insert(
        TransactionModel.tableName,
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<TransactionModel?> getById(String id) async {
    final maps = await _db.query(
      TransactionModel.tableName,
      where: '${TransactionModel.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  Future<List<TransactionModel>> getAll() async {
    final maps = await _db.query(
      TransactionModel.tableName,
      orderBy: '${TransactionModel.colDateTime} DESC',
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getByMonthKey(String monthKey) async {
    final maps = await _db.query(
      TransactionModel.tableName,
      where: '${TransactionModel.colMonthKey} = ?',
      whereArgs: [monthKey],
      orderBy: '${TransactionModel.colDateTime} DESC',
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  /// Returns all transactions from the beginning up to and including
  /// [upToDateTime]. Used for computing opening balances.
  Future<List<TransactionModel>> getAllUpTo(DateTime upToDateTime) async {
    final maps = await _db.query(
      TransactionModel.tableName,
      where: '${TransactionModel.colDateTime} <= ?',
      whereArgs: [upToDateTime.toIso8601String()],
      orderBy: '${TransactionModel.colDateTime} ASC',
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> search({
    String? query,
    String? categoryId,
    String? walletId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    String? monthKey,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (monthKey != null) {
      conditions.add('${TransactionModel.colMonthKey} = ?');
      args.add(monthKey);
    }

    if (query != null && query.trim().isNotEmpty) {
      conditions.add(
        '(${TransactionModel.colTitle} LIKE ? OR ${TransactionModel.colNote} LIKE ?)',
      );
      final pattern = '%${query.trim()}%';
      args.addAll([pattern, pattern]);
    }

    if (categoryId != null) {
      conditions.add('${TransactionModel.colCategoryId} = ?');
      args.add(categoryId);
    }

    if (walletId != null) {
      conditions.add(
        '(${TransactionModel.colSourceWalletId} = ? OR '
        '${TransactionModel.colDestinationWalletId} = ?)',
      );
      args.addAll([walletId, walletId]);
    }

    if (type != null) {
      conditions.add('${TransactionModel.colType} = ?');
      args.add(type);
    }

    if (fromDate != null) {
      conditions.add('${TransactionModel.colDateTime} >= ?');
      args.add(fromDate.toIso8601String());
    }

    if (toDate != null) {
      conditions.add('${TransactionModel.colDateTime} <= ?');
      args.add(toDate.toIso8601String());
    }

    final whereClause =
        conditions.isEmpty ? null : conditions.join(' AND ');

    final maps = await _db.query(
      TransactionModel.tableName,
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: '${TransactionModel.colDateTime} DESC',
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<List<String>> getDistinctMonthKeys() async {
    final maps = await _db.rawQuery(
      'SELECT DISTINCT ${TransactionModel.colMonthKey} '
      'FROM ${TransactionModel.tableName} '
      'ORDER BY ${TransactionModel.colMonthKey} DESC',
    );
    return maps
        .map((m) => m[TransactionModel.colMonthKey] as String)
        .toList();
  }

  Future<int> getCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${TransactionModel.tableName}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}