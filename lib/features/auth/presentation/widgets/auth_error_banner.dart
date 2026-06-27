/// Reusable authentication error banner.
///
/// Displays a styled error message with consistent
/// visual treatment across all auth screens.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_icons.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A styled error banner for authentication errors.
///
/// Use this instead of raw [Container] widgets for
/// consistent error display throughout auth screens.
class AuthErrorBanner extends StatelessWidget {
  /// Creates an [AuthErrorBanner].
  const AuthErrorBanner({super.key, required this.message});

  /// The error message to display.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.error, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
