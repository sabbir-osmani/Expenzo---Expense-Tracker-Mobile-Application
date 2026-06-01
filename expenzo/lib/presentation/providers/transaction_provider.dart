import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/transaction_model.dart';
import 'core_providers.dart';
import 'navigation_provider.dart';

class TransactionNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() =>
      ref.read(transactionRepositoryProvider).getAll();

  Future<void> add(TransactionModel transaction) async {
    await ref.read(transactionRepositoryProvider).add(transaction);
    final current = state.valueOrNull ?? [];
    final updated = [...current, transaction]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    state = AsyncData(updated);
  }

  Future<void> editTransaction(TransactionModel transaction) async {
    await ref.read(transactionRepositoryProvider).update(transaction);
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((t) => t.id == transaction.id);
    if (idx == -1) {
      ref.invalidateSelf();
      return;
    }
    final updated = [...current];
    updated[idx] = transaction;
    updated.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    state = AsyncData(updated);
  }

  Future<void> delete(String id) async {
    await ref.read(transactionRepositoryProvider).delete(id);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((t) => t.id != id).toList());
  }

  Future<void> clearAll() async {
    await ref.read(transactionRepositoryProvider).deleteAll();
    state = const AsyncData([]);
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, List<TransactionModel>>(
  TransactionNotifier.new,
);

final allTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  return ref
      .watch(transactionNotifierProvider)
      .maybeWhen(data: (list) => list, orElse: () => const []);
});

final monthTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final monthKey = DateFormat('yyyy-MM').format(selectedMonth);
  return ref
      .watch(allTransactionsProvider)
      .where((t) => t.monthKey == monthKey)
      .toList();
});

final recentTransactionsProvider =
    Provider.family<List<TransactionModel>, int>((ref, count) {
  return ref.watch(allTransactionsProvider).take(count).toList();
});

final availableMonthKeysProvider = Provider<List<String>>((ref) {
  final keys =
      ref.watch(allTransactionsProvider).map((t) => t.monthKey).toSet().toList()
        ..sort();
  return keys.reversed.toList();
});