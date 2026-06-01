import '../database/transaction_dao.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  const TransactionRepository(this._dao);

  final TransactionDao _dao;

  Future<void> add(TransactionModel transaction) =>
      _dao.insert(transaction);

  Future<void> update(TransactionModel transaction) =>
      _dao.update(transaction);

  Future<void> delete(String id) => _dao.delete(id);

  Future<void> deleteAll() => _dao.deleteAll();

  Future<TransactionModel?> getById(String id) => _dao.getById(id);

  Future<List<TransactionModel>> getAll() => _dao.getAll();

  Future<List<TransactionModel>> getByMonthKey(String monthKey) =>
      _dao.getByMonthKey(monthKey);

  Future<List<TransactionModel>> getAllUpTo(DateTime upTo) =>
      _dao.getAllUpTo(upTo);

  Future<List<TransactionModel>> search({
    String? query,
    String? categoryId,
    String? walletId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    String? monthKey,
  }) =>
      _dao.search(
        query: query,
        categoryId: categoryId,
        walletId: walletId,
        type: type,
        fromDate: fromDate,
        toDate: toDate,
        monthKey: monthKey,
      );

  Future<List<String>> getDistinctMonthKeys() =>
      _dao.getDistinctMonthKeys();

  Future<int> getCount() => _dao.getCount();

  Future<void> replaceAll(List<TransactionModel> transactions) async {
    await _dao.deleteAll();
    if (transactions.isNotEmpty) {
      await _dao.insertBatch(transactions);
    }
  }
}