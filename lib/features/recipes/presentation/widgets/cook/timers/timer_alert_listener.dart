/// Alerts when a cook timer runs out.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/domain/cook_timers.dart';

/// Wraps the cook screen. While mounted, listens to
/// `cookTimersProvider.notifier.onFinished` and, for each timer of
/// [recipeTitle] that runs out: plays haptics and an alert sound, shows a
/// prominent alert with "+1 min" and "Done", and calls [onAnnounce] with a
/// short sentence (e.g. "Simmer sauce is done") so the screen can speak it.
class TimerAlertListener extends ConsumerStatefulWidget {
  /// Creates a [TimerAlertListener].
  const TimerAlertListener({
    super.key,
    required this.recipeTitle,
    required this.child,
    this.onAnnounce,
  });

  /// Only this recipe's timers alert here.
  final String recipeTitle;

  /// The cook screen.
  final Widget child;

  /// Receives a sentence to read aloud, if read-aloud is on.
  final ValueChanged<String>? onAnnounce;

  @override
  ConsumerState<TimerAlertListener> createState() => _TimerAlertListenerState();
}

class _TimerAlertListenerState extends ConsumerState<TimerAlertListener> {
  StreamSubscription<CookTimer>? _sub;

  /// Timer ids waiting for their alert. One dialog at a time.
  final Queue<int> _queue = Queue();
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(cookTimersProvider.notifier).onFinished.listen(_onFinished);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onFinished(CookTimer t) {
    if (!mounted || t.recipeTitle != widget.recipeTitle) return;
    unawaited(_buzz());
    widget.onAnnounce?.call('${t.label} is done');
    if (!_queue.contains(t.id)) _queue.add(t.id);
    _pump();
  }

  Future<void> _buzz() async {
    for (var i = 0; i < 3; i++) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {
        // Not every platform has haptics.
      }
      if (i < 2) await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Not every platform has system sounds.
    }
  }

  Future<void> _pump() async {
    if (_showing || !mounted) return;
    while (_queue.isNotEmpty && mounted) {
      final id = _queue.removeFirst();
      final timer = ref.read(cookTimersProvider).where((t) => t.id == id).firstOrNull;
      // Already handled elsewhere (dismissed on the card, or time added).
      if (timer == null || !timer.finished) continue;
      _showing = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _TimerDoneDialog(timerId: id, label: timer.label),
      );
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The "<label> is done" alert. Closes itself if the timer stops being
/// finished some other way (dismissed on the card, or time added there).
class _TimerDoneDialog extends ConsumerStatefulWidget {
  const _TimerDoneDialog({required this.timerId, required this.label});

  final int timerId;
  final String label;

  @override
  ConsumerState<_TimerDoneDialog> createState() => _TimerDoneDialogState();
}

class _TimerDoneDialogState extends ConsumerState<_TimerDoneDialog> {
  bool _closed = false;

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<CookTimer>>(cookTimersProvider, (_, next) {
      final t = next.where((x) => x.id == widget.timerId).firstOrNull;
      if (t == null || !t.finished) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _close());
      }
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(cookTimersProvider.notifier);
    final buttonText = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xxl)),
        side: BorderSide(color: scheme.error, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏰', style: TextStyle(fontSize: 88))
                .animate(onPlay: (c) => c.repeat())
                .shake(hz: 6, rotation: 0.12, duration: 800.ms)
                .then(delay: 400.ms),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${widget.label} is done',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      notifier.addTime(widget.timerId, 60);
                      _close();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('+1 min'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      textStyle: buttonText,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      notifier.dismiss(widget.timerId);
                      _close();
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Done'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      textStyle: buttonText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 150.ms).scaleXY(begin: 0.9, end: 1, curve: Curves.easeOutBack);
  }
}
