import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/chess/game/game.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter_cchess/timer/ticker.dart';

part 'chess_event.dart';
part 'chess_state.dart';

class ChessBloc extends Bloc<ChessEvent, ChessState> {
  final Ticker ticker;

  ChessBloc({
    required this.ticker,
  }) : super(ChessState(
          board: Board(BuiltList.of([])),
        )) {
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
        throw UnimplementedError();
    }
    emit(
      state.copyWith(
        board: event.initialBoard,
        playMode: event.playMode,
        status: BoardStatus.idle,
      ),
    );
  }

  FutureOr<void> _onBoardTapped(
      ChessEventBoardTap event, Emitter<ChessState> emit) {
    if (state.status != BoardStatus.idle) return null;

    ChessPiece? pc = state.board!.getPiece(event.pos.sq);
    // final piece = state.board?.get(event.pos);
    final selected = state.selected;
    if (pc != null) {
      if (selected == null || pc.sideTag == selected.piece.sideTag) {
        if (state.board!.isSelectable(pc)) {
          emit(state.copyWith(
            selected: PiecePair(pc, event.pos),
            selectedMoves: BuiltList.of(
              state.board!.getMoves(event.pos.sq),
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

    if (isMovable) {
      ChessPiece? piece = state.board.getPiece(event.move.sqDst);
      Board board = Board(
        state.board.actions.rebuild(
          (b) => b..add(BoardMoveAction(event.move.mv)),
        ),
      );

      // playStatus =
      // state.board.isTurn(state.playSide) ? PlayStatus.win : PlayStatus.lose;

      if (board.innerBoard.isMate()) {
        // 绝杀
        playEffect = PlayEffect.mate;
        playStatus = state.board.isTurn(state.playSide)
            ? PlayStatus.win
            : PlayStatus.lose;
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
      status: BoardStatus.busy,
    ));
  }

  FutureOr<void> _onPieceEndMoving(
      ChessEventMoveEnd event, Emitter<ChessState> emit) {
    MovePos? move = state.animeMove;
    Board board = state.board!;
    if (move != null) {
      board = board.copyWith(
        actions: board.actions.rebuild(
          (b) => b..add(BoardMoveAction(move.mv)),
        ),
      );

      if (_engine != null &&
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
      status: BoardStatus.idle,
    ));
  }

  FutureOr<void> _onChessUndoEvent(
      ChessEventUndo event, Emitter<ChessState> emit) async {
    if (state.board!.lastMoves.length > 1 &&
        state.board!.isTurn(state.playSide)) {
      Board board = state.board!;
      for (int i = 0; i < 2; i++) {
        final lastMove = board.actions.last as BoardMoveAction;
        board = Board(board.actions.rebuild((b) => b.removeLast()));
        ChessPiece? p = board.getPiece(SquareBoard.getDst(lastMove.mv));
        await _engine?.requestUndo(lastMove.mv, p == null ? 0 : p.pc);
      }

      emit(
        state.copyWith(
          board: board,
        ),
      );
    } else {}
  }

  FutureOr<void> _onChessGetHintMoves(
      ChessEventGetHint event, Emitter<ChessState> emit) {
    if (state.board!.isTurn(state.playSide)) {
      _engine?.requestMove().then((mv) {
        add(
          ChessEventMoveBegin(
            MovePos.mv(mv),
          ),
        );
      });
    }
  }
}
