/// Files screen.
///
/// Browse, upload, open and delete the user's stored files. Files are
/// network-only, so an empty list with no connection is expected, not an
/// error state to design around.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/files/data/repositories/file_repository.dart';
import 'package:life_os/features/files/data/services/file_picker_service.dart';
import 'package:life_os/features/files/domain/providers/file_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const List<String> _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) => '${_kMonths[dt.month - 1]} ${dt.day}, ${dt.year}';

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

IconData _iconForMime(String mimeType) {
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf_rounded;
  if (mimeType.startsWith('text/')) return Icons.description_rounded;
  if (mimeType.contains('word') || mimeType.contains('document')) {
    return Icons.article_rounded;
  }
  return Icons.insert_drive_file_rounded;
}

/// Screen listing and managing the user's stored files.
class FilesScreen extends ConsumerWidget {
  /// Creates a [FilesScreen].
  const FilesScreen({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await ref.read(filePickerServiceProvider).pickAndPrepare();
      if (picked == null) return;
      if (!context.mounted) return;

      final isPrivate = await _UploadPrivacySheet.show(context, picked.fileName);
      if (isPrivate == null) return;

      await ref.read(fileListProvider.notifier).upload(picked, isPrivate: isPrivate);
    } on FilePickException catch (e) {
      if (context.mounted) _showSnack(context, e.message);
    } catch (_) {
      if (context.mounted) _showSnack(context, 'Could not upload the file.');
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, StoredFile file) async {
    try {
      final url = await ref.read(fileRepositoryProvider).signedUrl(file);
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _showSnack(context, 'Could not open the file.');
      }
    } catch (_) {
      if (context.mounted) _showSnack(context, 'Could not open the file.');
    }
  }

  Future<void> _togglePrivate(BuildContext context, WidgetRef ref, StoredFile file) async {
    try {
      await ref.read(fileListProvider.notifier).setPrivate(file, !file.isPrivate);
    } catch (_) {
      if (context.mounted) _showSnack(context, 'Could not update the file.');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, StoredFile file) async {
    try {
      await ref.read(fileListProvider.notifier).delete(file);
    } catch (_) {
      if (context.mounted) _showSnack(context, "Couldn't delete the file. Please try again.");
      await ref.read(fileListProvider.notifier).refresh();
    }
  }

  Future<bool> _confirmDelete(BuildContext context, StoredFile file) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete file?'),
            content: Text('"${file.fileName}" will be removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            tooltip: 'Upload file',
            onPressed: () => _upload(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(fileListProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, FileListState state) {
    if (state.status == FileListStatus.loading && state.files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == FileListStatus.error && state.files.isEmpty) {
      return _MessageList(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load files",
        subtitle: state.error ?? 'Please pull to refresh and try again.',
        action: TextButton(
          onPressed: () => ref.read(fileListProvider.notifier).refresh(),
          child: const Text('Retry'),
        ),
      );
    }

    if (state.files.isEmpty) {
      return _MessageList(
        icon: Icons.folder_open_rounded,
        title: 'No files yet',
        subtitle: 'Upload a file to keep it safe and searchable.',
        action: FilledButton.icon(
          onPressed: () => _upload(context, ref),
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Upload a file'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      itemCount: state.files.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final file = state.files[index];
        return Dismissible(
          key: ValueKey(file.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          ),
          confirmDismiss: (_) => _confirmDelete(context, file),
          onDismissed: (_) => _delete(context, ref, file),
          child: _FileRow(
            file: file,
            onTap: () => _open(context, ref, file),
            onTogglePrivate: () => _togglePrivate(context, ref, file),
          ),
        );
      },
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, this.onTap, this.onTogglePrivate});

  final StoredFile file;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePrivate;

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
              _FileThumbnail(file: file),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (file.isPrivate) ...[
                          Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            '${_formatBytes(file.sizeBytes)} · ${_formatDate(file.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  file.isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 20,
                ),
                tooltip: file.isPrivate ? 'Make public' : 'Make private, never send to AI',
                onPressed: onTogglePrivate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small thumbnail that never makes a network call: images render
/// straight from [StoredFile.thumbnailBase64], the tiny preview already
/// carried on the metadata row, decoded in memory with [Image.memory].
/// Every non-image file, and any image with no thumbnail, falls back to
/// the static [_iconForMime] icon.
class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({required this.file});

  final StoredFile file;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = file.thumbnailBase64;

    if (thumbnail == null) {
      return _icon(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.memory(
        base64Decode(thumbnail),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _icon(theme),
      ),
    );
  }

  Widget _icon(ThemeData theme) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        _iconForMime(file.mimeType),
        size: 20,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

/// Confirm sheet shown before an upload, letting the user set the
/// per-file "private, never send to AI" toggle. Defaults to off.
///
/// Returns the chosen [bool] value, or null if the user cancelled.
class _UploadPrivacySheet extends StatefulWidget {
  const _UploadPrivacySheet({required this.fileName});

  final String fileName;

  static Future<bool?> show(BuildContext context, String fileName) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UploadPrivacySheet(fileName: fileName),
    );
  }

  @override
  State<_UploadPrivacySheet> createState() => _UploadPrivacySheetState();
}

class _UploadPrivacySheetState extends State<_UploadPrivacySheet> {
  bool _isPrivate = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.all(Radius.circular(AppRadius.circular)),
              ),
            ),
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private, never send to AI'),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_isPrivate),
                    child: const Text('Upload'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A centered message rendered inside a scrollable so pull-to-refresh works
/// even when the list is empty or errored.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxxl * 2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
