import 'package:flutter_cchess/chess/game/game_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('charges only the active side and preserves fractional seconds', () {
    var now = 0;
    final clock = GameClock(timeControlSeconds: 900, nowMs: () => now);
    clock.start(0);
    now = 1250;
    expect(clock.snapshot.redElapsedMs, 1250);
    expect(clock.snapshot.remainingSeconds(0, 900), 899);
    expect(clock.snapshot.blackElapsedMs, 0);

    clock.start(1);
    now = 2300;
    expect(clock.snapshot.redElapsedMs, 1250);
    expect(clock.snapshot.blackElapsedMs, 1050);

    clock.stop();
    now = 10000;
    expect(clock.snapshot.blackElapsedMs, 1050);
    clock.start(1);
    now = 11000;
    expect(clock.snapshot.blackElapsedMs, 2050);
  });

  test('restores elapsed time and detects a side timeout', () {
    var now = 2000;
    final clock = GameClock(
      timeControlSeconds: 300,
      redElapsedMs: 299500,
      blackElapsedMs: 2000,
      nowMs: () => now,
    );
    clock.start(0);
    now = 2499;
    expect(clock.isExpired(0), isFalse);
    now = 2500;
    expect(clock.isExpired(0), isTrue);
    expect(clock.snapshot.remainingSeconds(0, 300), 0);
    expect(clock.isExpired(1), isFalse);
  });

  test('unlimited games never run down', () {
    var now = 0;
    final clock = GameClock(timeControlSeconds: 0, nowMs: () => now);
    clock.start(0);
    now = 900000;
    expect(clock.snapshot.redElapsedMs, 0);
    expect(clock.isExpired(0), isFalse);
  });
}
