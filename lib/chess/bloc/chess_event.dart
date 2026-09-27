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
    this.timeControlSeconds = 900,
    this.redElapsedMs = 0,
    this.blackElapsedMs = 0,
    this.aiStrength = AiStrength.normal,
    this.redAiStrength,
    this.blackAiStrength,
    this.aiMaxDepth,
    this.aiMaxThinkMs,
    this.redAiMaxDepth,
    this.blackAiMaxDepth,
    this.aiVsAiStepDelayMs = 0,
    this.openingBookLines = const [],
  });
  final Board initialBoard;
  final PlayMode playMode;
  final int timeControlSeconds;
  final int redElapsedMs;
  final int blackElapsedMs;
  final AiStrength aiStrength;
  final AiStrength? redAiStrength;
  final AiStrength? blackAiStrength;
  final int? aiMaxDepth;
  final int? aiMaxThinkMs;
  final int? redAiMaxDepth;
  final int? blackAiMaxDepth;
  final int aiVsAiStepDelayMs;
  final List<List<int>> openingBookLines;
  int get resolvedAiMaxDepth => aiMaxDepth ?? aiStrength.maxDepth;
  int get resolvedAiMaxThinkMs => aiMaxThinkMs ?? aiStrength.maxThinkMs;
  @override
  List<Object?> get props => [
    initialBoard,
    playMode,
    timeControlSeconds,
    redElapsedMs,
    blackElapsedMs,
    aiStrength,
    redAiStrength,
    blackAiStrength,
    aiMaxDepth,
    aiMaxThinkMs,
    redAiMaxDepth,
    blackAiMaxDepth,
    aiVsAiStepDelayMs,
    openingBookLines,
  ];
}

class ChessEventAiSettingsChanged extends ChessEvent {
  const ChessEventAiSettingsChanged({
    required this.aiStrength,
    required this.aiMaxDepth,
    required this.aiMaxThinkMs,
  });

  final AiStrength aiStrength;
  final int aiMaxDepth;
  final int aiMaxThinkMs;

  @override
  List<Object?> get props => [aiStrength, aiMaxDepth, aiMaxThinkMs];
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

class _ChessEventClockTick extends ChessEvent {
  const _ChessEventClockTick();
}
