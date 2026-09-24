import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/theme/motion_spec.dart';

/// Fades and compresses a captured piece while the attacker lands.
class AnimatedCapturedPiece extends StatelessWidget {
  const AnimatedCapturedPiece({
    super.key,
    required this.child,
    this.duration = MotionSpec.capture,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: MotionSpec.durationOf(context, duration),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: .35 + (.65 * value),
        child: Transform.scale(scale: .88 + (.12 * value), child: child),
      ),
    );
  }
}
