/// Upload sheet opened from the (+) chooser's "Add File" entry.
///
/// Picks a file, lets the user mark it private, and uploads it directly
/// through [fileRepositoryProvider]. Deliberately does not touch
/// `fileListProvider` — with no Files browse screen watching it, that
/// provider's notifier is never created, so calling its upload() would
/// throw before ever reaching the repository.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/repositories/file_repository.dart';
import 'package:life_os/features/files/data/services/file_picker_service.dart';

String _formatBytes(int bytes) {
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}

/// Shows the "Add File" upload sheet.
class AddFileSheet extends ConsumerStatefulWidget {
  const AddFileSheet({super.key});

  /// Opens [AddFileSheet] as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      isScrollControlled: true,
      builder: (_) => const AddFileSheet(),
    );
  }

  @override
  ConsumerState<AddFileSheet> createState() => _AddFileSheetState();
}

class _AddFileSheetState extends ConsumerState<AddFileSheet> {
  PickedFile? _picked;
  bool _isPrivate = false;
  bool _isUploading = false;
  bool _isPicking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    try {
      final picked = await ref.read(filePickerServiceProvider).pickAndPrepare();
      if (!mounted) return;
      if (picked == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _picked = picked;
        _isPicking = false;
      });
    } on FilePickException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick a file.')),
      );
    }
  }

  Future<void> _upload() async {
    final picked = _picked;
    if (picked == null || _isUploading) return;

    final userId = ref.read(authProvider).userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to add a file.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await ref.read(fileRepositoryProvider).upload(
        userId: userId,
        file: picked,
        isPrivate: _isPrivate,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File added.')),
      );
    } on FilePickException catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that file. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.all(Radius.circular(AppRadius.circular)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Add File',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isPicking)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_picked != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _picked!.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _picked!.fileName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatBytes(_picked!.sizeBytes),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPrivate,
                onChanged: _isUploading
                    ? null
                    : (value) => setState(() => _isPrivate = value),
                title: const Text('Private, never send to AI'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Once you add a file you can't remove it from the app yet. Only add "
                "something you're happy to keep.",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isUploading ? null : _upload,
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add File'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
