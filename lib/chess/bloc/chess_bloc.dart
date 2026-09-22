import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/chess/game/game.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/fen.dart';

part 'chess_event.dart';
part 'chess_state.dart';

class ChessBloc extends Bloc<ChessEvent, ChessState> {
  static const moveCompletionTimeout = Duration(milliseconds: 500);

  final Ticker ticker;
  final GameRepository? repository;
  final String initialFen;
  final Duration animationCompletionTimeout;
  final ChessEnginePort? _providedEngine;
  late final String gameId;
  late final DateTime createdAt;

  ChessBloc({
    required this.ticker,
    this.repository,
    this.initialFen = initialFenString,
    this.animationCompletionTimeout = moveCompletionTimeout,
    ChessEnginePort? engine,
    String? gameId,
    DateTime? createdAt,
  }) : _providedEngine = engine,
       super(ChessState(board: Board(BuiltList.of([])))) {
    this.gameId = gameId ?? DateTime.now().microsecondsSinceEpoch.toString();
    this.createdAt = createdAt ?? DateTime.now();
    on<ChessEventInitialized>(_onInitialized);
    on<ChessEventBoardTap>(_onBoardTapped);
    on<ChessEventMoveBegin>(_onPieceBeginMoving);
    on<ChessEventMoveEnd>(_onPieceEndMoving);
    on<ChessEventUndo>(_onChessUndoEvent);
    on<ChessEventGetHint>(_onChessGetHintMoves);
    on<ChessEventPause>(_onPaused);
    on<ChessEventResume>(_onResumed);
    on<ChessEventResign>(_onResigned);
  }

  ChessEnginePort? _engine;
  Timer? _moveCompletionTimer;
  BoardStatus _resumeStatus = BoardStatus.idle;
  MovePos? _pendingAiMove;

  Future<void> _onInitialized(
    ChessEventInitialized event,
    Emitter<ChessState> emit,
  ) async {
    switch (event.playMode) {
      case PlayMode.withAI:
        _engine = _providedEngine ?? ChessEngine();
        await _engine!.restore(
          event.initialBoard.lastMoves.map((move) => move.mv),
        );
        break;
      case PlayMode.withNetwork:
        throw UnimplementedError();
      case PlayMode.withSelf:
        // Local two-player mode uses the same board and rule path without an
        // AI engine. The active side is selected from the board itself.
        _engine = null;
        break;
    }
    _moveCompletionTimer?.cancel();
    _resumeStatus = BoardStatus.idle;
    _pendingAiMove = null;
    emit(
      state.copyWith(
        board: event.initialBoard,
        playMode: event.playMode,
        status: BoardStatus.idle,
        clearSelected: true,
        clearHintMoves: true,
        clearLastMove: true,
        clearResult: true,
      ),
    );
    _persist(state.board);
  }

  FutureOr<void> _onBoardTapped(
    ChessEventBoardTap event,
    Emitter<ChessState> emit,
  ) {
    if (state.status != BoardStatus.idle) return null;

    ChessPiece? pc = state.board.getPiece(event.pos.sq);
    // final piece = state.board?.get(event.pos);
    final selected = state.selected;
    if (pc != null) {
      if (selected?.sq == event.pos.sq) {
        emit(state.copyWith(clearSelected: true));
        return null;
      }
      if (selected == null || pc.sideTag == selected.piece.sideTag) {
        if (state.board.isSelectable(pc)) {
          emit(
            state.copyWith(
              selected: PiecePair(pc, event.pos),
              selectedMoves: BuiltList.of(state.board.getMoves(event.pos.sq)),
              clearHintMoves: true,
            ),
          );
        }
      } else {
        // 吃子
        add(ChessEventMoveBegin(MovePos(selected.sq, event.pos.sq)));
      }
    } else if (selected != null) {
      final move = MovePos(selected.sq, event.pos.sq);
      if (state.selectedMoves?.contains(move) ?? false) {
        add(ChessEventMoveBegin(move));
      } else {
        emit(state.copyWith(clearSelected: true));
      }
    }
  }

