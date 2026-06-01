import '../database/wallet_dao.dart';
import '../models/wallet_model.dart';

class WalletRepository {
  const WalletRepository(this._dao);

  final WalletDao _dao;

  Future<List<WalletModel>> getAll() => _dao.getAll();

  Future<WalletModel?> getById(String id) => _dao.getById(id);

  Future<void> add(WalletModel wallet) => _dao.insert(wallet);

  Future<void> update(WalletModel wallet) => _dao.update(wallet);

  Future<void> deleteAll() => _dao.deleteAll();

  Future<void> replaceAll(List<WalletModel> wallets) async {
    await _dao.deleteAll();
    if (wallets.isNotEmpty) {
      await _dao.insertBatch(wallets);
    }
  }
}