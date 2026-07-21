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
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';
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

  /// Opens the "Add" chooser (Add Task / Add Goal), regardless of screen.
  void _handleFAB(BuildContext context, WidgetRef ref, String location) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _AddChooserSheet(
        onAddTask: () {
          Navigator.of(sheetContext).pop();
          _createTask(context, ref);
        },
        onAddGoal: () {
          Navigator.of(sheetContext).pop();
          // TODO: re-point to AI Goal Breakdown when it exists
          context.go(AppRoutes.goals);
        },
      ),
    );
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

/// Premium animated chooser sheet offering "Add Task" / "Add Goal" actions.
class _AddChooserSheet extends StatefulWidget {
  const _AddChooserSheet({required this.onAddTask, required this.onAddGoal});

  final VoidCallback onAddTask;
  final VoidCallback onAddGoal;

  @override
  State<_AddChooserSheet> createState() => _AddChooserSheetState();
}

class _AddChooserSheetState extends State<_AddChooserSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = curved;
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.circular)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: _ChooserTile(
                        icon: Icons.check_circle_outline,
                        label: 'Add Task',
                        onTap: widget.onAddTask,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _ChooserTile(
                        icon: Icons.flag_outlined,
                        label: 'Add Goal',
                        onTap: widget.onAddGoal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single large, tappable tile within the [_AddChooserSheet].
class _ChooserTile extends StatelessWidget {
  const _ChooserTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl,
            horizontal: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: colorScheme.onPrimaryContainer),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
