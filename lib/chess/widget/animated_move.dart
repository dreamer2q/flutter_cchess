import 'package:flutter/material.dart';

class AnimatedMove extends StatelessWidget {
  const AnimatedMove({
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
      tween: AlignmentTween(begin: begin, end: end),
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
