/// Goal editor dialog.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/goals/data/models/goal.dart';

/// The values collected by [GoalEditorDialog].
class GoalEditorResult {
  const GoalEditorResult({
    required this.title,
    this.description,
    required this.progress,
    this.targetDate,
  }) : delete = false;

  /// Signals that the user asked to delete the goal instead of saving it.
  const GoalEditorResult.delete()
    : title = '',
      description = null,
      progress = 0,
      targetDate = null,
      delete = true;

  final String title;
  final String? description;
  final double progress;
  final DateTime? targetDate;

  /// Whether the dialog was closed by the "Delete goal" button.
  final bool delete;
}

/// A centered dialog for creating or editing a goal, with a progress slider.
class GoalEditorDialog extends StatefulWidget {
  const GoalEditorDialog({
    super.key,
    this.existing,
    this.progressDisabled = false,
  });

  final Goal? existing;

  /// Whether the progress slider is disabled because this goal's progress
  /// is derived from its linked tasks instead.
  final bool progressDisabled;

  static Future<GoalEditorResult?> show(
    BuildContext context, {
    Goal? existing,
    bool progressDisabled = false,
  }) {
    return showDialog<GoalEditorResult>(
      context: context,
      builder: (_) => GoalEditorDialog(
        existing: existing,
        progressDisabled: progressDisabled,
      ),
    );
  }

  @override
  State<GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<GoalEditorDialog> {
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
      GoalEditorResult(
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
                  widget.progressDisabled
                      ? 'Progress · from linked tasks'
                      : 'Progress · ${(_progress * 100).round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Slider(
                  value: _progress,
                  divisions: 20,
                  label: '${(_progress * 100).round()}%',
                  onChanged: widget.progressDisabled
                      ? null
                      : (value) => setState(() => _progress = value),
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
                                ? formatDay(_targetDate!)
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
                if (widget.existing != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const GoalEditorResult.delete()),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete goal'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
