import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/workout_checkin_providers.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';

const _buttonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(64, 48)),
);

/// The daily "Did you train today?" check-in at the top of the fitness hub.
/// Reloads when the hub opens, so it rolls over at local midnight.
class CheckinCard extends ConsumerStatefulWidget {
  /// Creates a [CheckinCard].
  const CheckinCard({super.key});

  @override
  ConsumerState<CheckinCard> createState() => _CheckinCardState();
}

class _CheckinCardState extends ConsumerState<CheckinCard> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(workoutCheckinProvider.notifier).load();
    });
  }

  Future<void> _save({required bool trained}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(workoutCheckinProvider.notifier)
          .setTrained(trained: trained);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save your check-in. Try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutCheckinProvider);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColors.primary : AppColors.primaryDark;
    final answer = state.trained;

    final Widget child;
    if (!state.loaded) {
      child = const Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    } else if (answer == null && state.loadFailed) {
      child = Row(
        children: [
          const Expanded(child: Text("Couldn't load today's check-in")),
          TextButton(
            style: _buttonStyle,
            onPressed: () => ref.read(workoutCheckinProvider.notifier).load(),
            child: const Text('Retry'),
          ),
        ],
      );
    } else if (answer == null) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Did you train today?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: _buttonStyle,
                  onPressed: _saving ? null : () => _save(trained: true),
                  child: const Text('Yes'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  style: _buttonStyle,
                  onPressed: _saving ? null : () => _save(trained: false),
                  child: const Text('No'),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      child = Row(
        children: [
          Icon(
            answer ? Icons.check_circle_outline : Icons.bedtime_outlined,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              answer ? 'Trained today ✓' : 'Rest day',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
          TextButton(
            style: _buttonStyle,
            onPressed: _saving ? null : () => _save(trained: !answer),
            child: const Text('Change'),
          ),
        ],
      );
    }
    return DashboardCard(child: child);
  }
}
