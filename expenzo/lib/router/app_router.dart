import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/analytics/analytics_screen.dart';
import '../presentation/screens/dashboard/dashboard_screen.dart';
import '../presentation/screens/history/history_screen.dart';
import '../presentation/screens/settings/backup_restore_screen.dart';
import '../presentation/screens/settings/manage_categories_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/transaction/add_transaction_screen.dart';
import '../presentation/screens/transaction/edit_transaction_screen.dart';
import '../presentation/screens/transfer/transfer_screen.dart';
import '../presentation/screens/savings/savings_screen.dart';
import '../presentation/screens/summary/monthly_summary_screen.dart';
import '../presentation/widgets/common/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  debugLogDiagnostics: false,
  routes: [
    // ── Splash ──────────────────────────────────────────────────────────
    GoRoute(
      path: '/splash',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const SplashScreen(),
    ),

    // ── Shell (bottom nav) ───────────────────────────────────────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (_, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (_, __) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'backup',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, __) => const BackupRestoreScreen(),
            ),
            GoRoute(
              path: 'categories',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, __) => const ManageCategoriesScreen(),
            ),
          ],
        ),
      ],
    ),

    // ── Full-screen routes (above shell) ─────────────────────────────────
    GoRoute(
      path: '/add-transaction',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const AddTransactionScreen(),
    ),
    GoRoute(
      path: '/edit-transaction/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) =>
          EditTransactionScreen(transactionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/transfer',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const TransferScreen(),
    ),
    GoRoute(
      path: '/savings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const SavingsScreen(),
    ),
    GoRoute(
      path: '/monthly-summary',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const MonthlySummaryScreen(),
    ),
  ],
);