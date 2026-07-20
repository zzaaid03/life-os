/// Animated task checkbox.
///
/// A custom circular checkbox that animates from empty to filled
/// with a subtle scale animation when tapped.
library;

import 'package:flutter/material.dart';

/// A premium animated checkbox for task completion.
class TaskCheckbox extends StatelessWidget {
  /// Creates a [TaskCheckbox].
  const TaskCheckbox({super.key, required this.value, required this.onChanged});

  /// Whether the checkbox is checked (task completed).
  final bool value;

  /// Called when the checkbox is tapped.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: value ? 'Mark as incomplete' : 'Mark as complete',
      button: true,
      checked: value,
      child: GestureDetector(
        onTap: onChanged != null ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: value
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: value
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: colorScheme.onPrimary,
                    key: const ValueKey('check'),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      ),
    );
  }
}
