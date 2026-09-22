/// A semantic sound emitted by the offline game.
///
/// Asset paths are relative to Flutter's `assets/` directory because that is
/// the prefix used by audioplayers' [AssetSource].
enum GameAudioCue {
  uiClick(priority: 20, assetPath: 'sounds/click.wav'),
  newGame(priority: 40, assetPath: 'sounds/newgame.wav'),
  illegalMove(priority: 50, assetPath: 'sounds/illegal.wav'),
  move(priority: 60, assetPath: 'sounds/move.wav'),
  capture(priority: 70, assetPath: 'sounds/capture.wav'),
  check(priority: 80, assetPath: 'sounds/check.wav'),
  win(priority: 100, assetPath: 'sounds/win.wav'),
  loss(priority: 100, assetPath: 'sounds/loss.wav'),
  draw(priority: 100, assetPath: 'sounds/draw.wav');

  const GameAudioCue({required this.priority, required this.assetPath});

  final int priority;
  final String assetPath;

  bool get isTerminal =>
      this == GameAudioCue.win ||
      this == GameAudioCue.loss ||
      this == GameAudioCue.draw;

  /// Picks one sound for a game step.
  ///
  /// Callers should pass every semantic candidate for the step. For example,
  /// a capturing move that gives check should pass move, capture, and check;
  /// only check will be returned.
  static GameAudioCue? highestPriority(Iterable<GameAudioCue> candidates) {
    GameAudioCue? selected;
    for (final candidate in candidates) {
      if (selected == null || candidate.priority > selected.priority) {
        selected = candidate;
      }
    }
    return selected;
  }
}
