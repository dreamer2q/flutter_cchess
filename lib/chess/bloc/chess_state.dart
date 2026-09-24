part of 'chess_bloc.dart';

enum GamePhase { loading, playerTurn, aiThinking, paused, finished, failure }

enum PlaySide { red, black }

enum PlayMode { withSelf, withAI, withNetwork }

enum PlayEffect { eat, check, mate }

enum PlayStatus { draw, win, lose }

enum PresentationEffectKind { move, invalidMove, undo }

enum PresentationStage { animating, feedback }

enum PersistenceStatus { idle, saving, saved, failed }

class PresentationEffect extends Equatable {
  const PresentationEffect({
    required this.id,
    required this.kind,
    required this.beforeBoard,
    required this.afterBoard,
    required this.move,
    this.movingPiece,
    this.capturedPiece,
    this.tacticalEffect,
    this.stage = PresentationStage.animating,
  });
  final int id;
  final PresentationEffectKind kind;
  final Board beforeBoard;
  final Board afterBoard;
  final MovePos move;
  final ChessPiece? movingPiece;
  final ChessPiece? capturedPiece;
  final PlayEffect? tacticalEffect;
  final PresentationStage stage;
  bool get isTerminal => tacticalEffect == PlayEffect.mate;

  PresentationEffect copyWith({PresentationStage? stage}) => PresentationEffect(
    id: id,
    kind: kind,
    beforeBoard: beforeBoard,
    afterBoard: afterBoard,
    move: move,
    movingPiece: movingPiece,
    capturedPiece: capturedPiece,
    tacticalEffect: tacticalEffect,
    stage: stage ?? this.stage,
  );
  @override
  List<Object?> get props => [
    id,
    kind,
    beforeBoard,
    afterBoard,
    move,
    movingPiece,
    capturedPiece,
    tacticalEffect,
    stage,
  ];
}

class ChessState extends Equatable {
  ChessState({
    required this.board,
    this.selected,
    BuiltList<MovePos>? selectedMoves,
    BuiltList<MovePos>? hintMoves,
    BuiltList<PresentationEffect>? presentations,
    this.phase = GamePhase.loading,
    this.playMode = PlayMode.withAI,
    this.playSide = PlaySide.red,
    this.playStatus,
    this.winningSide,
    this.lastMove,
    this.failureMessage,
    this.persistenceStatus = PersistenceStatus.idle,
    this.boardFlipped = false,
  }) : selectedMoves = selectedMoves ?? BuiltList<MovePos>(),
       hintMoves = hintMoves ?? BuiltList<MovePos>(),
       presentations = presentations ?? BuiltList<PresentationEffect>();

  final Board board;
  final PiecePair? selected;
  final BuiltList<MovePos> selectedMoves;
  final GamePhase phase;
  final PlayMode playMode;
  final PlaySide playSide;
  final BuiltList<MovePos> hintMoves;
  final PlayStatus? playStatus;
  final PlaySide? winningSide;
  final MovePos? lastMove;
  final BuiltList<PresentationEffect> presentations;
  final String? failureMessage;
  final PersistenceStatus persistenceStatus;
  final bool boardFlipped;

  PresentationEffect? get activePresentation =>
      presentations.isEmpty ? null : presentations.first;
  bool get isPlayerTurn =>
      playMode == PlayMode.withSelf || board.isTurn(playSide);
  bool get canInteractBoard =>
      phase == GamePhase.playerTurn && presentations.isEmpty && isPlayerTurn;
  bool get canUndo =>
      phase == GamePhase.playerTurn &&
      presentations.isEmpty &&
      (playMode == PlayMode.withSelf
          ? board.lastMoves.isNotEmpty
          : board.lastMoves.length > 1 && board.isTurn(playSide));
  bool get canHint =>
      playMode == PlayMode.withAI &&
      phase == GamePhase.playerTurn &&
      presentations.isEmpty &&
      board.isTurn(playSide);
  bool get canPause =>
      phase != GamePhase.loading &&
      phase != GamePhase.paused &&
      phase != GamePhase.finished;
  bool get canResume => phase == GamePhase.paused;
  bool get canResign =>
      phase != GamePhase.loading && phase != GamePhase.finished;
  bool get canRetryAi =>
      phase == GamePhase.failure &&
      playMode == PlayMode.withAI &&
      !board.isTurn(playSide);
  bool get canFlip => phase != GamePhase.loading && presentations.isEmpty;

  ChessState copyWith({
    Board? board,
    PiecePair? selected,
    BuiltList<MovePos>? selectedMoves,
    GamePhase? phase,
    PlayMode? playMode,
    PlaySide? playSide,
    BuiltList<MovePos>? hintMoves,
    PlayStatus? playStatus,
    PlaySide? winningSide,
    MovePos? lastMove,
    BuiltList<PresentationEffect>? presentations,
    String? failureMessage,
    PersistenceStatus? persistenceStatus,
    bool? boardFlipped,
    bool clearSelected = false,
    bool clearHintMoves = false,
    bool clearLastMove = false,
    bool clearResult = false,
    bool clearFailure = false,
  }) {
    return ChessState(
      board: board ?? this.board,
      selected: clearSelected ? null : selected ?? this.selected,
      selectedMoves: clearSelected
          ? BuiltList<MovePos>()
          : selectedMoves ?? this.selectedMoves,
      phase: phase ?? this.phase,
      playMode: playMode ?? this.playMode,
      playSide: playSide ?? this.playSide,
      hintMoves: clearHintMoves
          ? BuiltList<MovePos>()
          : hintMoves ?? this.hintMoves,
      playStatus: clearResult ? null : playStatus ?? this.playStatus,
      winningSide: clearResult ? null : winningSide ?? this.winningSide,
      lastMove: clearLastMove ? null : lastMove ?? this.lastMove,
      presentations: presentations ?? this.presentations,
      failureMessage: clearFailure
          ? null
          : failureMessage ?? this.failureMessage,
      persistenceStatus: persistenceStatus ?? this.persistenceStatus,
      boardFlipped: boardFlipped ?? this.boardFlipped,
    );
  }

  @override
  List<Object?> get props => [
    board,
    selected,
    selectedMoves,
    phase,
    playMode,
    playSide,
    hintMoves,
    playStatus,
    winningSide,
    lastMove,
    presentations,
    failureMessage,
    persistenceStatus,
    boardFlipped,
  ];
}
