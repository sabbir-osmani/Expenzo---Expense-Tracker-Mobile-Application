import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ExpenzoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ExpenzoAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = false,
    this.bottom,
    this.elevation = 0,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final PreferredSizeWidget? bottom;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: AppTextStyles.headlineSmall),
      actions: actions,
      backgroundColor: AppColors.surface,
      elevation: elevation,
      scrolledUnderElevation: 0.5,
      shadowColor: AppColors.shadow,
      leading: showBack
          ? IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            )
          : leading,
      automaticallyImplyLeading: showBack,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}