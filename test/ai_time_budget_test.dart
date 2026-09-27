import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/game/ai_time_budget.dart';

void main() {
  test(
    'a 15-minute clock gives strong AI time beyond the old five seconds',
    () {
      expect(
        aiTimeBudgetMs(
          strength: AiStrength.hard,
          configuredThinkMs: AiStrength.hard.maxThinkMs,
          remainingMs: 900000,
          timedGame: true,
        ),
        30000,
      );
    },
  );

  test('budget shrinks with the clock and leaves a deadline reserve', () {
    int budget(int remainingMs) => aiTimeBudgetMs(
      strength: AiStrength.hard,
      configuredThinkMs: AiStrength.hard.maxThinkMs,
      remainingMs: remainingMs,
      timedGame: true,
    );

    expect(budget(30000), 1000);
    expect(budget(1000), lessThanOrEqualTo(750));
    expect(budget(200), lessThan(200));
    expect(budget(0), 1);
  });

  test('custom strength scales clock budget; untimed uses configured time', () {
    expect(
      aiTimeBudgetMs(
        strength: AiStrength.hard,
        configuredThinkMs: 10000,
        remainingMs: 900000,
        timedGame: true,
      ),
      60000,
    );
    expect(
      aiTimeBudgetMs(
        strength: AiStrength.normal,
        configuredThinkMs: 1500,
        remainingMs: 900000,
        timedGame: false,
      ),
      1500,
    );
  });
}
