import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/theme/motion_spec.dart';

class AnimatedInvalidMove extends StatelessWidget {
  const AnimatedInvalidMove({
    Key? key,
    required this.begin,
    required this.end,
    required this.child,
    this.duration = MotionSpec.invalidMove,
    this.onEnd,
  }) : super(key: key);

  final Alignment begin;
  final Alignment end;
  final Duration duration;
  final Widget child;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MotionSpec.reducedMotionOf(context);
    return TweenAnimationBuilder<double>(
      onEnd: onEnd,
      tween: Tween<double>(begin: 0, end: 1),
      duration: MotionSpec.durationOf(context, duration),
      builder: (BuildContext context, double value, Widget? child) {
        return Align(
          alignment: begin,
          child: Transform.translate(
            offset: Offset(
              reducedMotion
                  ? 0
                  : _shakeOffset(value) * MotionSpec.invalidShakeDistance,
              0,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// A short, damped shake that always starts and finishes at the source.
  static double _shakeOffset(double t) {
    const values = <double>[0, 1, -1, .7, -.7, 0];
    final scaled = t.clamp(0.0, 1.0) * (values.length - 1);
    final index = scaled.floor().clamp(0, values.length - 2);
    final localT = scaled - index;
    return values[index] + (values[index + 1] - values[index]) * localT;
  }
}

/// Retained for source compatibility. Invalid moves no longer travel toward
/// their attempted destination; use [AnimatedInvalidMove] for visible feedback.
@Deprecated('Invalid moves now shake at their source square')
class InvalidMoveTween extends Tween<Alignment> {
  InvalidMoveTween({Alignment? begin, Alignment? end})
      : super(begin: begin, end: end);

  @override
  Alignment transform(double t) => begin!;
}
