import 'package:equatable/equatable.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'models.dart';

enum BoardSide { RedPlayer, BlackPlayer }

abstract class BoardAction extends Equatable {
  const BoardAction();
}

class BoardPutAction extends BoardAction {
  final int pc;
  final int sq;

  const BoardPutAction(this.pc, this.sq);

  @override
  List<Object?> get props => [pc, sq];
}

class BoardMoveAction extends BoardAction {
  final int mv;

  const BoardMoveAction(this.mv);

  @override
  List<Object?> get props => [mv];
}

class Board extends Equatable {
  Board(this.actions) : innerBoard = SquareBoard() {
    for (final ac in actions) {
      if (ac is BoardPutAction) {
        innerBoard.addPiece(ac.sq, ac.pc);
      } else if (ac is BoardMoveAction) {
        innerBoard.makeMove(ac.mv);
      }
    }
  }

  final SquareBoard innerBoard;

  final BuiltList<BoardAction> actions;

  List<PiecePair> get pcPairs {
    final List<PiecePair> pairs = [];
    for (int sq = 0; sq < 256; sq++) {
      final int pc = innerBoard.ucpcSquares[sq];
      if (pc != 0) {
        pairs.add(PiecePair(
          ChessPiece(pc),
          PiecePos(sq),
        ));
      }
    }
    return pairs;
  }

  List<MovePos> getMoves([int sq = 0]) {
    List<int> mvs = [];
    innerBoard.generateMoves(mvs);
    if (sq != 0) {
      mvs.removeWhere((mv) => sq != SquareBoard.getSrc(mv));
    }
    return mvs.map((mv) => MovePos.mv(mv)).toList();
  }

  bool isMovable(MovePos move) {
    return getMoves(move.sqSrc).contains(move);
  }

  ChessPiece? getPiece(int sq) {
    int pc = innerBoard.ucpcSquares[sq];
    return pc == 0 ? null : ChessPiece(pc);
  }

  bool isSelectable(ChessPiece pc) {
    return innerBoard.sdPlayer != pc.sideTag;
  }

  Board copyWith({
    BuiltList<BoardAction>? actions,
  }) {
    return Board(actions ?? this.actions);
  }

  @override
  List<Object?> get props => [actions];

  // 轮到我走
  bool isTurn(PlaySide playSide) {
    return innerBoard.sdPlayer == playSide.index;
  }
}
