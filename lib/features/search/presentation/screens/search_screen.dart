/// Search screen: global search across all Life OS data.
///
/// Search is the ONLY way to reach an uploaded file: there is deliberately
/// no Files tab and no browse list. This screen is therefore also the only
/// place a file can be opened or deleted.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/files/data/repositories/file_repository.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/search/domain/providers/search_provider.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/shared/widgets/empty_state_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    ref.read(fileSearchProvider.notifier).search(userId, value);
  }

  Future<void> _openFile(StoredFile file) async {
    try {
      final url = await ref.read(fileRepositoryProvider).signedUrl(file);
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open that file.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open that file.')));
    }
  }

  Future<void> _deleteFile(StoredFile file) async {
    final displayName = file.userNote.isNotEmpty ? file.userNote : file.fileName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('This permanently deletes "$displayName". This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await ref.read(fileRepositoryProvider).delete(file);
      if (!mounted) return;
      ref.read(fileSearchProvider.notifier).removeLocally(file);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete that file.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);
    final isSearching = query.trim().isNotEmpty;
    final tasks = ref.watch(matchingTasksProvider);
    final goals = ref.watch(matchingGoalsProvider);
    final fileState = ref.watch(fileSearchProvider);
    final hasResults = tasks.isNotEmpty || goals.isNotEmpty || fileState.results.isNotEmpty;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Search',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search anything…',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: AppSpacing.xxxl),
          if (!isSearching)
            const Center(
              child: EmptyStateWidget(
                icon: Icons.search_rounded,
                title: 'What are you looking for?',
                subtitle: 'Find tasks, goals and files.',
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms)
          else if (!hasResults)
            const Center(
              child: EmptyStateWidget(
                icon: Icons.search_off_rounded,
                title: 'No matches',
                subtitle: 'Try a different search term.',
              ),
            ).animate().fadeIn(duration: 300.ms)
          else ...[
            if (fileState.results.isNotEmpty)
              _ResultSection(
                title: 'Files',
                children: fileState.results
                    .map(
                      (file) => _FileResultTile(
                        file: file,
                        onOpen: () => _openFile(file),
                        onDelete: () => _deleteFile(file),
                      ),
                    )
                    .toList(),
              ),
            if (tasks.isNotEmpty)
              _ResultSection(
                title: 'Tasks',
                children: tasks.map((task) => _TaskResultTile(task: task)).toList(),
              ),
            if (goals.isNotEmpty)
              _ResultSection(
                title: 'Goals',
                children: goals.map((goal) => _GoalResultTile(goal: goal)).toList(),
              ),
          ],
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _FileResultTile extends StatelessWidget {
  const _FileResultTile({
    required this.file,
    required this.onOpen,
    required this.onDelete,
  });

  final StoredFile file;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = file.userNote.isNotEmpty ? file.userNote : file.fileName;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onOpen,
        leading: _FileThumbnail(file: file),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.error,
          ),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({required this.file});

  final StoredFile file;

  @override
  Widget build(BuildContext context) {
    if (file.isImage && file.thumbnailBase64 != null) {
      try {
        final bytes = base64Decode(file.thumbnailBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        // Fall through to the generic icon below.
      }
    }
    return const Icon(Icons.insert_drive_file_outlined);
  }
}

class _TaskResultTile extends StatelessWidget {
  const _TaskResultTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline_rounded),
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: (task.description?.isNotEmpty ?? false)
            ? Text(
                task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
      ),
    );
  }
}

class _GoalResultTile extends StatelessWidget {
  const _GoalResultTile({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text(goal.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: (goal.description?.isNotEmpty ?? false)
            ? Text(
                goal.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
      ),
    );
  }
}
