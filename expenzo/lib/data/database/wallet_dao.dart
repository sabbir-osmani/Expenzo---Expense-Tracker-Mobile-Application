import 'package:sqflite/sqflite.dart';
import '../models/wallet_model.dart';

class WalletDao {
  const WalletDao(this._db);

  final Database _db;

  Future<List<WalletModel>> getAll() async {
    final maps = await _db.query(WalletModel.tableName);
    return maps.map(WalletModel.fromMap).toList();
  }

  Future<WalletModel?> getById(String id) async {
    final maps = await _db.query(
      WalletModel.tableName,
      where: '${WalletModel.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WalletModel.fromMap(maps.first);
  }

  Future<void> insert(WalletModel wallet) async {
    await _db.insert(
      WalletModel.tableName,
      wallet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(WalletModel wallet) async {
    await _db.update(
      WalletModel.tableName,
      wallet.toMap(),
      where: '${WalletModel.colId} = ?',
      whereArgs: [wallet.id],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete(WalletModel.tableName);
  }

  Future<void> insertBatch(List<WalletModel> wallets) async {
    final batch = _db.batch();
    for (final w in wallets) {
      batch.insert(
        WalletModel.tableName,
        w.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}