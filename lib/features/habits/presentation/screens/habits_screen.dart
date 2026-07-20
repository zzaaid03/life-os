/// Habits screen.
///
/// Lists the user's habits with a daily check-off circle, today's
/// done/not-done state, and the current streak. Supports create,
/// tap-to-edit, and swipe-to-delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/habits/data/models/habit.dart';
import 'package:life_os/features/habits/domain/providers/habit_provider.dart';

/// Screen listing the user's habits.
class HabitsScreen extends ConsumerWidget {
  /// Creates a [HabitsScreen].
  const HabitsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await _HabitEditorDialog.show(context);
    if (result == null) return;
    await ref
        .read(habitListProvider.notifier)
        .createHabit(name: result.$1, description: result.$2);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Habit habit) async {
    final result = await _HabitEditorDialog.show(context, existing: habit);
    if (result == null) return;
    await ref
        .read(habitListProvider.notifier)
        .updateHabit(habit.copyWith(name: result.$1, description: result.$2));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New habit',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(habitListProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, HabitListState state) {
    final theme = Theme.of(context);

    if (state.status == HabitListStatus.loading && state.habits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.habits.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.xxxl * 2),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.favorite_outline_rounded,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No habits yet.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "You're one habit away from changing your life.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      itemCount: state.habits.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final view = state.habits[index];
        return Dismissible(
          key: ValueKey(view.habit.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
          ),
          onDismissed: (_) =>
              ref.read(habitListProvider.notifier).deleteHabit(view.habit.id),
          child: _HabitCard(
            view: view,
            onTap: () => _edit(context, ref, view.habit),
            onToggle: () =>
                ref.read(habitListProvider.notifier).toggleToday(view),
          ),
        );
      },
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.view,
    required this.onTap,
    required this.onToggle,
  });

  final HabitView view;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              // Daily check-off circle.
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: view.doneToday
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: view.doneToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: view.doneToday
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.habit.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (view.habit.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        view.habit.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Streak badge.
              if (view.streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.circular),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${view.streak}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

/// A centered dialog for creating or editing a habit.
///
/// Returns a `(name, description)` record, or null on cancel.
class _HabitEditorDialog extends StatefulWidget {
  const _HabitEditorDialog({this.existing});

  final Habit? existing;

  static Future<(String, String?)?> show(
    BuildContext context, {
    Habit? existing,
  }) {
    return showDialog<(String, String?)>(
      context: context,
      builder: (_) => _HabitEditorDialog(existing: existing),
    );
  }

  @override
  State<_HabitEditorDialog> createState() => _HabitEditorDialogState();
}

class _HabitEditorDialogState extends State<_HabitEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isValid => _nameController.text.trim().isNotEmpty;

  void _save() {
    if (!_isValid) return;
    final description = _descriptionController.text.trim();
    Navigator.of(context).pop((
      _nameController.text.trim(),
      description.isEmpty ? null : description,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing != null ? 'Edit Habit' : 'New Habit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _nameController,
                  autofocus: widget.existing == null,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Morning run',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Schedule / notes (optional)',
                    hintText: 'e.g. Every weekday before work',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isValid ? _save : null,
                        child: Text(
                          widget.existing != null ? 'Save' : 'Create',
                        ),
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
