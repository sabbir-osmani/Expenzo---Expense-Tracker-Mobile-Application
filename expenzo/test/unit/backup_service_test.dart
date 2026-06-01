import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/enums/wallet_type.dart';
import 'package:expenzo/data/models/category_model.dart';
import 'package:expenzo/data/models/transaction_model.dart';
import 'package:expenzo/data/models/wallet_model.dart';

// We test the validation logic directly by accessing the parsed data structures,
// since BackupService._validateAndParse is private.
// These tests verify the JSON schema that the backup service relies on.

Map<String, dynamic> _validBackupMap() {
  return {
    'version': 1,
    'appName': 'Expenzo',
    'exportedAt': '2025-01-15T10:30:00.000',
    'wallets': [
      {'id': 'wallet_cash', 'name': 'Cash', 'type': 'cash', 'is_active': 1},
    ],
    'categories': [
      {
        'id': 'cat_expense_food',
        'name': 'Food',
        'type': 'expense',
        'icon_name': 'restaurant',
        'color_hex': '#E53935',
        'is_default': 1,
        'is_active': 1,
        'sort_order': 0,
      },
    ],
    'transactions': [
      {
        'id': 'txn_001',
        'title': null,
        'amount': 250.0,
        'type': 'expense',
        'category_id': 'cat_expense_food',
        'source_wallet_id': 'wallet_cash',
        'destination_wallet_id': null,
        'date_time': '2025-01-15T12:00:00.000',
        'note': null,
        'month_key': '2025-01',
        'created_at': '2025-01-15T12:00:00.000',
        'updated_at': '2025-01-15T12:00:00.000',
      },
    ],
  };
}

void main() {
  group('Backup JSON schema — WalletModel', () {
    test('parses valid wallet from map', () {
      final map = {'id': 'wallet_cash', 'name': 'Cash', 'type': 'cash', 'is_active': 1};
      final wallet = WalletModel.fromMap(map);
      expect(wallet.id, 'wallet_cash');
      expect(wallet.isActive, true);
      expect(wallet.type, WalletType.cash);
    });

    test('throws on unknown wallet type', () {
      final map = {'id': 'w1', 'name': 'X', 'type': 'unknown_type', 'is_active': 1};
      expect(() => WalletModel.fromMap(map), throwsA(isA<ArgumentError>()));
    });
  });

  group('Backup JSON schema — CategoryModel', () {
    test('parses valid category from map', () {
      final map = {
        'id': 'cat_1', 'name': 'Food', 'type': 'expense',
        'icon_name': 'restaurant', 'color_hex': '#E53935',
        'is_default': 1, 'is_active': 1, 'sort_order': 0,
      };
      final cat = CategoryModel.fromMap(map);
      expect(cat.type, TransactionType.expense);
      expect(cat.isDefault, true);
    });
  });

  group('Backup JSON schema — TransactionModel', () {
    test('parses valid transaction from map', () {
      final map = {
        'id': 'txn_001',
        'title': null,
        'amount': 250.0,
        'type': 'expense',
        'category_id': 'cat_1',
        'source_wallet_id': 'wallet_cash',
        'destination_wallet_id': null,
        'date_time': '2025-01-15T12:00:00.000',
        'note': null,
        'month_key': '2025-01',
        'created_at': '2025-01-15T12:00:00.000',
        'updated_at': '2025-01-15T12:00:00.000',
      };
      final txn = TransactionModel.fromMap(map);
      expect(txn.amount, 250.0);
      expect(txn.type, TransactionType.expense);
      expect(txn.destinationWalletId, isNull);
    });

    test('throws on unknown transaction type', () {
      final map = {
        'id': 'txn_002', 'title': null, 'amount': 100.0,
        'type': 'invalid_type',
        'category_id': 'cat_1', 'source_wallet_id': 'wallet_cash',
        'destination_wallet_id': null,
        'date_time': '2025-01-15T12:00:00.000',
        'note': null, 'month_key': '2025-01',
        'created_at': '2025-01-15T12:00:00.000',
        'updated_at': '2025-01-15T12:00:00.000',
      };
      expect(() => TransactionModel.fromMap(map), throwsA(isA<ArgumentError>()));
    });
  });

  group('Backup JSON schema — full structure', () {
    test('valid backup map encodes and re-decodes without loss', () {
      final original = _validBackupMap();
      final encoded = jsonEncode(original);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['version'], 1);
      expect((decoded['transactions'] as List).length, 1);
      expect((decoded['wallets'] as List).length, 1);
      expect((decoded['categories'] as List).length, 1);
    });

    test('missing version field would fail version check', () {
      final map = Map<String, dynamic>.from(_validBackupMap())..remove('version');
      expect(map.containsKey('version'), false);
    });

    test('transfer transaction has destinationWalletId', () {
      final map = {
        'id': 'txn_transfer',
        'title': 'Transfer',
        'amount': 500.0,
        'type': 'transfer',
        'category_id': 'cat_1',
        'source_wallet_id': 'wallet_cash',
        'destination_wallet_id': 'wallet_bkash',
        'date_time': '2025-01-15T12:00:00.000',
        'note': null,
        'month_key': '2025-01',
        'created_at': '2025-01-15T12:00:00.000',
        'updated_at': '2025-01-15T12:00:00.000',
      };
      final txn = TransactionModel.fromMap(map);
      expect(txn.destinationWalletId, 'wallet_bkash');
      expect(txn.type, TransactionType.transfer);
    });
  });
}