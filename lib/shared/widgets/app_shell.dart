/// Application shell widget.
///
/// Provides the permanent navigation structure for the main app:
/// - A [FloatingNavBar] at the bottom
/// - A context-aware floating action button (FAB)
/// - A responsive content area with max-width centering
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';
import 'package:life_os/shared/widgets/coming_soon_dialog.dart';
import 'package:life_os/shared/widgets/floating_nav_bar.dart';

/// The maximum content width for tablet/desktop layouts.
const double _kMaxContentWidth = 600;

/// The application shell that wraps all main app screens.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onPressed: () => _handleFAB(context, ref, location),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 32),
        ),
      ),
      // `heightFactor: 1.0` is essential here: the `bottomNavigationBar`
      // slot gives its child loose height constraints up to the full
      // available height. A plain `Center` would expand to fill that
      // height, pushing the nav bar into the middle of the screen and
      // collapsing the body. `heightFactor: 1.0` makes this `Center`
      // size itself to exactly its child's height instead.
      bottomNavigationBar: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: FloatingNavBar(currentLocation: location),
        ),
      ),
    );
  }

  /// Context-aware FAB action.
  ///
  /// On the Tasks screen, opens the task editor.
  /// On other screens, shows a coming soon dialog.
  void _handleFAB(BuildContext context, WidgetRef ref, String location) {
    if (location == AppRoutes.tasks) {
      _createTask(context, ref);
    } else if (location == AppRoutes.home) {
      _createTask(context, ref);
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => const ComingSoonDialog(
          title: 'Quick Create',
          message:
              'Quick create is coming soon. You\'ll be able to add '
              'tasks, notes, habits, and goals from here.',
        ),
      );
    }
  }

  Future<void> _createTask(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authProvider);
    final userId = authState.userId;
    if (userId == null) return;

    final result = await TaskEditorSheet.show(context);
    if (result == null) return;

    await ref
        .read(taskListProvider.notifier)
        .createTask(result.copyWith(userId: userId));
  }
}
