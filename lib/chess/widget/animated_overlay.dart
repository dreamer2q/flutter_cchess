import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/theme/motion_spec.dart';

class AnimatedOverlay extends StatefulWidget {
  static show({
    required BuildContext context,
    required Widget child,
  }) {
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => AnimatedOverlay(
        child: child,
        duration: MotionSpec.overlayFeedback,
        onEnd: () => entry?.remove(),
      ),
    );

    Overlay.of(context).insert(entry);
  }

  const AnimatedOverlay({
    super.key,
    required this.child,
    this.duration = MotionSpec.overlayFeedback,
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
  bool _started = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animationController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (!_completed) {
          _completed = true;
          widget.onEnd?.call();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveDuration = MotionSpec.durationOf(context, widget.duration);
    _animationController.duration = effectiveDuration;
    if (!_started) {
      _started = true;
      _animationController.forward();
    } else if (effectiveDuration == Duration.zero && !_completed) {
      _animationController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _animationController.duration =
          MotionSpec.durationOf(context, widget.duration);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 50),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_animationController);
    final scale = Tween<double>(begin: .94, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, .35, curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: Align(
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: const TextStyle(),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
