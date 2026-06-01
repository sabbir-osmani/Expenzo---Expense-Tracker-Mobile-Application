import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/wallet_constants.dart';
import '../../../../core/extensions/double_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../providers/wallet_provider.dart';

class WalletRow extends ConsumerWidget {
  const WalletRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(walletBalancesProvider);

    return SizedBox(
      height: 130,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: summaries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final summary = summaries[i];
          return WalletCard(
            walletId: summary.walletId,
            name: summary.walletName,
            balance: summary.balance,
          );
        },
      ),
    );
  }
}

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.walletId,
    required this.name,
    required this.balance,
  });

  final String walletId;
  final String name;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return GestureDetector(
      onTap: () {
        if (walletId == WalletConstants.savingsWalletId) {
          context.push('/savings');
        }
      },
      child: Container(
        width: 165,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(_icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FittedBox scales the text down if it doesn't fit.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    balance.toCurrency,
                    style: AppTextStyles.amountMedium.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Balance',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _color {
    switch (walletId) {
      case WalletConstants.cashWalletId:
        return AppColors.cashWallet;
      case WalletConstants.bkashWalletId:
        return AppColors.bkashWallet;
      case WalletConstants.savingsWalletId:
        return AppColors.savingsWallet;
      default:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (walletId) {
      case WalletConstants.cashWalletId:
        return Icons.payments_outlined;
      case WalletConstants.bkashWalletId:
        return Icons.phone_android_outlined;
      case WalletConstants.savingsWalletId:
        return Icons.account_balance_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}