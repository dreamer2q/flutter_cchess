import 'dart:math' as math;

import 'ai_strength.dart';

/// Allocates only a fraction of the remaining clock, leaving time for later
/// moves. The configured value is a strength preference, not a hard deadline.
int aiTimeBudgetMs({
  required AiStrength strength,
  required int configuredThinkMs,
  required int remainingMs,
  required bool timedGame,
}) {
  final configured = AiStrength.clampThinkMs(configuredThinkMs);
  if (!timedGame) return configured;
  if (remainingMs <= 0) return 1;

  final fraction = switch (strength) {
    AiStrength.easy => 0.08,
    AiStrength.normal => 0.35,
    AiStrength.hard => 1.0,
  };
  final desired =
      (remainingMs / 30 * fraction * configured / strength.maxThinkMs).round();
  final clockReserve = math.max(1, remainingMs - 250);
  return desired.clamp(1, math.min(90000, clockReserve)).toInt();
}
