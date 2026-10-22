import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';

/// A row of day chips (A Push, B Pull...). The next-up chip has a filled dot
/// and bold text, so it never relies on colour alone.
class RotationStrip extends StatelessWidget {
  /// Creates a [RotationStrip].
  const RotationStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.nextUp,
    required this.onPick,
  });

  final List<PlanDay> days;
  final int selected;
  final int nextUp;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < days.length; i++)
          _DayChip(
            label: '${dayLetter(i)} ${days[i].title}',
            semanticLabel:
                'Day ${dayLetter(i)}, ${days[i].title}${i == nextUp ? ', next up' : ''}',
            selected: i == selected,
            isNext: i == nextUp,
            onTap: () => onPick(i),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.isNext,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNext) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(AppRadius.circular),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: isNext ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
