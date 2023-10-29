import 'package:flutter/material.dart';

class AnimatedOverlay extends StatefulWidget {
  static show({
    required BuildContext context,
    required Widget child,
  }) {
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => AnimatedOverlay(
        child: child,
        duration: Duration(milliseconds: 300),
        onEnd: () => entry?.remove(),
      ),
    );

    Overlay.of(context).insert(entry);
  }

  const AnimatedOverlay({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 1),
    this.onEnd,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback? onEnd;

  @override
  State<AnimatedOverlay> createState() => _AnimatedOverlayState();
}

class _AnimatedOverlayState extends State<AnimatedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animationController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.onEnd?.call();
      }
    });

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style: TextStyle(),
        child: widget.child,
      ),
    );
  }
}
