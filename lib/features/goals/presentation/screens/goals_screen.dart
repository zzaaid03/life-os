/// Goals screen.
///
/// Lists the user's goals with progress bars. Supports create, tap-to-edit
/// (including a progress slider), and swipe-to-delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';

/// Screen listing the user's goals.
class GoalsScreen extends ConsumerWidget {
  /// Creates a [GoalsScreen].
  const GoalsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await _GoalEditorDialog.show(context);
    if (result == null) return;
    await ref
        .read(goalListProvider.notifier)
        .createGoal(
          title: result.title,
          description: result.description,
          progress: result.progress,
          targetDate: result.targetDate,
        );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Goal goal) async {
    final result = await _GoalEditorDialog.show(context, existing: goal);
    if (result == null) return;
    await ref
        .read(goalListProvider.notifier)
        .updateGoal(
          goal.copyWith(
            title: result.title,
            description: result.description,
            progress: result.progress,
            targetDate: result.targetDate,
            status: result.progress >= 1.0
                ? GoalStatus.completed
                : GoalStatus.active,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New goal',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(goalListProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, GoalListState state) {
    final theme = Theme.of(context);

    if (state.status == GoalListStatus.loading && state.goals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.goals.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.xxxl * 2),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.track_changes_rounded,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No goals yet.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Small steps, big change. Set one with +.',
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
      itemCount: state.goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final goal = state.goals[index];
        return Dismissible(
          key: ValueKey(goal.id),
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
              ref.read(goalListProvider.notifier).deleteGoal(goal.id),
          child: _GoalCard(goal: goal, onTap: () => _edit(context, ref, goal)),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = goal.status == GoalStatus.completed;
    final pct = (goal.progress * 100).round();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$pct%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isCompleted
                          ? AppColors.success
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (goal.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  goal.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  valueColor: AlwaysStoppedAnimation(
                    isCompleted ? AppColors.success : theme.colorScheme.primary,
                  ),
                ),
              ),
              if (goal.targetDate != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Target: ${goal.targetDate!.month}/${goal.targetDate!.day}/${goal.targetDate!.year}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The values collected by [_GoalEditorDialog].
class _GoalEditorResult {
  const _GoalEditorResult({
    required this.title,
    this.description,
    required this.progress,
    this.targetDate,
  });

  final String title;
  final String? description;
  final double progress;
  final DateTime? targetDate;
}

/// A centered dialog for creating or editing a goal, with a progress slider.
class _GoalEditorDialog extends StatefulWidget {
  const _GoalEditorDialog({this.existing});

  final Goal? existing;

  static Future<_GoalEditorResult?> show(
    BuildContext context, {
    Goal? existing,
  }) {
    return showDialog<_GoalEditorResult>(
      context: context,
      builder: (_) => _GoalEditorDialog(existing: existing),
    );
  }

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late double _progress;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _progress = widget.existing?.progress ?? 0;
    _targetDate = widget.existing?.targetDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isValid => _titleController.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
  }

  void _save() {
    if (!_isValid) return;
    final description = _descriptionController.text.trim();
    Navigator.of(context).pop(
      _GoalEditorResult(
        title: _titleController.text.trim(),
        description: description.isEmpty ? null : description,
        progress: _progress,
        targetDate: _targetDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: screenHeight * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing != null ? 'Edit Goal' : 'New Goal',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _titleController,
                  autofocus: widget.existing == null,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'What do you want to achieve?',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What does success look like?',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Progress · ${(_progress * 100).round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Slider(
                  value: _progress,
                  divisions: 20,
                  label: '${(_progress * 100).round()}%',
                  onChanged: (value) => setState(() => _progress = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Target date',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _targetDate != null
                                ? '${_targetDate!.month}/${_targetDate!.day}/${_targetDate!.year}'
                                : 'No date',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (_targetDate != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _targetDate = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear date',
                          ),
                      ],
                    ),
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
