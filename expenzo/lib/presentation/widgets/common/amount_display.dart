import 'package:flutter/material.dart';

import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum AmountSize { large, medium, small }

class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.amount,
    required this.isIncome,
    this.size = AmountSize.medium,
    this.showSign = true,
    this.isTransfer = false,
    this.isSavings = false,
  });

  final double amount;
  final bool isIncome;
  final AmountSize size;
  final bool showSign;
  final bool isTransfer;
  final bool isSavings;

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final style = _style;
    final sign = showSign ? (isIncome ? '+' : '-') : '';

    return Text(
      '$sign${amount.toCurrency}',
      style: style.copyWith(color: color),
    );
  }

  Color get _color {
    if (isTransfer) return AppColors.transfer;
    if (isSavings) return AppColors.savings;
    return isIncome ? AppColors.income : AppColors.expense;
  }

  TextStyle get _style {
    switch (size) {
      case AmountSize.large:
        return AppTextStyles.amountLarge;
      case AmountSize.medium:
        return AppTextStyles.amountMedium;
      case AmountSize.small:
        return AppTextStyles.amountSmall;
    }
  }
}