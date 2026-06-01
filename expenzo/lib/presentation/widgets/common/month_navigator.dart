import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/datetime_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/navigation_provider.dart';

class MonthNavigator extends ConsumerWidget {
  const MonthNavigator({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth = selectedMonth.isSameMonth(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            onTap: () {
              ref.read(selectedMonthProvider.notifier).state =
                  selectedMonth.subtractMonths(1);
            },
          ),
          GestureDetector(
            onTap: () => _showMonthPicker(context, ref, selectedMonth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  compact
                      ? selectedMonth.shortMonthLabel
                      : selectedMonth.monthLabel,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isCurrentMonth) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Now',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right,
            onTap: isCurrentMonth
                ? null
                : () {
                    ref.read(selectedMonthProvider.notifier).state =
                        selectedMonth.addMonths(1);
                  },
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state =
          DateTime(picked.year, picked.month, 1);
    }
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.border : AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}