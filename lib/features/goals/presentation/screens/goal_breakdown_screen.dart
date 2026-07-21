/// AI Goal Breakdown screen.
///
/// Two-step flow: the user enters a goal (title, optional description,
/// optional target date) and taps "Generate tasks with AI", which calls the
/// `goal-breakdown` Edge Function for an ordered list of suggested tasks.
/// The user reviews/edits/removes suggestions (each already carries a
/// computed due date), then "Save goal & tasks" creates the goal and each
/// reviewed task linked to it via `goalId`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/goals/data/goal_breakdown_service.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/supabase_goal_repository.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/features/inbox/presentation/screens/inbox_scan_screen.dart'
    show mapSuggestedPriority;
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_priority_chip.dart';
import 'package:uuid/uuid.dart';

/// A reviewed suggestion awaiting the user's save decision.
///
/// Not yet a real [Task] — created only when the user saves.
class _ReviewItem {
  const _ReviewItem({
    required this.key,
    required this.title,
    this.description,
    required this.priority,
    required this.dueDate,
  });

  final String key;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime dueDate;

  _ReviewItem copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    DateTime? dueDate,
  }) {
    return _ReviewItem(
      key: key,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

/// Screen driving the AI goal-breakdown flow.
class GoalBreakdownScreen extends ConsumerStatefulWidget {
  /// Creates a [GoalBreakdownScreen].
  const GoalBreakdownScreen({super.key});

  @override
  ConsumerState<GoalBreakdownScreen> createState() =>
      _GoalBreakdownScreenState();
}

class _GoalBreakdownScreenState extends ConsumerState<GoalBreakdownScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _targetDate;

  bool _isGenerating = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<_ReviewItem>? _reviewItems;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isValidGoal => _titleController.text.trim().isNotEmpty;

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _generate() async {
    if (!_isValidGoal || _isGenerating) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final suggestions = await ref
          .read(goalBreakdownServiceProvider)
          .generateTasks(
            goalTitle: _titleController.text.trim(),
            goalDescription: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            targetDate: _targetDate,
          );

      if (!mounted) return;
      setState(() {
        _reviewItems = suggestions
            .map(
              (s) => _ReviewItem(
                key: const Uuid().v4(),
                title: s.title,
                description: s.description,
                priority: mapSuggestedPriority(s.priority),
                dueDate: s.suggestedDueDate,
              ),
            )
            .toList();
      });
    } on GoalBreakdownException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'We couldn\'t generate tasks right now. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _editItem(_ReviewItem item) async {
    final result = await TaskEditorSheet.show(
      context,
      initialTitle: item.title,
      initialDescription: item.description,
      initialDueDate: item.dueDate,
      defaultPriority: item.priority,
    );
    if (result == null || !mounted) return;

    setState(() {
      _reviewItems = _reviewItems!
          .map(
            (i) => i.key == item.key
                ? i.copyWith(
                    title: result.title,
                    description: result.description,
                    priority: result.priority,
                    dueDate: result.dueDate,
                  )
                : i,
          )
          .toList();
    });
  }

  void _removeItem(_ReviewItem item) {
    setState(() {
      _reviewItems = _reviewItems!.where((i) => i.key != item.key).toList();
    });
  }

  Future<void> _saveGoalAndTasks() async {
    if (!_isValidGoal || _isSaving) return;
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final goal = await ref
          .read(goalRepositoryProvider)
          .create(
            Goal(
              id: const Uuid().v4(),
              userId: userId,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              targetDate: _targetDate,
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final item in _reviewItems ?? const <_ReviewItem>[]) {
        await ref
            .read(taskRepositoryProvider)
            .create(
              Task(
                id: const Uuid().v4(),
                userId: userId,
                title: item.title,
                description: item.description,
                priority: item.priority,
                dueDate: item.dueDate,
                goalId: goal.id,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      }

      await ref.read(goalListProvider.notifier).refresh();
      await ref.read(taskListProvider.notifier).refresh();

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'We couldn\'t save your goal right now. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewItems = _reviewItems;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Goal Breakdown')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.lg,
          ),
          children: [
            TextField(
              controller: _titleController,
              autofocus: reviewItems == null,
              enabled: reviewItems == null,
              decoration: const InputDecoration(
                labelText: 'Goal',
                hintText: 'What do you want to achieve?',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _descriptionController,
              enabled: reviewItems == null,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What does success look like?',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Target date (optional)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: reviewItems == null ? _pickTargetDate : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                            : 'No target date (30-day horizon)',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (_targetDate != null && reviewItems == null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _targetDate = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Clear date',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (reviewItems == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isValidGoal && !_isGenerating
                      ? _generate
                      : null,
                  icon: _isGenerating
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    _isGenerating ? 'Generating…' : 'Generate tasks with AI',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (reviewItems != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Suggested Tasks',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${reviewItems.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (reviewItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                  ),
                  child: Text(
                    'No tasks left — you can still save the goal on its own.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              ...reviewItems.map(
                (item) => _ReviewCard(
                  item: item,
                  onTap: () => _editItem(item),
                  onRemove: () => _removeItem(item),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveGoalAndTasks,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Save goal & tasks'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.massive),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final _ReviewItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          if (item.priority != TaskPriority.none) ...[
                            TaskPriorityChip(priority: item.priority),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Icon(
                            Icons.event_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            '${item.dueDate.month}/${item.dueDate.day}/${item.dueDate.year}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