  FutureOr<void> _onPieceBeginMoving(
    ChessEventMoveBegin event,
    Emitter<ChessState> emit,
  ) {
    if (state.status != BoardStatus.idle &&
        state.status != BoardStatus.thinking) {
      return null;
    }
    bool isMovable = state.board.isMovable(event.move);
    PlayEffect? playEffect;
    PlayStatus? playStatus;
    PlaySide? winningSide;

    if (isMovable) {
      ChessPiece? piece = state.board.getPiece(event.move.sqDst);
      Board board = state.board.copyWith(
        actions: state.board.actions.rebuild(
          (b) => b..add(BoardMoveAction(event.move.mv)),
        ),
      );

      // playStatus =
      // state.board.isTurn(state.playSide) ? PlayStatus.win : PlayStatus.lose;

      if (board.innerBoard.isMate()) {
        // 绝杀
        playEffect = PlayEffect.mate;
        winningSide = state.board.innerBoard.sdPlayer == PlaySide.red.index
            ? PlaySide.red
            : PlaySide.black;
        if (state.playMode == PlayMode.withAI) {
          playStatus = winningSide == state.playSide
              ? PlayStatus.win
              : PlayStatus.lose;
        }
      } else if (board.innerBoard.checked()) {
        // 将军
        playEffect = PlayEffect.check;
      } else if (piece != null) {
        // 吃
        playEffect = PlayEffect.eat;
      }
    }

    emit(
      state.copyWith(
        animeMove: isMovable ? event.move : null,
        animeMoveInvalid: isMovable ? null : event.move,
        playEffect: playEffect,
        playStatus: playStatus,
        winningSide: winningSide,
        status: BoardStatus.busy,
      ),
    );
    _scheduleMoveCompletion(event.move);
  }

  Future<void> _onPieceEndMoving(
    ChessEventMoveEnd event,
    Emitter<ChessState> emit,
  ) async {
    final activeMove = state.animeMove ?? state.animeMoveInvalid;
    if (activeMove == null ||
        (event.expectedMove != null && event.expectedMove != activeMove)) {
      return;
    }
    _moveCompletionTimer?.cancel();
    _moveCompletionTimer = null;

    MovePos? lastMove;
    MovePos? move = state.animeMove;
    Board board = state.board;
    if (move != null) {
      board = board.copyWith(
        actions: board.actions.rebuild((b) => b..add(BoardMoveAction(move.mv))),
      );
      lastMove = MovePos.mv(move.mv);
    }

    final isFinished = state.playStatus != null || state.winningSide != null;
    final shouldRequestAi =
        move != null &&
        state.playMode == PlayMode.withAI &&
        _engine != null &&
        !board.isTurn(state.playSide) &&
        !isFinished;
    emit(
      state.copyWith(
        board: board,
        animeMove: null,
        animeMoveInvalid: null,
        selected: move == null ? state.selected : null,
        selectedMoves: move == null ? state.selectedMoves : BuiltList.of([]),
        lastMove: lastMove,
        playEffect: state.playEffect,
        clearHintMoves: move != null,
        status: isFinished
            ? BoardStatus.finished
            : shouldRequestAi
            ? BoardStatus.thinking
            : BoardStatus.idle,
      ),
    );
    _persist(board);

    if (shouldRequestAi) {
      try {
        final aiMove = await _engine!.makeMove(move.mv);
        if (isClosed || emit.isDone) return;
        final resolvedMove = MovePos.mv(aiMove);
        if (state.status == BoardStatus.thinking) {
          add(ChessEventMoveBegin(resolvedMove));
        } else if (state.status == BoardStatus.paused &&
            _resumeStatus == BoardStatus.thinking) {
          _pendingAiMove = resolvedMove;
        }
      } catch (error, stackTrace) {
        addError(error, stackTrace);
        if (!emit.isDone && state.status == BoardStatus.thinking) {
          emit(
            state.copyWith(
              board: board,
              status: BoardStatus.idle,
              clearSelected: true,
            ),
          );
        } else if (state.status == BoardStatus.paused &&
            _resumeStatus == BoardStatus.thinking) {
          _resumeStatus = BoardStatus.idle;
        }
      }
    }
  }

  FutureOr<void> _onChessUndoEvent(
    ChessEventUndo event,
    Emitter<ChessState> emit,
  ) async {
    if (state.status != BoardStatus.idle &&
        state.status != BoardStatus.finished) {
      return;
    }
    final canUndo = state.playMode == PlayMode.withSelf
        ? state.board.lastMoves.isNotEmpty
        : state.board.lastMoves.length > 1 &&
              state.board.isTurn(state.playSide);
    if (canUndo) {
      Board board = state.board;
      final undoCount = state.playMode == PlayMode.withSelf ? 1 : 2;
      for (int i = 0; i < undoCount; i++) {
        final lastMove = board.actions.last as BoardMoveAction;
        board = board.copyWith(
          actions: board.actions.rebuild((b) => b.removeLast()),
        );
        ChessPiece? p = board.getPiece(SquareBoard.getDst(lastMove.mv));
        if (state.playMode == PlayMode.withAI) {
          await _engine?.requestUndo(lastMove.mv, p == null ? 0 : p.pc);
        }
      }

      emit(
        state.copyWith(
          board: board,
          status: BoardStatus.idle,
          clearSelected: true,
          clearHintMoves: true,
          clearResult: true,
          lastMove: board.lastMoves.isEmpty ? null : board.lastMoves.last,
          clearLastMove: board.lastMoves.isEmpty,
        ),
      );
      _persist(board);
    } else {}
  }

