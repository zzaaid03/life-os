import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';

enum _PlanAction { regenerate, delete }

/// The hub's overflow menu: Regenerate and Delete plan. Hidden when there is
/// no plan.
class PlanMenuButton extends ConsumerWidget {
  /// Creates a [PlanMenuButton].
  const PlanMenuButton({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _onPick(
    BuildContext context,
    WidgetRef ref,
    _PlanAction action,
  ) async {
    switch (action) {
      case _PlanAction.regenerate:
        final ok = await _confirm(
          context,
          title: 'Regenerate your plan?',
          body:
              'Your current plan is archived and you answer the questions '
              'again to build a new one.',
          action: 'Regenerate',
        );
        if (ok && context.mounted) {
          unawaited(context.push(AppRoutes.fitnessPlanNew));
        }
      case _PlanAction.delete:
        final ok = await _confirm(
          context,
          title: 'Delete your plan?',
          body: 'This removes your plan and all of its exercises.',
          action: 'Delete',
        );
        if (!ok) return;
        try {
          await ref.read(workoutPlanProvider.notifier).deletePlan();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Couldn't delete your plan. Try again."),
              ),
            );
          }
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlan = ref.watch(
      workoutPlanProvider.select((s) => s.plan != null),
    );
    if (!hasPlan) return const SizedBox.shrink();
    return PopupMenuButton<_PlanAction>(
      tooltip: 'Plan options',
      onSelected: (a) => _onPick(context, ref, a),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _PlanAction.regenerate, child: Text('Regenerate')),
        PopupMenuItem(value: _PlanAction.delete, child: Text('Delete plan')),
      ],
    );
  }
}
