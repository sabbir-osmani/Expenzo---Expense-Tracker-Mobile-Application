import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expenzo/core/enums/transaction_type.dart';
import 'package:expenzo/core/enums/wallet_type.dart';
import 'package:expenzo/core/constants/wallet_constants.dart';
import 'package:expenzo/core/theme/app_theme.dart';
import 'package:expenzo/data/models/category_model.dart';
import 'package:expenzo/data/models/transaction_model.dart';
import 'package:expenzo/data/models/wallet_model.dart';
import 'package:expenzo/presentation/providers/category_provider.dart';
import 'package:expenzo/presentation/providers/wallet_provider.dart';
import 'package:expenzo/presentation/providers/transaction_provider.dart';
import 'package:expenzo/presentation/screens/transaction/add_transaction_screen.dart';

void main() {
  group('AddTransactionScreen — smoke test', () {
    testWidgets('Save button is present', (tester) async {
      const categories = [
        CategoryModel(
          id: 'cat_expense_food',
          name: 'Food',
          type: TransactionType.expense,
          iconName: 'restaurant',
          colorHex: '#E53935',
          isDefault: true,
          isActive: true,
          sortOrder: 0,
        ),
      ];
      const wallets = [
        WalletModel(
          id: WalletConstants.cashWalletId,
          name: 'Cash',
          type: WalletType.cash,
          isActive: true,
        ),
        WalletModel(
          id: WalletConstants.bkashWalletId,
          name: 'bKash',
          type: WalletType.mobileBanking,
          isActive: true,
        ),
        WalletModel(
          id: WalletConstants.savingsWalletId,
          name: 'Savings',
          type: WalletType.savings,
          isActive: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryNotifierProvider.overrideWith(
              () => _FakeCategoryNotifier(categories),
            ),
            walletNotifierProvider.overrideWith(
              () => _FakeWalletNotifier(wallets),
            ),
            transactionNotifierProvider.overrideWith(
              () => _FakeTransactionNotifier(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AddTransactionScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Save Transaction'), findsOneWidget);
    });
  });
}

class _FakeCategoryNotifier extends CategoryNotifier {
  _FakeCategoryNotifier(this._cats);
  final List<CategoryModel> _cats;
  @override
  Future<List<CategoryModel>> build() async => _cats;
}

class _FakeWalletNotifier extends WalletNotifier {
  _FakeWalletNotifier(this._wallets);
  final List<WalletModel> _wallets;
  @override
  Future<List<WalletModel>> build() async => _wallets;
}

class _FakeTransactionNotifier extends TransactionNotifier {
  @override
  Future<List<TransactionModel>> build() async => const [];
}