/// Inbox scan consent dialog.
///
/// Shown once before the first inbox scan. Explains, in plain language,
/// what Life OS reads and what it stores, and asks for explicit consent.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A consent dialog for the AI inbox assistant.
///
/// Returns `true` via [Navigator.pop] when the user taps
/// "Connect Gmail & Scan", `null`/`false` when cancelled.
class InboxConsentDialog extends StatelessWidget {
  /// Creates an [InboxConsentDialog].
  const InboxConsentDialog({super.key});

  /// Shows the consent dialog. Resolves to `true` only if the user accepts.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const InboxConsentDialog(),
    );
    return result ?? false;
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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Scan your inbox with AI',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Life OS will read your recent emails to suggest tasks and '
                  'track your job applications. We never store your emails — '
                  'only the tasks and summaries you keep. Powered by an AI '
                  'provider that does not train on your data.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Connect Gmail & Scan'),
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
