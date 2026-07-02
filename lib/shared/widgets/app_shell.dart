/// Application shell widget.
///
/// Provides the permanent navigation structure for the main app:
/// - A [FloatingNavBar] at the bottom
/// - A floating action button (FAB) for quick creation
/// - A responsive content area with max-width centering
///
/// This shell wraps all main app screens (Home, Timeline, Life,
/// Search, Settings) so they share a single navigation instance.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/shared/widgets/coming_soon_dialog.dart';
import 'package:life_os/shared/widgets/floating_nav_bar.dart';

/// The maximum content width for tablet/desktop layouts.
const double _kMaxContentWidth = 600;

/// The application shell that wraps all main app screens.
///
/// Provides the floating bottom navigation bar, a centered FAB,
/// and responsive content area.
class AppShell extends StatelessWidget {
  /// Creates an [AppShell].
  const AppShell({super.key, required this.child});

  /// The current screen content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: child,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxxl),
        child: FloatingActionButton.large(
          onPressed: () => _showComingSoon(context),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 32),
        ),
      ),
      bottomNavigationBar: FloatingNavBar(currentLocation: location),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const ComingSoonDialog(
        title: 'Quick Create',
        message:
            'Quick create is coming soon. You\'ll be able to add tasks, '
            'notes, habits, and goals from here.',
      ),
    );
  }
}
