/// The circular progress ring shared by the step card and the timers bar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:life_os/features/recipes/domain/cook_timers.dart';

/// Time left at [now], rounded UP to the whole second, so the display reads
/// "0:01" until the timer really runs out instead of sitting on "0:00".
Duration displayRemaining(CookTimer timer, DateTime now) {
  final ms = timer.remaining(now).inMilliseconds;
  return Duration(seconds: (ms / 1000).ceil());
}

/// Tabular digits, so the numbers do not jiggle as they count down.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

/// A ring that fills as [timer] runs. While running it repaints every frame
/// from `timer.progress(DateTime.now())`, so it glides between the clock's
/// one-second ticks instead of jumping. Empty when [timer] is null.
class TimerRing extends StatefulWidget {
  /// Creates a [TimerRing].
  const TimerRing({
    super.key,
    required this.timer,
    required this.size,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
    this.child,
  });

  /// The timer to show, or null for a not-started (empty) ring.
  final CookTimer? timer;

  /// Diameter.
  final double size;

  /// Ring thickness.
  final double strokeWidth;

  /// Filled part.
  final Color color;

  /// Unfilled part.
  final Color trackColor;

  /// Drawn in the middle.
  final Widget? child;

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _progress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _sample());
    _sync();
  }

  @override
  void didUpdateWidget(TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sample() {
    final t = widget.timer;
    _progress.value = t == null ? 0 : t.progress(DateTime.now());
  }

  void _sync() {
    _sample();
    final running = widget.timer?.isRunning ?? false;
    if (running && !_ticker.isActive) {
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RingPainter(
            progress: _progress,
            color: widget.color,
            trackColor: widget.trackColor,
            strokeWidth: widget.strokeWidth,
          ),
          child: widget.child == null ? null : Center(child: widget.child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  }) : super(repaint: progress);

  final ValueNotifier<double> progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(inset, 0, math.pi * 2, false, track);

    final value = progress.value.clamp(0.0, 1.0);
    if (value <= 0) return;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.progress != progress;
}
