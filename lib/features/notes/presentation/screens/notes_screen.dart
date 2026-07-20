/// Notes screen.
///
/// Lists the user's notes (pinned first, newest first) with create,
/// tap-to-edit, and swipe-to-delete. Simple title + body editor dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/notes/data/models/note.dart';
import 'package:life_os/features/notes/domain/providers/note_provider.dart';

/// Screen listing the user's notes.
class NotesScreen extends ConsumerWidget {
  /// Creates a [NotesScreen].
  const NotesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await _NoteEditorDialog.show(context);
    if (result == null) return;
    await ref
        .read(noteListProvider.notifier)
        .createNote(title: result.$1, content: result.$2);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Note note) async {
    final result = await _NoteEditorDialog.show(context, existing: note);
    if (result == null) return;
    await ref
        .read(noteListProvider.notifier)
        .updateNote(note.copyWith(title: result.$1, content: result.$2));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noteListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New note',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(noteListProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, NoteListState state) {
    final theme = Theme.of(context);

    if (state.status == NoteListStatus.loading && state.notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.notes.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.xxxl * 2),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No notes yet.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Capture a thought with +.',
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
      itemCount: state.notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final note = state.notes[index];
        return Dismissible(
          key: ValueKey(note.id),
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
              ref.read(noteListProvider.notifier).deleteNote(note.id),
          child: _NoteCard(note: note, onTap: () => _edit(context, ref, note)),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = note.content?.trim() ?? '';

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
                      note.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (note.isPinned)
                    Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A centered dialog for creating or editing a note.
///
/// Returns a `(title, content)` record, or null on cancel.
class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({this.existing});

  final Note? existing;

  static Future<(String, String?)?> show(
    BuildContext context, {
    Note? existing,
  }) {
    return showDialog<(String, String?)>(
      context: context,
      builder: (_) => _NoteEditorDialog(existing: existing),
    );
  }

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existing?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _isValid => _titleController.text.trim().isNotEmpty;

  void _save() {
    if (!_isValid) return;
    final content = _contentController.text.trim();
    Navigator.of(
      context,
    ).pop((_titleController.text.trim(), content.isEmpty ? null : content));
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
                  widget.existing != null ? 'Edit Note' : 'New Note',
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
                    hintText: 'What\'s this about?',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _contentController,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Write it down (optional)',
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
