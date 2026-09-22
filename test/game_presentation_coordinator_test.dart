import 'package:built_collection/built_collection.dart';
import 'package:flutter_cchess/audio/audio.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/presentation/game_presentation_coordinator.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects side-specific highest semantic cue once per effect', () async {
    final service = _FakeAudioService();
    final haptics = <PresentationHapticKind>[];
    final coordinator = GamePresentationCoordinator(
      audioController: GameAudioController(service: service),
      haptic: haptics.add,
    );
    final board = Board(BuiltList<BoardAction>());
    final effect = PresentationEffect(
      id: 7,
      kind: PresentationEffectKind.move,
      beforeBoard: board,
      afterBoard: board,
      move: const MovePos(1, 2),
      movingPiece: const ChessPiece(20),
      capturedPiece: const ChessPiece(12),
    );
    final state = ChessState(board: board, phase: GamePhase.playerTurn);

    await coordinator.present(effect, state, hapticsEnabled: true);
    await coordinator.present(effect, state, hapticsEnabled: true);

    expect(service.played, [GameAudioCue.captureBlack]);
    expect(haptics, [PresentationHapticKind.medium]);
  });

  test('suspension prevents queued transient feedback', () async {
    final service = _FakeAudioService();
    final coordinator = GamePresentationCoordinator(
      audioController: GameAudioController(service: service),
    );
    final board = Board(BuiltList<BoardAction>());
    final effect = PresentationEffect(
      id: 9,
      kind: PresentationEffectKind.invalidMove,
      beforeBoard: board,
      afterBoard: board,
      move: const MovePos(1, 1),
    );

    await coordinator.suspend();
    await coordinator.present(
      effect,
      ChessState(board: board),
      hapticsEnabled: false,
    );
    expect(service.played, isEmpty);
    expect(service.stopCalls, 1);
  });
}

class _FakeAudioService implements AudioService {
  final List<GameAudioCue> played = <GameAudioCue>[];
  int stopCalls = 0;
  @override
  bool isEnabled = true;
  @override
  double volume = 1;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> play(GameAudioCue cue) async => played.add(cue);
  @override
  Future<void> setEnabled(bool enabled) async => isEnabled = enabled;
  @override
  Future<void> setVolume(double value) async => volume = value;
  @override
  Future<void> stopAll() async => stopCalls++;
}
