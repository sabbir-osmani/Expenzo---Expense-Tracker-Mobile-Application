import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/database/category_dao.dart';
import '../../data/database/transaction_dao.dart';
import '../../data/database/wallet_dao.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../domain/services/backup_service.dart';
import '../../domain/services/balance_service.dart';
import '../../domain/services/category_service.dart';
import '../../domain/services/summary_service.dart';
import '../../domain/services/transfer_service.dart';

// ── Database (overridden at startup in main.dart) ──────────────────────────

final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError('databaseProvider not initialised'),
);

// ── Repositories ───────────────────────────────────────────────────────────

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepository(TransactionDao(db.db));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(CategoryDao(db.db));
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WalletRepository(WalletDao(db.db));
});

// ── Services ───────────────────────────────────────────────────────────────

final balanceServiceProvider = Provider<BalanceService>(
  (_) => const BalanceService(),
);

final transferServiceProvider = Provider<TransferService>(
  (_) => const TransferService(),
);

final summaryServiceProvider = Provider<SummaryService>((ref) {
  return SummaryService(ref.watch(balanceServiceProvider));
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(ref.watch(categoryRepositoryProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    walletRepository: ref.watch(walletRepositoryProvider),
  );
});