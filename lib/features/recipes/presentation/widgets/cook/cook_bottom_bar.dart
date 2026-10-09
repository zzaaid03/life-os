/// Cook mode's bottom controls: read aloud, ask the chef, back and next.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_palette.dart';

/// Big, thumb-sized controls. Every target is at least 56 tall.
class CookBottomBar extends StatelessWidget {
  /// Creates a [CookBottomBar].
  const CookBottomBar({
    super.key,
    required this.palette,
    required this.readAloud,
    required this.onReadAloudChanged,
    required this.onAskChef,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  /// Cook-mode colours.
  final CookPalette palette;

  /// Whether read aloud is on.
  final bool readAloud;

  /// Flips read aloud.
  final ValueChanged<bool> onReadAloudChanged;

  /// Opens "Ask the chef".
  final VoidCallback onAskChef;

  /// Previous page, or null on the first page.
  final VoidCallback? onBack;

  /// Next page.
  final VoidCallback onNext;

  /// "Next" or "Finish".
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl));
    final bigText = theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  toggled: readAloud,
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => onReadAloudChanged(!readAloud),
                      style: OutlinedButton.styleFrom(
                        shape: shape,
                        backgroundColor: readAloud ? palette.accent.withValues(alpha: 0.16) : null,
                        foregroundColor: readAloud ? palette.accent : theme.colorScheme.onSurface,
                        side: BorderSide(
                          color: readAloud ? palette.accent : theme.colorScheme.outlineVariant,
                          width: readAloud ? 2 : 1,
                        ),
                      ),
                      icon: Icon(
                        readAloud ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        size: 24,
                      ),
                      label: const Text('Read aloud'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: onAskChef,
                    style: OutlinedButton.styleFrom(
                      shape: shape,
                      foregroundColor: theme.colorScheme.onSurface,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    icon: const Icon(Icons.forum_rounded, size: 24),
                    label: const Text('Ask the chef'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 72,
                  child: FilledButton.tonalIcon(
                    onPressed: onBack,
                    style: FilledButton.styleFrom(shape: shape, textStyle: bigText),
                    icon: const Icon(Icons.arrow_back_rounded, size: 28),
                    label: const Text('Back'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 72,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      shape: shape,
                      textStyle: bigText,
                      backgroundColor: palette.accent,
                      foregroundColor: palette.onAccent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nextLabel),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          nextLabel == 'Finish'
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
