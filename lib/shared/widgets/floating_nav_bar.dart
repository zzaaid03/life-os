/// Floating bottom navigation bar.
///
/// Custom navigation component with glass effect,
/// blur, soft shadow, and animated labels.
/// Five items: Home, Timeline, Life, Search, Settings.
library;

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_icons.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// The floating bottom navigation bar for Life OS.
///
/// Displays five navigation items with icons.
/// Active item shows a label. Inactive items show only the icon.
/// Features glass-morphism effect with blur and soft shadow.
class FloatingNavBar extends StatelessWidget {
  /// Creates a [FloatingNavBar].
  const FloatingNavBar({super.key, required this.currentLocation});

  /// The current route location from GoRouter.
  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.85)
              : AppColors.surfaceLight.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: const ColorFilter.mode(
              Colors.transparent,
              BlendMode.srcOver,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: AppIcons.home,
                  filledIcon: AppIcons.homeFilled,
                  label: 'Home',
                  route: AppRoutes.home,
                  isActive: currentLocation == AppRoutes.home,
                ),
                _NavItem(
                  icon: AppIcons.timeline,
                  filledIcon: AppIcons.timeline,
                  label: 'Timeline',
                  route: AppRoutes.timeline,
                  isActive: currentLocation == AppRoutes.timeline,
                ),
                _NavItem(
                  icon: AppIcons.life,
                  filledIcon: AppIcons.lifeFilled,
                  label: 'Life',
                  route: AppRoutes.life,
                  isActive: currentLocation == AppRoutes.life,
                ),
                _NavItem(
                  icon: AppIcons.search,
                  filledIcon: AppIcons.search,
                  label: 'Search',
                  route: AppRoutes.search,
                  isActive: currentLocation == AppRoutes.search,
                ),
                _NavItem(
                  icon: AppIcons.settings,
                  filledIcon: AppIcons.settingsFilled,
                  label: 'Settings',
                  route: AppRoutes.settings,
                  isActive: currentLocation == AppRoutes.settings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.route,
    required this.isActive,
  });

  final IconData icon;
  final IconData filledIcon;
  final String label;
  final String route;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.go(route),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: label,
        selected: isActive,
        button: true,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  top: isActive ? 12 : 16,
                  bottom: isActive ? 0 : 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? filledIcon : icon,
                      size: 24,
                      color: isActive
                          ? AppColors.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
