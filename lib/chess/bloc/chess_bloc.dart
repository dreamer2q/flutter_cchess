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
  final Ticker ticker;
  final GameRepository? repository;
  final String initialFen;
  late final String gameId;
  late final DateTime createdAt;

  ChessBloc({
    required this.ticker,
    this.repository,
    this.initialFen = initialFenString,
    String? gameId,
    DateTime? createdAt,
  }) : super(ChessState(
          board: Board(BuiltList.of([])),
        )) {
    this.gameId = gameId ?? DateTime.now().microsecondsSinceEpoch.toString();
    this.createdAt = createdAt ?? DateTime.now();
    on<ChessEventInitialized>(_onInitialized);
    on<ChessEventBoardTap>(_onBoardTapped);
    on<ChessEventMoveBegin>(_onPieceBeginMoving);
    on<ChessEventMoveEnd>(_onPieceEndMoving);
    on<ChessEventUndo>(_onChessUndoEvent);
    on<ChessEventGetHint>(_onChessGetHintMoves);
  }

  ChessEngine? _engine;

  FutureOr<void> _onInitialized(
      ChessEventInitialized event, Emitter<ChessState> emit) {
    switch (event.playMode) {
      case PlayMode.withAI:
        _engine = ChessEngine();
        break;
      case PlayMode.withNetwork:
        throw UnimplementedError();
      case PlayMode.withSelf:
        // Local two-player mode uses the same board and rule path without an
        // AI engine. The active side is selected from the board itself.
        _engine = null;
        break;
    }
    emit(state.copyWith(
      board: event.initialBoard,
      playMode: event.playMode,
      status: BoardStatus.idle,
    ));
    _persist(state.board);
  }

  FutureOr<void> _onBoardTapped(
      ChessEventBoardTap event, Emitter<ChessState> emit) {
    if (state.status != BoardStatus.idle) return null;

    ChessPiece? pc = state.board.getPiece(event.pos.sq);
    // final piece = state.board?.get(event.pos);
    final selected = state.selected;
    if (pc != null) {
      if (selected == null || pc.sideTag == selected.piece.sideTag) {
        if (state.board.isSelectable(pc)) {
          emit(state.copyWith(
            selected: PiecePair(pc, event.pos),
            selectedMoves: BuiltList.of(
              state.board.getMoves(event.pos.sq),
            ),
          ));
        }
      } else {
        // 吃子
        add(ChessEventMoveBegin(MovePos(selected.sq, event.pos.sq)));
      }
    } else if (selected != null) {
      // 走子
      add(ChessEventMoveBegin(MovePos(selected.sq, event.pos.sq)));
    }
  }

  FutureOr<void> _onPieceBeginMoving(
      ChessEventMoveBegin event, Emitter<ChessState> emit) {
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
          playStatus =
              winningSide == state.playSide ? PlayStatus.win : PlayStatus.lose;
        }
      } else if (board.innerBoard.checked()) {
        // 将军
        playEffect = PlayEffect.check;
      } else if (piece != null) {
        // 吃
        playEffect = PlayEffect.eat;
      }
    }

    emit(state.copyWith(
      animeMove: isMovable ? event.move : null,
      animeMoveInvalid: isMovable ? null : event.move,
      playEffect: playEffect,
      playStatus: playStatus,
      winningSide: winningSide,
      status: BoardStatus.busy,
    ));
  }

  FutureOr<void> _onPieceEndMoving(
      ChessEventMoveEnd event, Emitter<ChessState> emit) {
    MovePos? lastMove;
    MovePos? move = state.animeMove;
    Board board = state.board;
    if (move != null) {
      board = board.copyWith(
        actions: board.actions.rebuild(
          (b) => b..add(BoardMoveAction(move.mv)),
        ),
      );
      lastMove = MovePos.mv(move.mv);

      if (state.playMode == PlayMode.withAI &&
          _engine != null &&
          !board.isTurn(state.playSide) &&
          state.playStatus == null) {
        _engine?.makeMove(move.mv).then(
              (mv) => add(
                ChessEventMoveBegin(MovePos.mv(mv)),
              ),
            );
      }
    }

    emit(state.copyWith(
      board: board,
      animeMove: null,
      animeMoveInvalid: null,
      selected: move != null ? null : state.selected,
      selectedMoves: move != null ? BuiltList.of([]) : state.selectedMoves,
      lastMove: lastMove,
      status: BoardStatus.idle,
    ));
    _persist(board);
  }

  FutureOr<void> _onChessUndoEvent(
      ChessEventUndo event, Emitter<ChessState> emit) async {
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
        ),
      );
      _persist(board);
    } else {}
  }

  FutureOr<void> _onChessGetHintMoves(
      ChessEventGetHint event, Emitter<ChessState> emit) {
    if (state.board.isTurn(state.playSide)) {
      _engine?.requestMove().then((mv) {
        add(
          ChessEventMoveBegin(
            MovePos.mv(mv),
          ),
        );
      });
    }
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
