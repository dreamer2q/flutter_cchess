import 'dart:math' as math;

/// Central responsive policy shared by the game shell and its tests.
abstract class GameLayoutPolicy {
  static const double desktopBreakpoint = 860;
  static const double minimumDesktopHeight = 620;
  static const double minimumInspectorWidth = 280;
  static const double maximumInspectorWidth = 340;

  static bool useDesktop(double width, double height) =>
      width >= desktopBreakpoint && height >= minimumDesktopHeight;

  static double inspectorWidth(double availableWidth) => math.min(
    maximumInspectorWidth,
    math.max(minimumInspectorWidth, availableWidth * .27),
  );
}
