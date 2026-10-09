/// The segmented progress bar across the top of cook mode.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// One segment per page; every segment up to [current] is filled.
class CookProgressBar extends StatelessWidget {
  /// Creates a [CookProgressBar].
  const CookProgressBar({
    super.key,
    required this.count,
    required this.current,
    required this.fill,
    required this.track,
  });

  /// Number of pages.
  final int count;

  /// The page on screen.
  final int current;

  /// Filled colour.
  final Color fill;

  /// Unfilled colour.
  final Color track;

  @override
  Widget build(BuildContext context) {
    // Many steps squeeze the gaps so the bar still fits a narrow phone.
    final gap = count > 10 ? AppSpacing.xxs : AppSpacing.xs;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: track),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: i <= current ? 1 : 0,
                      child: ColoredBox(color: fill),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
