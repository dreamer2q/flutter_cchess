import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:built_collection/built_collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/chess/game/game.dart';
import 'package:flutter_cchess/chess/game/game_clock.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/fen.dart';

part 'chess_event.dart';
part 'chess_state.dart';

class ChessBloc extends Bloc<ChessEvent, ChessState> {
  ChessBloc({
    required this.ticker,
    this.repository,
    this.initialFen = initialFenString,
    ChessEnginePort? engine,
    ChessEnginePort? analysisEngine,
    int Function()? clockNowMs,
    String? gameId,
    DateTime? createdAt,
  }) : _providedEngine = engine,
       _providedAnalysisEngine = analysisEngine,
       _clockNowMs = clockNowMs,
       gameId = gameId ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       super(ChessState(board: Board(BuiltList<BoardAction>()))) {
    on<ChessEventInitialized>(_onInitialized);
    on<ChessEventAiSettingsChanged>(_onAiSettingsChanged);
    on<ChessEventBoardTap>(_onBoardTapped);
    on<ChessEventMoveRequested>(_onMoveRequested);
    on<ChessEventPresentationAcknowledged>(_onPresentationAcknowledged);
    on<ChessEventPresentationAnimationCompleted>(
      _onPresentationAnimationCompleted,
    );
    on<ChessEventUndo>(_onUndo);
    on<ChessEventGetHint>(_onGetHint);
    on<ChessEventEvaluatePosition>(_onEvaluatePosition);
    on<ChessEventPause>(_onPaused);
    on<ChessEventResume>(_onResumed);
    on<ChessEventResign>(_onResigned);
    on<ChessEventRetryAi>(_onRetryAi);
    on<ChessEventSwitchToLocal>(_onSwitchToLocal);
    on<ChessEventFlipBoard>(_onFlipBoard);
    on<ChessEventClearSelection>(_onClearSelection);
    on<_ChessEventAiResolved>(_onAiResolved);
    on<_ChessEventHintResolved>(_onHintResolved);
    on<_ChessEventEvaluationResolved>(_onEvaluationResolved);
    on<_ChessEventPersistenceCompleted>(_onPersistenceCompleted);
    on<_ChessEventPersistenceStarted>(_onPersistenceStarted);
    on<_ChessEventClockTick>(_onClockTick);
  }

  final Ticker ticker;
  final GameRepository? repository;
  final String initialFen;
  final ChessEnginePort? _providedEngine;
  final ChessEnginePort? _providedAnalysisEngine;
  final int Function()? _clockNowMs;
  final Stopwatch _monotonic = Stopwatch()..start();
  final String gameId;
  final DateTime createdAt;

  ChessEnginePort? _engine;
  ChessEnginePort? _analysisEngine;
  int _taskGeneration = 0;
  int _evaluationGeneration = 0;
  int _effectSequence = 0;
  int _persistenceRevision = 0;
  bool _aiVsAiSearchPending = false;
  Future<void> _saveTail = Future<void>.value();
  GameClock? _clock;
  StreamSubscription<int>? _clockTicks;
  int _lastClockPersistBucket = 0;

  int get _nowMs => _clockNowMs?.call() ?? _monotonic.elapsedMilliseconds;

  GameClockSnapshot get _clockSnapshot =>
      _clock?.snapshot ??
      GameClockSnapshot(
        redElapsedMs: state.redElapsedMs,
        blackElapsedMs: state.blackElapsedMs,
      );

  int _aiBudget(AiStrength strength, int configuredThinkMs, {int? side}) {
    final aiSide = side ?? state.board.innerBoard.sdPlayer;
    final remaining =
        state.timeControlSeconds * 1000 - _clockSnapshot.elapsedFor(aiSide);
    return aiTimeBudgetMs(
      strength: strength,
      configuredThinkMs: configuredThinkMs,
      remainingMs: remaining,
      timedGame: state.timeControlSeconds > 0,
    );
  }

  void _startPonder() {
    if (state.playMode != PlayMode.withAI ||
        state.phase != GamePhase.playerTurn ||
        _engine == null) {
      return;
    }
    final board = state.board.innerBoard;
    _engine!.startPonder(
      squares: List<int>.from(board.ucpcSquares),
      sideToMove: board.sdPlayer,
      maxDepth: state.aiMaxDepth,
      maxThinkMs: _aiBudget(
        state.aiStrength,
        state.aiMaxThinkMs,
        side: 1 - board.sdPlayer,
      ),
    );
  }

