import 'game_audio_cue.dart';

/// Platform audio boundary used by game audio orchestration.
///
/// The game and its BLoCs should depend on this interface instead of a player
/// plugin. That keeps cue selection deterministic and unit-testable.
abstract class AudioService {
  bool get isEnabled;

  double get volume;

  /// Preloads every bundled sound used by [GameAudioCue].
  Future<void> initialize();

  Future<void> play(GameAudioCue cue);

  /// Stops current sounds while keeping the service reusable.
  Future<void> stopAll();

  Future<void> setEnabled(bool enabled);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}
