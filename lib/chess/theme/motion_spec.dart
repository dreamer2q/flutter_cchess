import 'package:flutter/material.dart';

/// Shared motion timings and accessibility behavior for the chess board.
abstract class MotionSpec {
  static const Duration legalMove = Duration(milliseconds: 220);
  static const Duration capture = Duration(milliseconds: 240);
  static const Duration invalidMove = Duration(milliseconds: 180);
  static const Duration overlayFeedback = Duration(milliseconds: 520);

  static const double invalidShakeDistance = 5;
  static const Curve legalMoveCurve = Curves.easeOutCubic;

  static bool reducedMotionOf(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration durationOf(BuildContext context, Duration duration) =>
      reducedMotionOf(context) ? Duration.zero : duration;
}
