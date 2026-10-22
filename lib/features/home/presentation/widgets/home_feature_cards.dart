import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/groceries/domain/providers/grocery_provider.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';
import 'package:life_os/features/subscriptions/domain/providers/subscription_provider.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';
import 'package:life_os/shared/widgets/empty_state_widget.dart';
import 'package:life_os/shared/widgets/section_header.dart';

/// A prominent, primary-colored card that opens the AI inbox scan flow.
class HomeInboxScanCard extends StatelessWidget {
  const HomeInboxScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final onPrimary = theme.colorScheme.onPrimary;

    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => context.push(AppRoutes.inboxScan),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: onPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan my inbox',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Turn emails into tasks & job updates',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashboard card showing the tracked job-application count.
class HomeJobApplicationsCard extends ConsumerWidget {
  const HomeJobApplicationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(jobApplicationCountProvider);

    return DashboardCard(
      icon: Icons.work_outline_rounded,
      title: 'Job Applications',
      trailing: count > 0
          ? Text(
              '$count',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      onTap: () => context.push(AppRoutes.jobApplications),
      child: EmptyStateWidget(
        icon: Icons.badge_outlined,
        title: count == 0
            ? 'No applications tracked yet.'
            : '$count application${count == 1 ? '' : 's'} tracked.',
        subtitle: count == 0
            ? 'Scan your inbox to start tracking.'
            : 'Tap to view interviews, acceptances, and more.',
        compact: true,
      ),
    );
  }
}

/// A dashboard section for subscriptions: a header plus a compact card.
///
/// Renders nothing at all when the user has no subscriptions, active or
/// cancelled: an empty-state card here would be noise on a dashboard that
/// already has an explicit place (the subscriptions screen's own empty
/// state) to invite adding the first one.
class HomeSubscriptionsSection extends ConsumerWidget {
  const HomeSubscriptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionListProvider);
    if (state.subscriptions.isEmpty) return const SizedBox.shrink();

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Subscriptions'),
        SizedBox(height: AppSpacing.md),
        HomeSubscriptionsCard(),
      ],
    );
  }
}

/// A compact dashboard card showing monthly spend and the active
/// subscription count, tapping through to the subscriptions screen.
class HomeSubscriptionsCard extends ConsumerWidget {
  const HomeSubscriptionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = ref
        .watch(subscriptionListProvider)
        .subscriptions
        .where((s) => s.status == SubscriptionStatus.active)
        .length;
    final monthlySpend = ref.watch(monthlySpendProvider);
    final currencies = monthlySpend.keys.toList()..sort();

    return DashboardCard(
      icon: Icons.repeat_rounded,
      title: 'Subscriptions',
      trailing: activeCount > 0
          ? Text(
              '$activeCount',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      onTap: () => context.push(AppRoutes.subscriptions),
      child: currencies.isEmpty
          ? Text(
              '$activeCount active subscription${activeCount == 1 ? '' : 's'}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final currency in currencies)
                  Text(
                    '$currency ${formatAmount(monthlySpend[currency]!)} / month',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// The home dashboard's groceries block. Unlike subscriptions it is always
/// shown, even with an empty list, so the user always has a way in.
class HomeGroceriesSection extends StatelessWidget {
  const HomeGroceriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Groceries'),
        SizedBox(height: AppSpacing.md),
        HomeGroceriesCard(),
      ],
    );
  }
}

/// A compact dashboard card showing how many grocery items are left to
/// buy, tapping through to the grocery list screen.
class HomeGroceriesCard extends ConsumerWidget {
  const HomeGroceriesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groceryListProvider);
    final count = state.uncheckedCount;

    final String subtitle;
    if (state.status == GroceryListStatus.error) {
      subtitle = 'Tap to open';
    } else if (state.status == GroceryListStatus.loading &&
        state.items.isEmpty) {
      subtitle = 'Loading…';
    } else if (count == 0) {
      subtitle = 'Nothing to buy';
    } else if (count == 1) {
      subtitle = '1 item to buy';
    } else {
      subtitle = '$count items to buy';
    }

    return DashboardCard(
      icon: Icons.shopping_cart_outlined,
      title: 'Groceries',
      trailing: count > 0
          ? Text(
              '$count',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      onTap: () => context.push(AppRoutes.groceries),
      child: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// The home dashboard's recipes block. Always shown, like groceries, so the
/// AI chef is one tap away even before anything is saved.
class HomeRecipesSection extends StatelessWidget {
  const HomeRecipesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Recipes'),
        SizedBox(height: AppSpacing.md),
        HomeRecipesCard(),
      ],
    );
  }
}

/// A compact dashboard card showing how many recipes are saved, tapping
/// through to the recipes screen.
class HomeRecipesCard extends ConsumerWidget {
  const HomeRecipesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedRecipesProvider);
    final count = state.recipes.length;

    final String subtitle;
    if (state.status == SavedRecipesStatus.error && count == 0) {
      subtitle = 'Tap to open';
    } else if (state.status == SavedRecipesStatus.loading && count == 0) {
      subtitle = 'Loading…';
    } else if (count == 0) {
      subtitle = 'No saved recipes yet';
    } else if (count == 1) {
      subtitle = '1 saved recipe';
    } else {
      subtitle = '$count saved recipes';
    }

    return DashboardCard(
      icon: Icons.restaurant_menu_outlined,
      title: 'Recipes',
      onTap: () => context.push(AppRoutes.recipes),
      child: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
