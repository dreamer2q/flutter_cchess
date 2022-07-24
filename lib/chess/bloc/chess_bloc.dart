import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/chess/game/chess.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:built_collection/built_collection.dart';

part 'chess_event.dart';
part 'chess_state.dart';

class ChessBloc extends Bloc<ChessEvent, ChessState> {
  ChessBloc()
      : super(ChessState(
          board: Board(pieces: BuiltList(), moves: BuiltList()),
        )) {
    on<ChessInitialized>(_onInitialized);
    on<ChessBoardTapped>(_onBoardTapped);
    on<PieceBeginMovingEvent>(_onPieceBeginMoving);
    on<PieceEndMovingEvent>(_onPieceEndMoving);
  }

  final ChessGame _game = ChessGame();

  FutureOr<void> _onInitialized(
      ChessInitialized event, Emitter<ChessState> emit) {
    _game.resetBoard(initialPieces: event.initialBoard?.pieces.toList());
    _game.prepareMoves();
    emit(ChessIdle(board: event.initialBoard ?? state.board));
  }

  FutureOr<void> _onBoardTapped(
      ChessBoardTapped event, Emitter<ChessState> emit) {
    if (state is! ChessIdle) return null;
    assert(state is ChessIdle, "invalid state");
    final s = state as ChessIdle;
    final piece = state.board.get(event.position);
    final selected = s.selected;

    if (piece != null) {
      if (selected == null || piece.isSameSide(selected)) {
        if (_game.isSelectable(piece)) {
          emit(s.copyWith(
            selected: piece,
            selectedMoves: _game.getPieceMoves(piece),
          ));
        }
      } else {
        // move & eat
        if (_game.makeMove(selected.position, event.position)) {
          add(PieceBeginMovingEvent(selected, event.position));
        }
      }
    } else if (selected != null) {
      // move
      if (_game.makeMove(selected.position, event.position)) {
        add(PieceBeginMovingEvent(selected, event.position));
      }
    }
  }

  FutureOr<void> _onPieceBeginMoving(
      PieceBeginMovingEvent event, Emitter<ChessState> emit) {
    // 判断走子是否合法
    emit(
      ChessBusyMoving(
        board: state.board.removePiece(event.piece),
        move: PieceMove(
          event.piece,
          event.destination,
        ),
      ),
    );
  }

  FutureOr<void> _onPieceEndMoving(
      PieceEndMovingEvent event, Emitter<ChessState> emit) {
    final state = this.state;
    if (state is ChessBusyMoving) {
      _game.prepareMoves();
      final destPiece = state.board.get(state.move.dst);
      final pieces = state.board.pieces.rebuild(
        (b) => b
          ..remove(destPiece)
          ..add(state.move.dstPiece),
      );
      emit(
        ChessIdle(
          board: Board(
            pieces: pieces,
            moves: state.board.addMove(state.move),
          ),
        ),
      );
    }
  }
}
