/// The servings stepper: minus, count, plus.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// Lowest servings the stepper allows.
const int kMinServings = 1;

/// Highest servings the stepper allows.
const int kMaxServings = 12;

/// A pill with minus / count / plus and a "servings" label.
class ServingsStepper extends StatelessWidget {
  /// Creates a [ServingsStepper].
  const ServingsStepper({super.key, required this.servings, required this.onChanged});

  /// Current servings.
  final int servings;

  /// Called with the new value.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.circular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: servings > kMinServings ? () => onChanged(servings - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                '$servings',
                key: ValueKey(servings),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: servings < kMaxServings ? () => onChanged(servings + 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, right: AppSpacing.md),
            child: Text(
              'servings',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: onTap == null ? Colors.transparent : scheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? scheme.onSurface.withValues(alpha: 0.3) : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
