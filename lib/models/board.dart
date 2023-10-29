import 'package:equatable/equatable.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/utils/utils.dart';
import 'dart:collection';
import 'models.dart';

enum BoardSide { RedPlayer, BlackPlayer }

abstract class BoardAction extends Equatable {}

class PutPieceAction extends BoardAction {
  final Piece piece;

  PutPieceAction(this.piece);

  @override
  List<Object?> get props => [piece];
}

class MovePieceAction extends PutPieceAction {
  final PiecePosition position;

  MovePieceAction(super.piece, this.position);

  @override
  List<Object?> get props => [...super.props, position];
}

class Board2 extends Equatable {
  // static calcPieces(List<BoardAction> actions) {
  //   final List<Piece> board = [];
  //   for (final action in actions) {
  //     if (action is PutPieceAction) {
  //       board.removeWhere((p) => p.position == action.piece.position);
  //       board.add(action.piece);
  //     } else if (action is MovePieceAction) {
  //       board.removeWhere((p) =>
  //           p.position == action.piece.position ||
  //           p.position == action.position);
  //       board.add(action.piece.copyWith(position: action.position));
  //     }
  //   }
  //   return board;
  // }

  Board2({
    required this.actions,
  }) : innerBoard = GameBoard() {
    for (final ac in actions) {
      if (ac is MovePieceAction) {
        innerBoard.makeMove(
          GameBoard.getMove(ac.piece.sq, ac.position.sq),
        );
      } else if (ac is PutPieceAction) {
        innerBoard.addPiece(ac.piece.sq, ac.piece.pc);
      }
    }
  }

  final BuiltList<BoardAction> actions;
  final GameBoard innerBoard;

  List<Piece> get pieces {
    final List<Piece> board = [];
    for (int sq = 0; sq < 256; sq++) {
      final int pc = innerBoard.ucpcSquares[sq];
      if (pc != 0) {
        final Piece piece = BoardUtil.makePiece(sq, pc);
        board.add(piece);
      }
    }
    return board;
  }

  Piece? get(PiecePosition position) {
    final int i = pieces.indexWhere((p) => p.position == position);
    if (i != -1) {
      return pieces[i];
    }
    return null;
  }

  List<PieceMove> get moves => actions
      .whereType<MovePieceAction>()
      .map((e) => PieceMove(e.piece, e.position))
      .toList();

  BoardSide get currentPlayer =>
      moves.length.isOdd ? BoardSide.BlackPlayer : BoardSide.RedPlayer;

  Board2 nextAction(BoardAction action) {
    return Board2(
      actions: actions.rebuild(
        (b) => b..add(action),
      ),
    );
  }

  @override
  String toString() => 'Board{pieces: $pieces}';

  @override
  List<Object?> get props => [...actions];
}

class Board extends Equatable {
  const Board({
    required this.pieces,
    required this.moves,
  });

  final BuiltList<Piece> pieces;
  final BuiltList<PieceMove> moves;

  BoardSide get currentPlayer =>
      moves.length.isOdd ? BoardSide.BlackPlayer : BoardSide.RedPlayer;

  Piece? get(PiecePosition position) {
    return pieces.firstWhere((p) => p.position == position);
  }

  Board toBeginMoving(Piece piece) {
    return copyWith(
      pieces: pieces.rebuild(
        (p) => p..remove(piece),
      ),
    );
  }

  Board toEndMoving(PieceMove move) {
    return copyWith(
      pieces: pieces.rebuild(
        (p) => p
          ..remove(get(move.dst))
          ..add(move.dstPiece),
      ),
      moves: _addMove(move),
    );
  }

  BuiltList<PieceMove> _addMove(PieceMove move) {
    return moves.rebuild((b) => b.add(move));
  }

  @override
  List<Object?> get props => [pieces, moves];

  @override
  String toString() => 'Board{pieces: $pieces, moves: $moves}';

  Board copyWith({
    BuiltList<Piece>? pieces,
    BuiltList<PieceMove>? moves,
  }) {
    return Board(
      pieces: pieces ?? this.pieces,
      moves: moves ?? this.moves,
    );
  }
}
