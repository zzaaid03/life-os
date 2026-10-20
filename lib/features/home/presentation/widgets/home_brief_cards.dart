import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/home/domain/daily_brief_provider.dart';
import 'package:life_os/features/review/domain/review_seen_provider.dart';
import 'package:life_os/features/review/domain/weekly_review.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';

/// AI "Daily Brief" card: a warm 2-3 sentence summary of the user's day.
///
/// Fetches lazily on first build, offers a refresh button, and quietly
/// collapses to an invitation line if the AI call fails.
class HomeDailyBriefCard extends ConsumerStatefulWidget {
  const HomeDailyBriefCard({super.key});

  @override
  ConsumerState<HomeDailyBriefCard> createState() => _HomeDailyBriefCardState();
}

class _HomeDailyBriefCardState extends ConsumerState<HomeDailyBriefCard> {
  @override
  void initState() {
    super.initState();
    // Kick off the first fetch after build; no-op if already loaded.
    Future.microtask(
      () => ref.read(dailyBriefProvider.notifier).loadIfNeeded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(dailyBriefProvider);

    final String body = switch (state.status) {
      DailyBriefStatus.loaded => state.brief!,
      DailyBriefStatus.error =>
        'Your brief isn\'t available right now, tap refresh to try again.',
      _ => 'Summing up your day…',
    };

    return DashboardCard(
      icon: Icons.wb_sunny_outlined,
      title: 'Daily Brief',
      trailing: state.status == DailyBriefStatus.loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Refresh brief',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              onPressed: () => ref.read(dailyBriefProvider.notifier).refresh(),
            ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Column(
          key: ValueKey(body),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: state.status == DailyBriefStatus.loaded ? 0.8 : 0.45,
                ),
                height: 1.5,
              ),
            ),
            if (state.status == DailyBriefStatus.loaded &&
                (state.noticed?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Text(
                'Life OS noticed: ${state.noticed}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.75,
                  ),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A pointer to a not-yet-opened weekly review.
///
/// Renders nothing while the seen-state hasn't loaded yet, and nothing once
/// the current week's review has been opened, so it never flashes or lingers
/// past the point it means something.
class HomeWeeklyReviewPointerCard extends ConsumerWidget {
  const HomeWeeklyReviewPointerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewSeenState = ref.watch(reviewSeenProvider);
    final now = DateTime.now();
    // Nothing at all when there is no pointer to show, including the gap
    // above it: an unconditional spacer would leave a stray hole under the
    // daily brief on every day the review has already been opened.
    if (!reviewSeenState.hasUnseenReview(now)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: DashboardCard(
        icon: Icons.fact_check_outlined,
        title: 'Weekly Review',
        onTap: () {
          final userId = reviewSeenState.userId;
          final weekStart = mostRecentEndedWeekStart(now);
          if (userId != null) {
            ref.read(reviewSeenProvider.notifier).markSeen(userId, weekStart);
          }
          context.push(AppRoutes.weeklyReview);
        },
        child: Text(
          'Your review for last week is ready.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
