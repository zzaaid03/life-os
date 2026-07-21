/// Task editor dialog.
///
/// A premium centered dialog card for creating and editing tasks.
/// Fields: title, description, priority, due date.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// A centered dialog card for creating or editing a task.
///
/// Pass an existing [Task] to edit, or null to create a new one.
/// Returns the edited/created [Task] via the dialog's return value,
/// or null if cancelled.
class TaskEditorSheet extends StatefulWidget {
  /// Creates a [TaskEditorSheet].
  const TaskEditorSheet({
    super.key,
    this.task,
    this.defaultPriority = TaskPriority.none,
    this.initialTitle,
    this.initialDescription,
  });

  /// The task to edit, or null for a new task.
  final Task? task;

  /// Default priority for new tasks.
  final TaskPriority defaultPriority;

  /// Prefilled title for create mode (ignored when editing).
  final String? initialTitle;

  /// Prefilled description for create mode (ignored when editing).
  final String? initialDescription;

  /// Shows the editor as a centered dialog.
  static Future<Task?> show(
    BuildContext context, {
    Task? task,
    TaskPriority defaultPriority = TaskPriority.none,
    String? initialTitle,
    String? initialDescription,
  }) {
    return showDialog<Task>(
      context: context,
      builder: (context) => TaskEditorSheet(
        task: task,
        defaultPriority: defaultPriority,
        initialTitle: initialTitle,
        initialDescription: initialDescription,
      ),
    );
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskPriority _priority;
  DateTime? _dueDate;
  bool _isSaving = false;
  bool _showDueDateError = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.task?.title ?? widget.initialTitle ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? widget.initialDescription ?? '',
    );
    _priority = widget.task?.priority ?? widget.defaultPriority;
    _dueDate = widget.task?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty && _dueDate != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = picked;
        _showDueDateError = false;
      });
    }
  }

  void _save() {
    if (_dueDate == null) {
      setState(() => _showDueDateError = true);
      return;
    }
    if (!_isValid || _isSaving) return;

    setState(() => _isSaving = true);

    final task =
        widget.task?.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          updatedAt: DateTime.now(),
        ) ??
        Task(
          id: '',
          userId: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    Navigator.of(context).pop(task);
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
                // Title
                Text(
                  widget.task != null ? 'Edit Task' : 'New Task',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Title field
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'What needs to be done?',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Description field
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Add details (optional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Priority selector
                Text(
                  'Priority',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _PrioritySelector(
                  value: _priority,
                  onChanged: (p) => setState(() => _priority = p),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Due date
                Row(
                  children: [
                    Text(
                      'Due Date',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '(required)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _showDueDateError
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _DueDateButton(
                  dueDate: _dueDate,
                  onTap: _pickDate,
                  hasError: _showDueDateError,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Actions
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
                      child: Opacity(
                        opacity: _isValid ? 1.0 : 0.5,
                        child: FilledButton(
                          onPressed:
                              _titleController.text.trim().isNotEmpty &&
                                  !_isSaving
                              ? _save
                              : null,
                          child: Text(
                            widget.task != null ? 'Save' : 'Create',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      children: TaskPriority.values.map((p) {
        final isSelected = p == value;
        final color = _priorityColor(p, theme);

        return FilterChip(
          label: Text(_priorityLabel(p)),
          selected: isSelected,
          onSelected: (_) => onChanged(p),
          selectedColor: color.withValues(alpha: 0.15),
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? color
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSelected
                ? color.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        );
      }).toList(),
    );
  }

  String _priorityLabel(TaskPriority p) {
    return switch (p) {
      TaskPriority.none => 'None',
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };
  }

  Color _priorityColor(TaskPriority p, ThemeData theme) {
    return switch (p) {
      TaskPriority.none => theme.colorScheme.primary,
      TaskPriority.low => AppColors.info,
      TaskPriority.medium => AppColors.warning,
      TaskPriority.high => AppColors.error,
    };
  }
}

class _DueDateButton extends StatelessWidget {
  const _DueDateButton({
    required this.dueDate,
    required this.onTap,
    this.hasError = false,
  });

  final DateTime? dueDate;
  final VoidCallback onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = hasError
        ? theme.colorScheme.error
        : theme.colorScheme.outline.withValues(alpha: 0.3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: hasError ? 1.5 : 1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: hasError
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                dueDate != null
                    ? '${dueDate!.month}/${dueDate!.day}/${dueDate!.year}'
                    : 'Select a due date',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasError ? theme.colorScheme.error : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
