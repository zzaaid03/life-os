import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_icons.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/shared/widgets/quick_action_button.dart';

class HomeQuickActionsGrid extends StatelessWidget {
  const HomeQuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickActionButton(
            icon: AppIcons.add,
            label: 'New Task',
            onPressed: () => context.go(AppRoutes.tasks),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.flag_outlined,
            label: 'New Goal',
            onPressed: () => context.push(AppRoutes.goals),
          ),
        ),
      ],
    );
  }
}
