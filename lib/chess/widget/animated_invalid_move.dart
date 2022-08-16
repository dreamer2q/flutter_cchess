import 'package:flutter/material.dart';

class AnimatedInvalidMove extends StatelessWidget {
  const AnimatedInvalidMove({
    Key? key,
    required this.begin,
    required this.end,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
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
      curve: Curves.linearToEaseOut,
      tween: InvalidMoveTween(begin: begin, end: end),
      duration: duration,
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

class InvalidMoveTween extends Tween<Alignment> {
  InvalidMoveTween({Alignment? begin, Alignment? end})
      : super(begin: begin, end: end);

  @override
  Alignment transform(double t) {
    if (t == 0.0 || t == 1.0) return begin!;
    t -= 0.5;
    t = 1 - 4 * t * t;
    return super.lerp(t);
  }
}
