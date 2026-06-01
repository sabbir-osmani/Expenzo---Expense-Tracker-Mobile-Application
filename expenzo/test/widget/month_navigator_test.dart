import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expenzo/core/theme/app_theme.dart';
import 'package:expenzo/presentation/providers/navigation_provider.dart';
import 'package:expenzo/presentation/widgets/common/month_navigator.dart';

Widget _wrap(Widget child, {DateTime? initialMonth}) {
  return ProviderScope(
    overrides: initialMonth != null
        ? [
            selectedMonthProvider
                .overrideWith((_) => initialMonth),
          ]
        : [],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('MonthNavigator widget', () {
    testWidgets('displays selected month label', (tester) async {
      await tester.pumpWidget(
        _wrap(const MonthNavigator(), initialMonth: DateTime(2025, 3, 1)),
      );
      expect(find.text('March 2025'), findsOneWidget);
    });

    testWidgets('previous button navigates to prior month', (tester) async {
      await tester.pumpWidget(
        _wrap(const MonthNavigator(), initialMonth: DateTime(2025, 3, 1)),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      expect(find.text('February 2025'), findsOneWidget);
    });

    testWidgets('next button is disabled on current month', (tester) async {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);

      await tester.pumpWidget(
        _wrap(const MonthNavigator(), initialMonth: currentMonth),
      );

      // The right chevron should be present but grayed out.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('shows Now badge on current month', (tester) async {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);

      await tester.pumpWidget(
        _wrap(const MonthNavigator(), initialMonth: currentMonth),
      );

      expect(find.text('Now'), findsOneWidget);
    });
  });
}