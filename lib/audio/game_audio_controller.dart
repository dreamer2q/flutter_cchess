import 'dart:collection';

import 'audio_service.dart';
import 'game_audio_cue.dart';

typedef GameAudioClock = DateTime Function();

/// Selects and de-duplicates semantic game sounds before playback.
class GameAudioController {
  GameAudioController({
    required AudioService service,
    Duration deduplicationWindow = const Duration(milliseconds: 80),
    GameAudioClock? clock,
    int rememberedSteps = 128,
  }) : assert(!deduplicationWindow.isNegative),
       assert(rememberedSteps > 0),
       _service = service,
       _deduplicationWindow = deduplicationWindow,
       _clock = clock ?? _monotonicNow,
       _rememberedSteps = rememberedSteps;

  static final Stopwatch _stopwatch = Stopwatch()..start();

  static DateTime _monotonicNow() => DateTime.fromMillisecondsSinceEpoch(
    _stopwatch.elapsedMilliseconds,
    isUtc: true,
  );

  final AudioService _service;
  final Duration _deduplicationWindow;
  final GameAudioClock _clock;
  final int _rememberedSteps;
  final LinkedHashSet<Object> _playedSteps = LinkedHashSet<Object>();
  final Map<GameAudioCue, DateTime> _lastPlayedAt = {};

  bool _disposed = false;

  /// Plays exactly one cue for [stepId], choosing the highest priority from
  /// [candidates]. A step identifier should be unique within a game.
  Future<GameAudioCue?> playForStep({
    required Object stepId,
    required Iterable<GameAudioCue> candidates,
  }) async {
    _ensureNotDisposed();
    if (_playedSteps.contains(stepId)) return null;

    final cue = GameAudioCue.highestPriority(candidates);
    if (cue == null) return null;

    _rememberStep(stepId);
    return _playIfNotDuplicate(cue);
  }

  /// Plays a cue that is not tied to a move, such as a UI click.
  Future<GameAudioCue?> play(GameAudioCue cue) {
    _ensureNotDisposed();
    return _playIfNotDuplicate(cue);
  }

  Future<GameAudioCue?> _playIfNotDuplicate(GameAudioCue cue) async {
    final now = _clock();
    final previous = _lastPlayedAt[cue];
    if (previous != null) {
      final elapsed = now.difference(previous);
      if (!elapsed.isNegative && elapsed < _deduplicationWindow) {
        return null;
      }
    }

    _lastPlayedAt[cue] = now;
    await _service.play(cue);
    return cue;
  }

  void _rememberStep(Object stepId) {
    _playedSteps.add(stepId);
    while (_playedSteps.length > _rememberedSteps) {
      _playedSteps.remove(_playedSteps.first);
    }
  }

  /// Stops current audio for a lifecycle pause.
  ///
  /// Played step identifiers remain recorded so rebuilding the same game state
  /// after resume cannot replay an earlier move sound.
  Future<void> stopAll() async {
    _ensureNotDisposed();
    await _service.stopAll();
  }

  /// Stops audio and clears semantic history before starting another game.
  Future<void> resetForNewGame() async {
    _ensureNotDisposed();
    _playedSteps.clear();
    _lastPlayedAt.clear();
    await _service.stopAll();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playedSteps.clear();
    _lastPlayedAt.clear();
    await _service.dispose();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('GameAudioController has been disposed.');
    }
  }
}
