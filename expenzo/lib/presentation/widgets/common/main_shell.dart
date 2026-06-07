import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/navigation_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard,
        label: 'Home',      path: '/dashboard'),
    _TabItem(icon: Icons.history_outlined,   activeIcon: Icons.history,
        label: 'History',   path: '/history'),
    _TabItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart,
        label: 'Analytics', path: '/analytics'),
    _TabItem(icon: Icons.settings_outlined,  activeIcon: Icons.settings,
        label: 'Settings',  path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabIndexProvider);

    return Scaffold(
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _AddFab(),
      bottomNavigationBar: _CurvedBar(
        currentIndex: currentIndex,
        onTap: (i) {
          HapticFeedback.lightImpact();
          ref.read(currentTabIndexProvider.notifier).state = i;
          context.go(_tabs[i].path);
        },
      ),
    );
  }
}

// ── Curved bottom bar ─────────────────────────────────────────────────────────

class _CurvedBar extends StatelessWidget {
  const _CurvedBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.surface,
      elevation: 10,
      child: SizedBox(
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Left two tabs.
            _NavItem(tab: MainShell._tabs[0], isActive: currentIndex == 0,
                onTap: () => onTap(0)),
            _NavItem(tab: MainShell._tabs[1], isActive: currentIndex == 1,
                onTap: () => onTap(1)),
            // Centre spacer for FAB.
            const SizedBox(width: 60),
            // Right two tabs.
            _NavItem(tab: MainShell._tabs[2], isActive: currentIndex == 2,
                onTap: () => onTap(2)),
            _NavItem(tab: MainShell._tabs[3], isActive: currentIndex == 3,
                onTap: () => onTap(3)),
          ],
        ),
      ),
    );
  }
}

// ── FAB — sits in the notch, never overlaps content ──────────────────────────

class _AddFab extends StatefulWidget {
  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FloatingActionButton.large sits in CircularNotchedRectangle.
    // Modal bottom sheets render on top of FAB automatically — no overlap issue.
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        HapticFeedback.mediumImpact();
        context.push('/add-transaction');
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.40),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });
  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? tab.activeIcon : tab.icon,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? AppColors.primary : AppColors.textTertiary,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}