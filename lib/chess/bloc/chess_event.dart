part of 'chess_bloc.dart';

abstract class ChessEvent extends Equatable {
  const ChessEvent();
  @override
  List<Object?> get props => const [];
}

class ChessEventInitialized extends ChessEvent {
  const ChessEventInitialized({
    required this.initialBoard,
    this.playMode = PlayMode.withAI,
  });
  final Board initialBoard;
  final PlayMode playMode;
  @override
  List<Object?> get props => [initialBoard, playMode];
}

class ChessEventBoardTap extends ChessEvent {
  const ChessEventBoardTap(this.pos);
  final PiecePos pos;
  @override
  List<Object?> get props => [pos];
}

class ChessEventMoveRequested extends ChessEvent {
  const ChessEventMoveRequested(this.move);
  final MovePos move;
  @override
  List<Object?> get props => [move];
}

@Deprecated('Use ChessEventMoveRequested')
class ChessEventMoveBegin extends ChessEventMoveRequested {
  const ChessEventMoveBegin(super.move);
}

class ChessEventPresentationAcknowledged extends ChessEvent {
  const ChessEventPresentationAcknowledged(this.effectId);
  final int effectId;
  @override
  List<Object?> get props => [effectId];
}

class ChessEventPresentationAnimationCompleted extends ChessEvent {
  const ChessEventPresentationAnimationCompleted(this.effectId);
  final int effectId;
  @override
  List<Object?> get props => [effectId];
}

class ChessEventUndo extends ChessEvent {
  const ChessEventUndo();
}

class ChessEventGetHint extends ChessEvent {
  const ChessEventGetHint();
}

class ChessEventPause extends ChessEvent {
  const ChessEventPause();
}

class ChessEventResume extends ChessEvent {
  const ChessEventResume();
}

class ChessEventResign extends ChessEvent {
  const ChessEventResign();
}

class ChessEventRetryAi extends ChessEvent {
  const ChessEventRetryAi();
}

class ChessEventSwitchToLocal extends ChessEvent {
  const ChessEventSwitchToLocal();
}

class ChessEventFlipBoard extends ChessEvent {
  const ChessEventFlipBoard();
}

class ChessEventClearSelection extends ChessEvent {
  const ChessEventClearSelection();
}

class _ChessEventAiResolved extends ChessEvent {
  const _ChessEventAiResolved(this.generation, this.move, this.error);
  final int generation;
  final MovePos? move;
  final Object? error;
  @override
  List<Object?> get props => [generation, move, error];
}

class _ChessEventHintResolved extends ChessEvent {
  const _ChessEventHintResolved(this.generation, this.move, this.error);
  final int generation;
  final MovePos? move;
  final Object? error;
  @override
  List<Object?> get props => [generation, move, error];
}

class _ChessEventPersistenceCompleted extends ChessEvent {
  const _ChessEventPersistenceCompleted(this.revision, this.error);
  final int revision;
  final Object? error;
  @override
  List<Object?> get props => [revision, error];
}

class _ChessEventPersistenceStarted extends ChessEvent {
  const _ChessEventPersistenceStarted(this.revision);
  final int revision;
  @override
  List<Object?> get props => [revision];
}