  Future<void> _onChessGetHintMoves(
    ChessEventGetHint event,
    Emitter<ChessState> emit,
  ) async {
    if (state.status == BoardStatus.idle &&
        state.board.isTurn(state.playSide) &&
        _engine != null) {
      emit(state.copyWith(status: BoardStatus.thinking));
      try {
        final move = await _engine!.requestMove();
        if (emit.isDone) return;
        final hints = BuiltList.of([MovePos.mv(move)]);
        if (state.status == BoardStatus.thinking) {
          emit(state.copyWith(status: BoardStatus.idle, hintMoves: hints));
        } else if (state.status == BoardStatus.paused &&
            _resumeStatus == BoardStatus.thinking) {
          _resumeStatus = BoardStatus.idle;
          emit(state.copyWith(hintMoves: hints));
        }
      } catch (error, stackTrace) {
        addError(error, stackTrace);
        if (!emit.isDone && state.status == BoardStatus.thinking) {
          emit(state.copyWith(status: BoardStatus.idle));
        } else if (state.status == BoardStatus.paused &&
            _resumeStatus == BoardStatus.thinking) {
          _resumeStatus = BoardStatus.idle;
        }
      }
    }
  }

  void _onPaused(ChessEventPause event, Emitter<ChessState> emit) {
    if (state.status == BoardStatus.idle ||
        state.status == BoardStatus.thinking) {
      _resumeStatus = state.status;
      emit(state.copyWith(status: BoardStatus.paused, clearSelected: true));
    }
  }

  void _onResumed(ChessEventResume event, Emitter<ChessState> emit) {
    if (state.status == BoardStatus.paused) {
      final targetStatus = _resumeStatus;
      final pendingAiMove = _pendingAiMove;
      _resumeStatus = BoardStatus.idle;
      _pendingAiMove = null;
      emit(state.copyWith(status: targetStatus));
      if (targetStatus == BoardStatus.thinking && pendingAiMove != null) {
        add(ChessEventMoveBegin(pendingAiMove));
      }
    }
  }

  void _onResigned(ChessEventResign event, Emitter<ChessState> emit) {
    if (state.status == BoardStatus.finished || state.board.pcPairs.isEmpty) {
      return;
    }
    _moveCompletionTimer?.cancel();
    _moveCompletionTimer = null;
    _pendingAiMove = null;
    _resumeStatus = BoardStatus.idle;
    final resigningSide = state.playMode == PlayMode.withSelf
        ? (state.board.innerBoard.sdPlayer == PlaySide.red.index
              ? PlaySide.red
              : PlaySide.black)
        : state.playSide;
    final winner = resigningSide == PlaySide.red
        ? PlaySide.black
        : PlaySide.red;
    emit(
      state.copyWith(
        winningSide: winner,
        playStatus: PlayStatus.lose,
        status: BoardStatus.finished,
        clearSelected: true,
        clearHintMoves: true,
      ),
    );
    _persist(state.board);
  }

  void _scheduleMoveCompletion(MovePos move) {
    _moveCompletionTimer?.cancel();
    _moveCompletionTimer = Timer(animationCompletionTimeout, () {
      if (!isClosed) add(ChessEventMoveEnd(move));
    });
  }

  @override
  Future<void> close() {
    _moveCompletionTimer?.cancel();
    return super.close();
  }

  void _persist(Board board) {
    final store = repository;
    if (store == null) return;

    final result = state.winningSide == PlaySide.red
        ? GameResult.redWin
        : state.winningSide == PlaySide.black
        ? GameResult.blackWin
        : state.playStatus == PlayStatus.draw
        ? GameResult.draw
        : GameResult.inProgress;
    final record = GameRecord(
      id: gameId,
      initialFen: initialFen,
      moves: board.lastMoves
          .map((move) => GameMove(from: move.sqSrc, to: move.sqDst))
          .toList(),
      mode: state.playMode == PlayMode.withSelf
          ? GamePlayMode.self
          : GamePlayMode.ai,
      result: result,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
    unawaited(store.save(record));
  }
}
