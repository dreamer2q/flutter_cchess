import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/theme/motion_spec.dart';

class AnimatedMove extends StatelessWidget {
  const AnimatedMove({
    Key? key,
    required this.begin,
    required this.end,
    required this.child,
    this.duration = MotionSpec.legalMove,
    this.onEnd,
  }) : super(key: key);

  final Alignment begin;
  final Alignment end;
  final Duration duration;
  final Widget child;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      onEnd: onEnd,
      curve: MotionSpec.legalMoveCurve,
      tween: AlignmentTween(begin: begin, end: end),
      duration: MotionSpec.durationOf(context, duration),
      builder: (BuildContext context, Alignment value, Widget? child) {
        return Align(
          alignment: value,
          child: child,
        );
      },
      child: child,
    );
  }
}
