import 'dart:math' as math;

class GameClockSnapshot {
  const GameClockSnapshot({
    required this.redElapsedMs,
    required this.blackElapsedMs,
  });

  final int redElapsedMs;
  final int blackElapsedMs;

  int elapsedFor(int side) => side == 0 ? redElapsedMs : blackElapsedMs;

  int remainingSeconds(int side, int timeControlSeconds) {
    if (timeControlSeconds == 0) return 0;
    final remainingMs = math.max(
      0,
      timeControlSeconds * 1000 - elapsedFor(side),
    );
    return (remainingMs + 999) ~/ 1000;
  }
}

class GameClock {
  GameClock({
    required this.timeControlSeconds,
    required int Function() nowMs,
    int redElapsedMs = 0,
    int blackElapsedMs = 0,
  }) : _nowMs = nowMs,
       _redElapsedMs = redElapsedMs,
       _blackElapsedMs = blackElapsedMs;

  final int timeControlSeconds;
  final int Function() _nowMs;
  int _redElapsedMs;
  int _blackElapsedMs;
  int? _activeSide;
  int? _startedAtMs;

  int? get activeSide => _activeSide;

  GameClockSnapshot get snapshot {
    final delta = _startedAtMs == null
        ? 0
        : math.max(0, _nowMs() - _startedAtMs!);
    return GameClockSnapshot(
      redElapsedMs: _redElapsedMs + (_activeSide == 0 ? delta : 0),
      blackElapsedMs: _blackElapsedMs + (_activeSide == 1 ? delta : 0),
    );
  }

  bool isExpired(int side) =>
      timeControlSeconds > 0 &&
      snapshot.elapsedFor(side) >= timeControlSeconds * 1000;

  void start(int side) {
    stop();
    if (timeControlSeconds == 0) return;
    _activeSide = side;
    _startedAtMs = _nowMs();
  }

  void stop() {
    final current = snapshot;
    _redElapsedMs = current.redElapsedMs;
    _blackElapsedMs = current.blackElapsedMs;
    _activeSide = null;
    _startedAtMs = null;
  }
}
