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
      // Curved notch FAB bar — no FAB in DashboardScreen.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _AddFab(),
      bottomNavigationBar: _CurvedBottomBar(
        currentIndex: currentIndex,
        tabs: _tabs,
        onTap: (i, path, ref) {
          ref.read(currentTabIndexProvider.notifier).state = i;
          context.go(path);
        },
        ref: ref,
      ),
    );
  }
}

// ── Curved bottom bar ─────────────────────────────────────────────────────────

class _CurvedBottomBar extends StatelessWidget {
  const _CurvedBottomBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    required this.ref,
  });

  final int currentIndex;
  final List<_TabItem> tabs;
  final void Function(int, String, WidgetRef) onTap;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      color: AppColors.surface,
      elevation: 12,
      shadowColor: AppColors.shadow,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Left 2 tabs.
            ...List.generate(2, (i) => _NavItem(
              tab: tabs[i],
              isActive: currentIndex == i,
              onTap: () {
                HapticFeedback.lightImpact();
                onTap(i, tabs[i].path, ref);
              },
            )),
            // Centre gap for FAB.
            const SizedBox(width: 64),
            // Right 2 tabs.
            ...List.generate(2, (i) {
              final idx = i + 2;
              return _NavItem(
                tab: tabs[idx],
                isActive: currentIndex == idx,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(idx, tabs[idx].path, ref);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Central FAB ───────────────────────────────────────────────────────────────

class _AddFab extends StatefulWidget {
  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _rotate = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/add-transaction');
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: Transform.rotate(
            angle: _rotate.value * 3.14159,
            child: child,
          ),
        ),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7986CB), AppColors.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 32),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
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