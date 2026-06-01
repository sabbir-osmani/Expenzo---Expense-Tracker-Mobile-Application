import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';

class BackupData {
  const BackupData({
    required this.transactions,
    required this.categories,
    required this.wallets,
  });

  final List<TransactionModel> transactions;
  final List<CategoryModel> categories;
  final List<WalletModel> wallets;
}

class BackupService {
  const BackupService({
    required TransactionRepository transactionRepository,
    required CategoryRepository categoryRepository,
    required WalletRepository walletRepository,
  })  : _transactionRepo = transactionRepository,
        _categoryRepo = categoryRepository,
        _walletRepo = walletRepository;

  final TransactionRepository _transactionRepo;
  final CategoryRepository _categoryRepo;
  final WalletRepository _walletRepo;

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Creates a backup JSON file and shares it via the system share sheet.
  Future<String> exportBackup() async {
    try {
      final transactions = await _transactionRepo.getAll();
      final categories = await _categoryRepo.getAll();
      final wallets = await _walletRepo.getAll();

      final backupMap = {
        'version': AppConstants.backupVersion,
        'appName': AppConstants.appName,
        'exportedAt': DateTime.now().toIso8601String(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'wallets': wallets.map((w) => w.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupMap);
      final filePath = await _writeBackupFile(jsonString);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '${AppConstants.appName} Backup',
      );

      return filePath;
    } on AppException {
      rethrow;
    } catch (e) {
      throw BackupExportException('Export failed: ${e.toString()}');
    }
  }

  Future<String> _writeBackupFile(String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final fileName =
        '${AppConstants.backupFilePrefix}_$timestamp.${AppConstants.backupFileExtension}';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  // ── Import / Restore ───────────────────────────────────────────────────────

  /// Reads a JSON backup file at [filePath] and fully restores the database.
  ///
  /// Throws typed exceptions on any failure.
  /// Uses a replace-all strategy: existing data is cleared only after
  /// successful validation.
  Future<void> importBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const BackupImportException('Backup file not found.');
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        throw const CorruptedBackupException('Backup file is empty.');
      }

      late Map<String, dynamic> backupMap;
      try {
        backupMap = json.decode(content) as Map<String, dynamic>;
      } catch (_) {
        throw const CorruptedBackupException('Backup file contains invalid JSON.');
      }

      final parsed = _validateAndParse(backupMap);

      // Only clear data after successful parse.
      await _transactionRepo.replaceAll(parsed.transactions);
      await _categoryRepo.replaceAll(parsed.categories);
      await _walletRepo.replaceAll(parsed.wallets);
    } on AppException {
      rethrow;
    } catch (e) {
      throw BackupImportException('Restore failed: ${e.toString()}');
    }
  }

  BackupData _validateAndParse(Map<String, dynamic> map) {
    // Version check.
    final version = map['version'];
    if (version == null) {
      throw const CorruptedBackupException('Missing version field.');
    }
    if (version is! int || version > AppConstants.backupVersion) {
      throw UnsupportedBackupVersionException(version is int ? version : -1);
    }

    // Wallets.
    final rawWallets = map['wallets'];
    if (rawWallets is! List) {
      throw const CorruptedBackupException('Invalid wallets field.');
    }
    final wallets = <WalletModel>[];
    for (final item in rawWallets) {
      if (item is! Map<String, dynamic>) {
        throw const CorruptedBackupException('Malformed wallet entry.');
      }
      try {
        wallets.add(WalletModel.fromJson(item));
      } catch (_) {
        throw const CorruptedBackupException('Failed to parse wallet entry.');
      }
    }

    // Categories.
    final rawCategories = map['categories'];
    if (rawCategories is! List) {
      throw const CorruptedBackupException('Invalid categories field.');
    }
    final categories = <CategoryModel>[];
    for (final item in rawCategories) {
      if (item is! Map<String, dynamic>) {
        throw const CorruptedBackupException('Malformed category entry.');
      }
      try {
        categories.add(CategoryModel.fromJson(item));
      } catch (_) {
        throw const CorruptedBackupException('Failed to parse category entry.');
      }
    }

    // Transactions.
    final rawTransactions = map['transactions'];
    if (rawTransactions is! List) {
      throw const CorruptedBackupException('Invalid transactions field.');
    }
    final transactions = <TransactionModel>[];
    final walletIds = wallets.map((w) => w.id).toSet();

    for (final item in rawTransactions) {
      if (item is! Map<String, dynamic>) {
        throw const CorruptedBackupException('Malformed transaction entry.');
      }
      try {
        final t = TransactionModel.fromJson(item);
        // Validate wallet references.
        if (!walletIds.contains(t.sourceWalletId)) {
          throw CorruptedBackupException(
            'Transaction ${t.id} references unknown wallet ${t.sourceWalletId}.',
          );
        }
        if (t.destinationWalletId != null &&
            !walletIds.contains(t.destinationWalletId)) {
          throw CorruptedBackupException(
            'Transaction ${t.id} references unknown destination wallet.',
          );
        }
        // Validate amount.
        if (t.amount <= 0) {
          throw CorruptedBackupException(
            'Transaction ${t.id} has invalid amount ${t.amount}.',
          );
        }
        transactions.add(t);
      } on AppException {
        rethrow;
      } catch (_) {
        throw const CorruptedBackupException('Failed to parse transaction entry.');
      }
    }

    return BackupData(
      transactions: transactions,
      categories: categories,
      wallets: wallets,
    );
  }
}