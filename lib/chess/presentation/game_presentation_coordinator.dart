import 'dart:async';

import 'package:flutter_cchess/audio/audio.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';

typedef PresentationHaptic =
    FutureOr<void> Function(PresentationHapticKind kind);

enum PresentationHapticKind { light, medium, result }

/// Coordinates one-shot audio and haptic feedback for completed board effects.
///
/// Rules and animation timing remain in [ChessBloc] and the board widget. This
/// class only consumes the unique effect ID, so rebuilds and stale callbacks
/// cannot replay feedback.
class GamePresentationCoordinator {
  GamePresentationCoordinator({
    required GameAudioController audioController,
    PresentationHaptic? haptic,
  }) : _audioController = audioController,
       _haptic = haptic;

  final GameAudioController _audioController;
  final PresentationHaptic? _haptic;
  bool _suspended = false;

  Future<void> present(
    PresentationEffect effect,
    ChessState state, {
    required bool hapticsEnabled,
  }) async {
    if (_suspended) return;
    final cue = _cueFor(effect, state);
    final played = await _audioController.playForStep(
      stepId: effect.id,
      candidates: [cue],
    );
    if (played == null || !hapticsEnabled || _haptic == null) return;
    await _haptic(_hapticFor(effect, state));
  }

  Future<void> suspend() async {
    _suspended = true;
    await _audioController.stopAll();
  }

  void resume() => _suspended = false;

  GameAudioCue _cueFor(PresentationEffect effect, ChessState state) {
    if (effect.kind == PresentationEffectKind.invalidMove) {
      return GameAudioCue.illegalMove;
    }
    if (effect.isTerminal || state.phase == GamePhase.finished) {
      if (state.playStatus == PlayStatus.draw) return GameAudioCue.draw;
      if (state.playMode == PlayMode.withAI &&
          state.winningSide != state.playSide) {
        return GameAudioCue.loss;
      }
      return GameAudioCue.win;
    }
    final black = effect.movingPiece?.isRedSide() == false;
    if (effect.tacticalEffect == PlayEffect.check) {
      return black ? GameAudioCue.checkBlack : GameAudioCue.check;
    }
    if (effect.capturedPiece != null) {
      return black ? GameAudioCue.captureBlack : GameAudioCue.capture;
    }
    return black ? GameAudioCue.moveBlack : GameAudioCue.move;
  }

  PresentationHapticKind _hapticFor(
    PresentationEffect effect,
    ChessState state,
  ) {
    if (effect.isTerminal || state.phase == GamePhase.finished) {
      return PresentationHapticKind.result;
    }
    if (effect.kind == PresentationEffectKind.invalidMove) {
      return PresentationHapticKind.light;
    }
    if (effect.capturedPiece != null ||
        effect.tacticalEffect == PlayEffect.check) {
      return PresentationHapticKind.medium;
    }
    return PresentationHapticKind.light;
  }
}
