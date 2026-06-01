import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/double_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/summary_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/month_navigator.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Analytics', style: AppTextStyles.headlineSmall),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              const MonthNavigator(),
              TabBar(
                controller: _tabController,
                tabs: const [Tab(text: 'Expenses'), Tab(text: 'Income')],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BreakdownTab(
            isExpense: true,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
          _BreakdownTab(
            isExpense: false,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
        ],
      ),
    );
  }
}

class _BreakdownTab extends ConsumerWidget {
  const _BreakdownTab({
    required this.isExpense,
    required this.touchedIndex,
    required this.onTouch,
  });
  final bool isExpense;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = isExpense
        ? ref.watch(expenseBreakdownProvider)
        : ref.watch(incomeBreakdownProvider);
    final trendData = ref.watch(trendDataProvider);

    if (breakdown.isEmpty) {
      return EmptyState(
        message: 'No ${isExpense ? 'expense' : 'income'} data',
        subtitle: 'Add some transactions to see your breakdown',
        icon: Icons.pie_chart_outline,
      );
    }

    final total = breakdown.fold(0.0, (s, b) => s + b.total);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Pie chart with distinct palette colors.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text('Total: ${total.toCurrency}',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (response?.touchedSection != null) {
                          onTouch(response!
                              .touchedSection!.touchedSectionIndex);
                        } else {
                          onTouch(-1);
                        }
                      },
                    ),
                    sections: breakdown.asMap().entries.map((entry) {
                      final i = entry.key;
                      final b = entry.value;
                      final isTouched = i == touchedIndex;
                      // ← Distinct palette color, not category color.
                      final sectionColor = AppColors
                          .chartPalette[i % AppColors.chartPalette.length];
                      return PieChartSectionData(
                        value: b.total,
                        color: sectionColor,
                        radius: isTouched ? 72 : 58,
                        title: isTouched ? '${b.percentage}%' : '',
                        titleStyle: AppTextStyles.labelMedium
                            .copyWith(color: Colors.white),
                      );
                    }).toList(),
                    centerSpaceRadius: 48,
                    sectionsSpace: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 6-month trend bar chart.
        if (trendData.isNotEmpty) ...[
          Text('6-Month Trend', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: trendData
                        .map((t) =>
                            isExpense ? t.expense : t.income)
                        .fold(0.0, (a, b) => a > b ? a : b) *
                    1.2,
                barGroups: trendData.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: isExpense ? t.expense : t.income,
                        color: isExpense
                            ? AppColors.expense
                            : AppColors.income,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < trendData.length) {
                          final parts =
                              trendData[idx].monthKey.split('-');
                          const months = [
                            '', 'Jan', 'Feb', 'Mar', 'Apr', 'May',
                            'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
                            'Dec'
                          ];
                          final m = int.tryParse(parts[1]) ?? 0;
                          return Text(months[m],
                              style: AppTextStyles.labelSmall);
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Category breakdown list with palette colors matching pie.
        Text('Breakdown', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        ...breakdown.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CategoryRow(
              breakdown: entry.value,
              total: total,
              // ← Same palette index so list matches pie slice color.
              paletteIndex: entry.key,
            ),
          );
        }),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.breakdown,
    required this.total,
    required this.paletteIndex,
  });
  final dynamic breakdown;
  final double total;
  final int paletteIndex;

  @override
  Widget build(BuildContext context) {
    // Uses palette color so list and pie chart are consistent.
    final color = AppColors.chartPalette[
        paletteIndex % AppColors.chartPalette.length];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(breakdown.categoryName as String,
                    style: AppTextStyles.bodyMedium),
              ),
              Text((breakdown.total as double).toCurrency,
                  style: AppTextStyles.amountSmall),
              const SizedBox(width: 8),
              Text(
                '${breakdown.percentage}%',
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0
                  ? (breakdown.total as double) / total
                  : 0,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}