import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/number_format.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';

/// The BODY section: compact calories and BMI tiles, side by side. Both tap
/// through to the calorie screen, which holds the details.
class BodyRow extends ConsumerWidget {
  /// Creates a [BodyRow].
  const BodyRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(calorieProfileProvider);
    final target = ref.watch(dailyTargetProvider);
    final profile = state.profile;
    final weight = profile.weightKg;
    final height = profile.heightCm;
    final hasBmi =
        weight != null &&
        height != null &&
        isValidWeightKg(weight) &&
        isValidHeightCm(height);
    final birthYear = profile.birthYear;
    final under18 =
        birthYear != null && ageFromBirthYear(birthYear, DateTime.now()) < 18;

    final String caloriesValue;
    final String caloriesNote;
    if (!state.loaded) {
      caloriesValue = 'Loading…';
      caloriesNote = '';
    } else if (state.loadFailed) {
      caloriesValue = 'Not loaded';
      caloriesNote = 'Tap to open';
    } else if (target == null) {
      caloriesValue = 'Set your target';
      caloriesNote = '';
    } else {
      caloriesValue = '${formatThousands(target)} kcal/day';
      caloriesNote = profile.goal?.label ?? '';
    }

    final String bmiValue;
    final String bmiNote;
    if (!state.loaded) {
      bmiValue = 'Loading…';
      bmiNote = '';
    } else if (hasBmi) {
      final value = bmi(weight, height);
      bmiValue = value.toStringAsFixed(1);
      bmiNote = under18 ? '' : BmiCategory.of(value).label;
    } else {
      bmiValue = 'Add details';
      bmiNote = '';
    }

    void open() => context.push(AppRoutes.calorieTarget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BODY',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BodyTile(
                  label: 'Calories',
                  value: caloriesValue,
                  note: caloriesNote,
                  onTap: open,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _BodyTile(
                  label: 'BMI',
                  value: bmiValue,
                  note: bmiNote,
                  onTap: open,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BodyTile extends StatelessWidget {
  const _BodyTile({
    required this.label,
    required this.value,
    required this.note,
    required this.onTap,
  });

  final String label;
  final String value;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Semantics(
      button: true,
      label: [label, value, if (note.isNotEmpty) note].join(', '),
      excludeSemantics: true,
      child: DashboardCard(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
