import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wallet_model.dart';
import '../../domain/entities/wallet_summary.dart';
import 'core_providers.dart';
import 'transaction_provider.dart';

// ── Notifier ───────────────────────────────────────────────────────────────

class WalletNotifier extends AsyncNotifier<List<WalletModel>> {
  @override
  Future<List<WalletModel>> build() {
    return ref.read(walletRepositoryProvider).getAll();
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final walletNotifierProvider =
    AsyncNotifierProvider<WalletNotifier, List<WalletModel>>(
  WalletNotifier.new,
);

// ── Derived ────────────────────────────────────────────────────────────────

final allWalletsProvider = Provider<List<WalletModel>>((ref) {
  return ref
      .watch(walletNotifierProvider)
      .maybeWhen(data: (list) => list, orElse: () => const []);
});

final activeWalletsProvider = Provider<List<WalletModel>>((ref) {
  return ref.watch(allWalletsProvider).where((w) => w.isActive).toList();
});

/// Current (live) wallet balances — computed from ALL transactions.
final walletBalancesProvider = Provider<List<WalletSummary>>((ref) {
  final wallets = ref.watch(activeWalletsProvider);
  final allTransactions = ref.watch(allTransactionsProvider);
  final balanceSvc = ref.watch(balanceServiceProvider);

  return wallets.map((w) {
    final balance = balanceSvc.computeWalletBalance(w.id, allTransactions);
    return WalletSummary(
      walletId: w.id,
      walletName: w.name,
      balance: balance,
      totalInflow: 0,
      totalOutflow: 0,
    );
  }).toList();
});

/// Quick map walletId → balance for efficient lookup.
final walletBalanceMapProvider = Provider<Map<String, double>>((ref) {
  final summaries = ref.watch(walletBalancesProvider);
  return {for (final s in summaries) s.walletId: s.balance};
});