  Future<void> _onInitialized(
    ChessEventInitialized event,
    Emitter<ChessState> emit,
  ) async {
    _taskGeneration++;
    _evaluationGeneration++;
    _aiVsAiSearchPending = false;
    emit(
      state.copyWith(
        timeControlSeconds: event.timeControlSeconds,
        redElapsedMs: event.redElapsedMs,
        blackElapsedMs: event.blackElapsedMs,
        aiStrength: event.aiStrength,
        aiMaxDepth: event.resolvedAiMaxDepth,
        aiMaxThinkMs: event.resolvedAiMaxThinkMs,
        clearAiEvaluation: true,
        redAiMaxDepth:
            event.redAiMaxDepth ??
            (event.playMode == PlayMode.withAIvsAI
                ? (event.redAiStrength ?? event.aiStrength).maxDepth
                : event.resolvedAiMaxDepth),
        blackAiMaxDepth:
            event.blackAiMaxDepth ??
            (event.playMode == PlayMode.withAIvsAI
                ? (event.blackAiStrength ?? event.aiStrength).maxDepth
                : event.resolvedAiMaxDepth),
        aiVsAiStepDelayMs: event.aiVsAiStepDelayMs,
      ),
    );
    try {
      switch (event.playMode) {
        case PlayMode.withAI:
          _engine = _providedEngine ?? ChessEngine();
          await _engine!.setOpeningBook(event.openingBookLines);
          await _engine!.setStrength(
            event.aiStrength,
            maxDepth: event.resolvedAiMaxDepth,
            maxThinkMs: event.resolvedAiMaxThinkMs,
          );
          await _engine!.restore(event.initialBoard.lastMoves.map((m) => m.mv));
          break;
        case PlayMode.withAIvsAI:
          _engine = _providedEngine ?? ChessEngine();
          await _engine!.setOpeningBook(event.openingBookLines);
          await _engine!.setStrength(
            event.aiStrength,
            maxDepth: event.resolvedAiMaxDepth,
            maxThinkMs: event.resolvedAiMaxThinkMs,
          );
          await _engine!.restore(event.initialBoard.lastMoves.map((m) => m.mv));
          break;
        case PlayMode.withSelf:
          _engine = null;
          break;
        case PlayMode.withNetwork:
          throw UnsupportedError('Network play is outside the offline app.');
      }

      final aiTurn =
          event.playMode == PlayMode.withAIvsAI ||
          (event.playMode == PlayMode.withAI &&
              !event.initialBoard.isTurn(PlaySide.red));
      _clock = GameClock(
        timeControlSeconds: event.timeControlSeconds,
        redElapsedMs: event.redElapsedMs,
        blackElapsedMs: event.blackElapsedMs,
        nowMs: () => _nowMs,
      );
      _lastClockPersistBucket =
          (event.redElapsedMs + event.blackElapsedMs) ~/ 10000;
      emit(
        state.copyWith(
          board: event.initialBoard,
          playMode: event.playMode,
          phase: aiTurn ? GamePhase.aiThinking : GamePhase.playerTurn,
          presentations: BuiltList<PresentationEffect>(),
          lastMove: event.initialBoard.lastMoves.isEmpty
              ? null
              : event.initialBoard.lastMoves.last,
          clearLastMove: event.initialBoard.lastMoves.isEmpty,
          clearSelected: true,
          clearHintMoves: true,
          clearResult: true,
          clearFailure: true,
          timeControlSeconds: event.timeControlSeconds,
          redElapsedMs: event.redElapsedMs,
          blackElapsedMs: event.blackElapsedMs,
          aiStrength: event.aiStrength,
          redAiStrength: event.redAiStrength ?? event.aiStrength,
          blackAiStrength: event.blackAiStrength ?? event.aiStrength,
          aiMaxDepth: event.resolvedAiMaxDepth,
          aiMaxThinkMs: event.resolvedAiMaxThinkMs,
          clearAiEvaluation: true,
          redAiMaxDepth:
              event.redAiMaxDepth ??
              (event.playMode == PlayMode.withAIvsAI
                  ? (event.redAiStrength ?? event.aiStrength).maxDepth
                  : event.resolvedAiMaxDepth),
          blackAiMaxDepth:
              event.blackAiMaxDepth ??
              (event.playMode == PlayMode.withAIvsAI
                  ? (event.blackAiStrength ?? event.aiStrength).maxDepth
                  : event.resolvedAiMaxDepth),
          aiVsAiStepDelayMs: event.aiVsAiStepDelayMs,
        ),
      );
      if (_clock!.isExpired(event.initialBoard.innerBoard.sdPlayer)) {
        _finishOnTime(event.initialBoard.innerBoard.sdPlayer, emit);
        return;
      }
      _clock!.start(event.initialBoard.innerBoard.sdPlayer);
      if (event.timeControlSeconds > 0) {
        _clockTicks ??= ticker
            .tick(ticks: 86400)
            .listen((_) => add(const _ChessEventClockTick()));
      }
      _queuePersist(event.initialBoard);
      if (aiTurn) {
        if (event.playMode == PlayMode.withAIvsAI) {
          _requestAiVsAiMove();
        } else {
          _requestAiMove(fromRestoredPosition: true);
        }
      } else {
        _startPonder();
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          board: event.initialBoard,
          playMode: event.playMode,
          phase: GamePhase.failure,
          failureMessage: '棋局恢复失败，请返回后重新开始。',
          clearSelected: true,
        ),
      );
    }
  }

  Future<void> _onAiSettingsChanged(
    ChessEventAiSettingsChanged event,
    Emitter<ChessState> emit,
  ) async {
    await _engine?.setStrength(
      event.aiStrength,
      maxDepth: event.aiMaxDepth,
      maxThinkMs: event.aiMaxThinkMs,
    );
    _evaluationGeneration++;
    emit(
      state.copyWith(
        aiStrength: event.aiStrength,
        aiMaxDepth: event.aiMaxDepth,
        aiMaxThinkMs: event.aiMaxThinkMs,
        clearAiEvaluation: true,
      ),
    );
    _queuePersist(state.board);
    if (state.playMode == PlayMode.withAI &&
        state.phase == GamePhase.playerTurn) {
      _startPonder();
    }
  }

  void _onBoardTapped(ChessEventBoardTap event, Emitter<ChessState> emit) {
    if (!state.canInteractBoard) return;
    final piece = state.board.getPiece(event.pos.sq);
    final selected = state.selected;
    if (piece != null) {
      if (selected?.sq == event.pos.sq) {
        emit(state.copyWith(clearSelected: true));
      } else if (selected == null || piece.sideTag == selected.piece.sideTag) {
        if (state.board.isSelectable(piece)) {
          emit(
            state.copyWith(
              selected: PiecePair(piece, event.pos),
              selectedMoves: BuiltList<MovePos>(
                state.board.getMoves(event.pos.sq),
              ),
              clearHintMoves: true,
            ),
          );
        }
      } else {
        add(ChessEventMoveRequested(MovePos(selected.sq, event.pos.sq)));
      }
    } else if (selected != null) {
      add(ChessEventMoveRequested(MovePos(selected.sq, event.pos.sq)));
    }
  }

  void _onMoveRequested(
    ChessEventMoveRequested event,
    Emitter<ChessState> emit,
  ) {
    if (!state.canInteractBoard) return;
    if (!state.board.isMovable(event.move)) {
      _appendInvalidPresentation(event.move, emit);
      return;
    }
    _commitMove(event.move, emit, requestAi: state.playMode == PlayMode.withAI);
  }

  void _commitMove(
    MovePos move,
    Emitter<ChessState> emit, {
    required bool requestAi,
    bool requestAiVsAi = false,
    bool keepPaused = false,
  }) {
    _evaluationGeneration++;
    final before = state.board;
    final movingSide = before.innerBoard.sdPlayer;
    if (_clock?.isExpired(movingSide) ?? false) {
      _finishOnTime(movingSide, emit);
      return;
    }
    final movingPiece = before.getPiece(move.sqSrc);
    final capturedPiece = before.getPiece(move.sqDst);
    if (movingPiece == null || !before.isMovable(move)) {
      if (!requestAi) {
        emit(
          state.copyWith(
            phase: GamePhase.failure,
            failureMessage: '电脑返回了无效着法，可以重试或切换本地双人。',
          ),
        );
      }
      return;
    }
    final after = before.copyWith(
      actions: before.actions.rebuild(
        (actions) => actions..add(BoardMoveAction(move.mv)),
      ),
    );
    final outcome = _outcomeFor(after, capturedPiece);
    final effect = PresentationEffect(
      id: ++_effectSequence,
      kind: PresentationEffectKind.move,
      beforeBoard: before,
      afterBoard: after,
      move: move,
      movingPiece: movingPiece,
      capturedPiece: capturedPiece,
      tacticalEffect: outcome.effect,
    );
    final finished = outcome.winner != null;
    final nextPhase = keepPaused
        ? GamePhase.paused
        : finished
        ? GamePhase.finished
        : requestAi || requestAiVsAi
        ? GamePhase.aiThinking
        : GamePhase.playerTurn;
    _clock?.stop();
    final clock = _clockSnapshot;
    final waitingForAiAnimation = requestAiVsAi && state.aiVsAiStepDelayMs > 0;
    if (!finished && !keepPaused && !waitingForAiAnimation) {
      _clock?.start(after.innerBoard.sdPlayer);
    }
    emit(
      state.copyWith(
        board: after,
        phase: nextPhase,
        presentations: state.presentations.rebuild((b) => b..add(effect)),
        lastMove: move,
        playStatus: outcome.status,
        winningSide: outcome.winner,
        resultReason: finished ? '将死' : null,
        clearSelected: true,
        clearHintMoves: true,
        clearFailure: true,
        clearAiEvaluation: true,
        redElapsedMs: clock.redElapsedMs,
        blackElapsedMs: clock.blackElapsedMs,
      ),
    );
    _queuePersist(after);
    if (requestAi && !finished) {
      _requestAiMove(humanMove: move.mv);
    } else if (requestAiVsAi && !finished && !keepPaused) {
      _requestAiVsAiMove(respectStepDelay: true);
    } else if (!finished &&
        !keepPaused &&
        state.playMode == PlayMode.withAI &&
        state.phase == GamePhase.playerTurn) {
      _startPonder();
    }
  }

  void _appendInvalidPresentation(MovePos move, Emitter<ChessState> emit) {
    final piece = state.board.getPiece(move.sqSrc);
    final effect = PresentationEffect(
      id: ++_effectSequence,
      kind: PresentationEffectKind.invalidMove,
      beforeBoard: state.board,
      afterBoard: state.board,
      move: move,
      movingPiece: piece,
    );
    emit(
      state.copyWith(
        presentations: state.presentations.rebuild((b) => b..add(effect)),
        clearHintMoves: true,
      ),
    );
  }

  void _onPresentationAcknowledged(
    ChessEventPresentationAcknowledged event,
    Emitter<ChessState> emit,
  ) {
    if (state.presentations.isEmpty ||
        state.presentations.first.id != event.effectId) {
      return;
    }
    emit(
      state.copyWith(
        presentations: state.presentations.rebuild((b) => b..removeAt(0)),
      ),
    );
  }

  void _onPresentationAnimationCompleted(
    ChessEventPresentationAnimationCompleted event,
    Emitter<ChessState> emit,
  ) {
    final active = state.activePresentation;
    if (active == null || active.id != event.effectId) return;
    if (active.tacticalEffect == null ||
        active.tacticalEffect == PlayEffect.eat) {
      add(ChessEventPresentationAcknowledged(event.effectId));
      return;
    }
    emit(
      state.copyWith(
        presentations: state.presentations.rebuild(
          (b) => b[0] = active.copyWith(stage: PresentationStage.feedback),
        ),
      ),
    );
  }

  Future<void> _onUndo(ChessEventUndo event, Emitter<ChessState> emit) async {
    if (!state.canUndo) return;
    _engine?.stopPonder();
    _taskGeneration++;
    _evaluationGeneration++;
    _clock?.stop();
    final clock = _clockSnapshot;
    final original = state.board;
    var cursor = original;
    final effects = <PresentationEffect>[];
    final count = state.playMode == PlayMode.withSelf ? 1 : 2;
    for (var i = 0; i < count; i++) {
      final action = cursor.actions.last as BoardMoveAction;
      final move = MovePos.mv(action.mv);
      final after = cursor.copyWith(
        actions: cursor.actions.rebuild((b) => b..removeLast()),
      );
      effects.add(
        PresentationEffect(
          id: ++_effectSequence,
          kind: PresentationEffectKind.undo,
          beforeBoard: cursor,
          afterBoard: after,
          move: move,
          movingPiece: cursor.getPiece(move.sqDst),
          capturedPiece: after.getPiece(move.sqDst),
        ),
      );
      cursor = after;
    }
    emit(
      state.copyWith(
        phase: GamePhase.loading,
        clearSelected: true,
        redElapsedMs: clock.redElapsedMs,
        blackElapsedMs: clock.blackElapsedMs,
      ),
    );
    try {
      await _engine?.restore(cursor.lastMoves.map((m) => m.mv));
      if (emit.isDone) return;
      _clock?.start(cursor.innerBoard.sdPlayer);
      emit(
        state.copyWith(
          board: cursor,
          phase: GamePhase.playerTurn,
          presentations: state.presentations.rebuild((b) => b..addAll(effects)),
          lastMove: cursor.lastMoves.isEmpty ? null : cursor.lastMoves.last,
          clearLastMove: cursor.lastMoves.isEmpty,
          clearSelected: true,
          clearHintMoves: true,
          clearResult: true,
          clearFailure: true,
          clearAiEvaluation: true,
        ),
      );
      _queuePersist(cursor);
      if (state.playMode == PlayMode.withAI) _startPonder();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _clock?.start(original.innerBoard.sdPlayer);
      emit(
        state.copyWith(
          board: original,
          phase: GamePhase.failure,
          failureMessage: '悔棋未能同步到电脑引擎，请重试。',
        ),
      );
    }
  }

  void _onGetHint(ChessEventGetHint event, Emitter<ChessState> emit) {
    if (!state.canHint || _engine == null) return;
    final generation = ++_taskGeneration;
    emit(state.copyWith(phase: GamePhase.aiThinking, clearHintMoves: true));
    unawaited(
      _engine!.requestMove().then(
        (mv) => add(_ChessEventHintResolved(generation, MovePos.mv(mv), null)),
        onError: (Object error, StackTrace stackTrace) {
          addError(error, stackTrace);
          add(_ChessEventHintResolved(generation, null, error));
        },
      ),
    );
  }

  void _onEvaluatePosition(
    ChessEventEvaluatePosition event,
    Emitter<ChessState> emit,
  ) {
    if (!state.canEvaluate || state.playMode == PlayMode.withNetwork) return;
    final board = state.board;
    final generation = ++_evaluationGeneration;
    final engine = _analysisEngine ??= _providedAnalysisEngine ?? ChessEngine();
    emit(state.copyWith(isEvaluating: true, evaluationFailed: false));
    unawaited(
      engine
          .evaluatePosition(
            squares: List<int>.unmodifiable(board.innerBoard.ucpcSquares),
            sideToMove: board.innerBoard.sdPlayer,
            maxDepth: state.aiMaxDepth,
            maxThinkMs: state.aiMaxThinkMs,
          )
          .then(
            (result) {
              if (isClosed) return;
              add(
                _ChessEventEvaluationResolved(
                  generation: generation,
                  board: board,
                  score: result.score,
                  depth: result.depth,
                ),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              if (isClosed) return;
              addError(error, stackTrace);
              add(
                _ChessEventEvaluationResolved(
                  generation: generation,
                  board: board,
                  score: 0,
                  depth: 0,
                  error: error,
                ),
              );
            },
          ),
    );
  }

  void _onEvaluationResolved(
    _ChessEventEvaluationResolved event,
    Emitter<ChessState> emit,
  ) {
    if (event.generation != _evaluationGeneration ||
        state.board != event.board) {
      return;
    }
    if (event.error != null) {
      emit(state.copyWith(isEvaluating: false, evaluationFailed: true));
      return;
    }
    emit(
      state.copyWith(
        aiEvaluationForRed: event.board.isTurn(PlaySide.red)
            ? event.score
            : -event.score,
        aiEvaluationDepth: event.depth,
        isEvaluating: false,
        evaluationFailed: false,
      ),
    );
  }

  void _onHintResolved(
    _ChessEventHintResolved event,
    Emitter<ChessState> emit,
  ) {
    if (event.generation != _taskGeneration) return;
    if (event.error != null || event.move == null) {
      emit(
        state.copyWith(
          phase: state.phase == GamePhase.paused
              ? GamePhase.paused
              : GamePhase.playerTurn,
          failureMessage: '暂时无法获取提示。',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        phase: state.phase == GamePhase.paused
            ? GamePhase.paused
            : GamePhase.playerTurn,
        hintMoves: BuiltList<MovePos>([event.move!]),
      ),
    );
  }

  void _requestAiMove({int? humanMove, bool fromRestoredPosition = false}) {
    final engine = _engine;
    if (engine == null) return;
    final generation = ++_taskGeneration;
    final budget = _aiBudget(state.aiStrength, state.aiMaxThinkMs);
    final future = fromRestoredPosition
        ? engine.requestAndMakeMove(maxThinkMs: budget)
        : engine.makeMove(humanMove!, maxThinkMs: budget);
    unawaited(
      future.then(
        (mv) => add(_ChessEventAiResolved(generation, MovePos.mv(mv), null)),
        onError: (Object error, StackTrace stackTrace) {
          addError(error, stackTrace);
          add(_ChessEventAiResolved(generation, null, error));
        },
      ),
    );
  }

  void _requestAiVsAiMove({bool respectStepDelay = false}) {
    final engine = _engine;
    if (engine == null || state.playMode != PlayMode.withAIvsAI) return;
    final side = state.board.innerBoard.sdPlayer == PlaySide.red.index
        ? PlaySide.red
        : PlaySide.black;
    final strength = side == PlaySide.red
        ? state.redAiStrength
        : state.blackAiStrength;
    final maxDepth = side == PlaySide.red
        ? state.redAiMaxDepth
        : state.blackAiMaxDepth;
    final generation = ++_taskGeneration;
    _aiVsAiSearchPending = true;
    unawaited(
      () async {
        if (respectStepDelay && state.aiVsAiStepDelayMs > 0) {
          await Future<void>.delayed(
            Duration(milliseconds: state.aiVsAiStepDelayMs),
          );
        }
        if (generation != _taskGeneration ||
            state.playMode != PlayMode.withAIvsAI ||
            state.phase == GamePhase.paused) {
          _aiVsAiSearchPending = false;
          return null;
        }
        if (respectStepDelay) _clock?.start(side.index);
        await engine.setStrength(strength, maxDepth: maxDepth);
        return engine.requestAndMakeMove(
          maxThinkMs: _aiBudget(strength, strength.maxThinkMs),
        );
      }().then(
        (mv) {
          if (mv != null) {
            add(_ChessEventAiResolved(generation, MovePos.mv(mv), null));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          addError(error, stackTrace);
          add(_ChessEventAiResolved(generation, null, error));
        },
      ),
    );
  }

  void _onAiResolved(_ChessEventAiResolved event, Emitter<ChessState> emit) {
    if (event.generation != _taskGeneration ||
        (state.playMode != PlayMode.withAI &&
            state.playMode != PlayMode.withAIvsAI)) {
      return;
    }
    final aiVsAi = state.playMode == PlayMode.withAIvsAI;
    if (aiVsAi) _aiVsAiSearchPending = false;
    if (event.error != null || event.move == null) {
      _clock?.stop();
      final clock = _clockSnapshot;
      emit(
        state.copyWith(
          phase: GamePhase.failure,
          failureMessage: '电脑思考失败，可以重试或切换本地双人。',
          redElapsedMs: clock.redElapsedMs,
          blackElapsedMs: clock.blackElapsedMs,
        ),
      );
      return;
    }
    _commitMove(
      event.move!,
      emit,
      requestAi: false,
      requestAiVsAi: aiVsAi,
      keepPaused: state.phase == GamePhase.paused,
    );
  }

  void _onPaused(ChessEventPause event, Emitter<ChessState> emit) {
    if (!state.canPause) return;
    _engine?.stopPonder();
    _clock?.stop();
    final clock = _clockSnapshot;
    emit(
      state.copyWith(
        phase: GamePhase.paused,
        clearSelected: true,
        redElapsedMs: clock.redElapsedMs,
        blackElapsedMs: clock.blackElapsedMs,
      ),
    );
    _queuePersist(state.board);
  }

  void _onResumed(ChessEventResume event, Emitter<ChessState> emit) {
    if (!state.canResume) return;
    final target =
        state.winningSide != null || state.playStatus == PlayStatus.draw
        ? GamePhase.finished
        : (state.playMode == PlayMode.withAI &&
                  !state.board.isTurn(state.playSide) ||
              state.playMode == PlayMode.withAIvsAI)
        ? GamePhase.aiThinking
        : GamePhase.playerTurn;
    if (target != GamePhase.finished) {
      _clock?.start(state.board.innerBoard.sdPlayer);
    }
    emit(state.copyWith(phase: target));
    if (target == GamePhase.playerTurn && state.playMode == PlayMode.withAI) {
      _startPonder();
    }
    if (target == GamePhase.aiThinking &&
        state.playMode == PlayMode.withAIvsAI &&
        !_aiVsAiSearchPending) {
      _requestAiVsAiMove();
    }
  }

  void _onResigned(ChessEventResign event, Emitter<ChessState> emit) {
    if (!state.canResign || state.board.pcPairs.isEmpty) return;
    _engine?.stopPonder();
    _taskGeneration++;
    _aiVsAiSearchPending = false;
    _clock?.stop();
    final clock = _clockSnapshot;
    final resigningSide = state.playMode == PlayMode.withSelf
        ? (state.board.innerBoard.sdPlayer == PlaySide.red.index
              ? PlaySide.red
              : PlaySide.black)
        : state.playSide;
    emit(
      state.copyWith(
        winningSide: resigningSide == PlaySide.red
            ? PlaySide.black
            : PlaySide.red,
        playStatus: PlayStatus.lose,
        resultReason: '${resigningSide == PlaySide.red ? '红方' : '黑方'}认输',
        phase: GamePhase.finished,
        clearSelected: true,
        clearHintMoves: true,
        clearFailure: true,
        redElapsedMs: clock.redElapsedMs,
        blackElapsedMs: clock.blackElapsedMs,
      ),
    );
    _queuePersist(state.board);
  }

  Future<void> _onRetryAi(
    ChessEventRetryAi event,
    Emitter<ChessState> emit,
  ) async {
    if (!state.canRetryAi) return;
    final engine = _engine;
    if (engine == null) return;
    final generation = ++_taskGeneration;
    emit(state.copyWith(phase: GamePhase.aiThinking, clearFailure: true));
    try {
      await engine.restore(state.board.lastMoves.map((move) => move.mv));
      if (emit.isDone || generation != _taskGeneration) return;
      _clock?.start(state.board.innerBoard.sdPlayer);
      if (state.playMode == PlayMode.withAIvsAI) {
        _requestAiVsAiMove();
      } else {
        _requestAiMove(fromRestoredPosition: true);
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (emit.isDone || generation != _taskGeneration) return;
      emit(
        state.copyWith(
          phase: GamePhase.failure,
          failureMessage: '电脑引擎恢复失败，可以再次重试或切换本地双人。',
        ),
      );
    }
  }

  Future<void> _onSwitchToLocal(
    ChessEventSwitchToLocal event,
    Emitter<ChessState> emit,
  ) async {
    if (state.phase != GamePhase.failure) return;
    _taskGeneration++;
    _aiVsAiSearchPending = false;
    _clock?.start(state.board.innerBoard.sdPlayer);
    emit(
      state.copyWith(
        playMode: PlayMode.withSelf,
        phase: GamePhase.playerTurn,
        clearFailure: true,
      ),
    );
    _queuePersist(state.board);
  }

  void _onFlipBoard(ChessEventFlipBoard event, Emitter<ChessState> emit) {
    if (state.canFlip) emit(state.copyWith(boardFlipped: !state.boardFlipped));
  }

  void _onClearSelection(
    ChessEventClearSelection event,
    Emitter<ChessState> emit,
  ) {
    if (state.selected != null) emit(state.copyWith(clearSelected: true));
  }

  void _onPersistenceCompleted(
    _ChessEventPersistenceCompleted event,
    Emitter<ChessState> emit,
  ) {
    if (event.revision != _persistenceRevision) return;
    emit(
      state.copyWith(
        persistenceStatus: event.error == null
            ? PersistenceStatus.saved
            : PersistenceStatus.failed,
      ),
    );
  }

  void _onPersistenceStarted(
    _ChessEventPersistenceStarted event,
    Emitter<ChessState> emit,
  ) {
    if (event.revision == _persistenceRevision) {
      emit(state.copyWith(persistenceStatus: PersistenceStatus.saving));
    }
  }

  void _onClockTick(_ChessEventClockTick event, Emitter<ChessState> emit) {
    final clock = _clock;
    if (clock == null || clock.activeSide == null) return;
    final side = clock.activeSide!;
    if (clock.isExpired(side)) {
      _finishOnTime(side, emit);
      return;
    }
    final snapshot = clock.snapshot;
    emit(
      state.copyWith(
        redElapsedMs: snapshot.redElapsedMs,
        blackElapsedMs: snapshot.blackElapsedMs,
      ),
    );
    final bucket = (snapshot.redElapsedMs + snapshot.blackElapsedMs) ~/ 10000;
    if (bucket != _lastClockPersistBucket) {
      _lastClockPersistBucket = bucket;
      _queuePersist(state.board);
    }
  }

  void _finishOnTime(int losingSide, Emitter<ChessState> emit) {
    _engine?.stopPonder();
    _taskGeneration++;
    _aiVsAiSearchPending = false;
    _clock?.stop();
    final clock = _clockSnapshot;
    final winner = losingSide == PlaySide.red.index
        ? PlaySide.black
        : PlaySide.red;
    emit(
      state.copyWith(
        phase: GamePhase.finished,
        winningSide: winner,
        playStatus: state.playMode == PlayMode.withAI
            ? (winner == state.playSide ? PlayStatus.win : PlayStatus.lose)
            : null,
        resultReason: '${losingSide == PlaySide.red.index ? '红方' : '黑方'}超时',
        redElapsedMs: clock.redElapsedMs,
        blackElapsedMs: clock.blackElapsedMs,
        clearSelected: true,
        clearHintMoves: true,
      ),
    );
    _queuePersist(state.board);
  }

  _MoveOutcome _outcomeFor(Board board, ChessPiece? capturedPiece) {
    if (board.innerBoard.isMate()) {
      final winner = board.innerBoard.sdPlayer == PlaySide.red.index
          ? PlaySide.black
          : PlaySide.red;
      return _MoveOutcome(
        effect: PlayEffect.mate,
        winner: winner,
        status: state.playMode == PlayMode.withAI
            ? (winner == state.playSide ? PlayStatus.win : PlayStatus.lose)
            : null,
      );
    }
    if (board.innerBoard.checked()) {
      return const _MoveOutcome(effect: PlayEffect.check);
    }
    if (capturedPiece != null) {
      return const _MoveOutcome(effect: PlayEffect.eat);
    }
    return const _MoveOutcome();
  }

  void _queuePersist(Board board) {
    final store = repository;
    if (store == null) return;
    final revision = ++_persistenceRevision;
    add(_ChessEventPersistenceStarted(revision));
    final record = _recordFor(board);
    _saveTail = _saveTail
        .then((_) => store.save(record))
        .then(
          (_) {
            if (!isClosed) {
              add(_ChessEventPersistenceCompleted(revision, null));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            if (!isClosed) {
              add(_ChessEventPersistenceCompleted(revision, error));
            }
          },
        );
  }

  GameRecord _recordFor(Board board) {
    final clock = _clockSnapshot;
    final result = state.winningSide == PlaySide.red
        ? GameResult.redWin
        : state.winningSide == PlaySide.black
        ? GameResult.blackWin
        : state.playStatus == PlayStatus.draw
        ? GameResult.draw
        : GameResult.inProgress;
    return GameRecord(
      id: gameId,
      initialFen: initialFen,
      moves: board.lastMoves
          .map((move) => GameMove(from: move.sqSrc, to: move.sqDst))
          .toList(growable: false),
      mode: switch (state.playMode) {
        PlayMode.withSelf => GamePlayMode.self,
        PlayMode.withAIvsAI => GamePlayMode.aiVsAi,
        PlayMode.withAI || PlayMode.withNetwork => GamePlayMode.ai,
      },
      result: result,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      redElapsedMs: clock.redElapsedMs,
      blackElapsedMs: clock.blackElapsedMs,
      timeControlSeconds: state.timeControlSeconds,
      aiStrength: state.aiStrength,
      redAiStrength: state.redAiStrength,
      blackAiStrength: state.blackAiStrength,
      aiMaxDepth: state.aiMaxDepth,
      aiMaxThinkMs: state.aiMaxThinkMs,
      redAiMaxDepth: state.redAiMaxDepth,
      blackAiMaxDepth: state.blackAiMaxDepth,
      aiVsAiStepDelayMs: state.aiVsAiStepDelayMs,
    );
  }

  Future<void> flushPersistence() => _saveTail;

  Future<void> persistSnapshot() {
    _queuePersist(state.board);
    return flushPersistence();
  }

  @override
  Future<void> close() async {
    _engine?.stopPonder();
    _taskGeneration++;
    _aiVsAiSearchPending = false;
    await _clockTicks?.cancel();
    _clock?.stop();
    await flushPersistence();
    if (repository != null && state.board.pcPairs.isNotEmpty) {
      await repository!.save(_recordFor(state.board));
    }
    await _engine?.dispose();
    if (!identical(_analysisEngine, _engine)) {
      await _analysisEngine?.dispose();
    }
    return super.close();
  }
}

class _MoveOutcome {
  const _MoveOutcome({this.effect, this.winner, this.status});
  final PlayEffect? effect;
  final PlaySide? winner;
  final PlayStatus? status;
}
