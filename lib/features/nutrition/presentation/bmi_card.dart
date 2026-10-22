import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

/// BMI with its category and the healthy weight range for the height.
/// Under 18 the adult ranges do not apply, so only the number is shown.
class BmiCard extends StatelessWidget {
  /// Creates a [BmiCard].
  const BmiCard({
    super.key,
    required this.weightKg,
    required this.heightCm,
    required this.units,
    this.age,
  });

  final double weightKg;
  final double heightCm;
  final int? age;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final value = bmi(weightKg, heightCm);
    final under18 = age != null && age! < 18;
    final headline = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final Widget details;
    if (under18) {
      details = Text(
        "Adult BMI ranges don't apply under 18.",
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      );
    } else {
      final range = healthyWeightRangeKg(heightCm);
      final imperial = units == UnitSystem.imperial;
      final lo = (imperial ? kgToLb(range.minKg) : range.minKg).round();
      final hi = (imperial ? kgToLb(range.maxKg) : range.maxKg).round();
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Healthy weight for your height: $lo to $hi ${imperial ? 'lb' : 'kg'}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "BMI doesn't account for muscle, so treat it as a rough guide.",
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('BMI ${value.toStringAsFixed(1)}', style: headline),
              if (!under18) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  BmiCategory.of(value).label,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          details,
        ],
      ),
    );
  }
}
