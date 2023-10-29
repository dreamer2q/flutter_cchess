import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/game/game.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/utils/utils.dart';

part 'chess_event.dart';
part 'chess_state.dart';

class ChessBloc extends Bloc<ChessEvent, ChessState> {
  ChessBloc() : super(ChessState()) {
    on<ChessInitialized>(_onInitialized);
    on<ChessBoardTapped>(_onBoardTapped);
    on<PieceBeginMovingEvent>(_onPieceBeginMoving);
    on<PieceEndMovingEvent>(_onPieceEndMoving);
    on<PieceInvalidMoveBegin>(_onPieceInvalidMoveBegin);
    on<PieceInvalidMoveEnd>(_onPieceInvalidMoveEnd);
  }

  final ChessGame _game = ChessGame();
  ChessEngine? _engine;

  FutureOr<void> _onInitialized(
      ChessInitialized event, Emitter<ChessState> emit) {
    _game.resetBoard(initialPieces: event.initialBoard?.pieces.toList());
    _game.prepareMoves();
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
      ChessBoardTapped event, Emitter<ChessState> emit) {
    if (state.status != BoardStatus.idle) return null;

    final piece = state.board?.get(event.position);
    final selected = state.selected;

    if (piece != null) {
      if (selected == null || selected.isSameSide(piece)) {
        if (_game.isSelectable(piece)) {
          emit(state.copyWith(
            selected: piece,
            selectedMoves: _game.getPieceMoves(piece),
          ));
        }
      } else {
        // move & eat
        add(PieceBeginMovingEvent(selected, event.position));
      }
    } else if (selected != null) {
      // move
      add(PieceBeginMovingEvent(selected, event.position));
    }
  }

  FutureOr<void> _onPieceBeginMoving(
      PieceBeginMovingEvent event, Emitter<ChessState> emit) {
    if (_game.makeMove(event.piece.position, event.destination)) {
      emit(
        state.copyWith(
          animeMove: PieceMove(event.piece, event.destination),
          status: BoardStatus.busy,
        ),
      );
    } else {
      add(PieceInvalidMoveBegin(event.piece, event.destination));
    }
  }

  FutureOr<void> _onPieceEndMoving(
      PieceEndMovingEvent event, Emitter<ChessState> emit) {
    if (state.status == BoardStatus.busy) {
      _game.prepareMoves();
      final move = state.animeMove!;
      emit(
        state.copyWith(
          board: state.board!.nextAction(
            MovePieceAction(move.piece, move.dst),
          ),
          status: BoardStatus.idle,
        ),
      );
      if (_engine != null) {
        if (state.board!.currentPlayer == BoardSide.BlackPlayer) {
          _engine?.resultForMove(move).then((move) {
            int sqSrc = GameBoard.getSrc(move);
            int sqDst = GameBoard.getDst(move);
            Piece originPiece =
                state.board!.get(BoardUtil.makePosition(sqSrc))!;
            add(PieceBeginMovingEvent(
                originPiece, BoardUtil.makePosition(sqDst)));
          });
        }
      }
    }
  }

  FutureOr<void> _onPieceInvalidMoveBegin(
      PieceInvalidMoveBegin event, Emitter<ChessState> emit) {
    final move = PieceMove(event.piece, event.destination);
    emit(
      state.copyWith(
        selectedMoves: state.selectedMoves,
        animeMoveInvalid: move,
      ),
    );
  }

  FutureOr<void> _onPieceInvalidMoveEnd(
      PieceInvalidMoveEnd event, Emitter<ChessState> emit) {
    emit(
      state.copyWith(
        selected: state.animeMoveInvalid!.piece,
        selectedMoves: state.selectedMoves,
      ),
    );
  }
}
