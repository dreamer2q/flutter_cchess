import 'package:equatable/equatable.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/engine/xqlite/position_evaluator.dart';
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
  String toString() {
    return '${ChessPiece(pc)}${PiecePos(sq)}';
  }

  @override
  List<Object?> get props => [pc, sq];
}

class BoardMoveAction extends BoardAction {
  final int mv;

  const BoardMoveAction(this.mv);

  @override
  String toString() {
    return MovePos.mv(mv).toString();
  }

  @override
  List<Object?> get props => [mv];
}

class Board extends Equatable {
  Board(this.actions, {this.initialSideToMove = 0})
    : innerBoard = SquareBoard() {
    innerBoard.sdPlayer = initialSideToMove;
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

  /// The side that was to move before the first recorded action.
  /// This is needed when rebuilding a position parsed from a black-to-move FEN.
  final int initialSideToMove;

  List<PiecePair> get pcPairs {
    final List<PiecePair> pairs = [];
    for (int sq = 0; sq < 256; sq++) {
      final int pc = innerBoard.ucpcSquares[sq];
      if (pc != 0) {
        pairs.add(PiecePair(ChessPiece(pc), PiecePos(sq)));
      }
    }
    return pairs;
  }

  BuiltList<MovePos> get lastMoves => actions
      .whereType<BoardMoveAction>()
      .map<MovePos>((v) => MovePos.mv(v.mv))
      .toBuiltList();

  /// Static engine evaluation from Red's perspective, excluding the side-to-
  /// move bonus so the displayed score does not flip after every turn.
  int get staticEvaluationForRed =>
      innerBoard.vlWhite -
      innerBoard.vlBlack +
      PositionEvaluator.evaluateSquares(innerBoard.ucpcSquares);

  List<MovePos> getMoves([int sq = 0]) {
    List<int> mvs = [];
    innerBoard.generateMoves(mvs);
    if (sq != 0) {
      mvs.removeWhere((mv) => sq != SquareBoard.getSrc(mv));
    }
    return mvs
        .map((mv) => MovePos.mv(mv))
        .where(isMovable)
        .toList(growable: false);
  }

  bool isMovable(MovePos move) {
    int pcCaptured = innerBoard.moveCaptured(move.mv);
    bool canMove =
        innerBoard.legalMove(move.mv) && innerBoard.makeMove(move.mv);
    if (canMove) innerBoard.undoMakeMove(move.mv, pcCaptured);
    return canMove;
  }

  ChessPiece? getPiece(int sq) {
    int pc = innerBoard.ucpcSquares[sq];
    return pc == 0 ? null : ChessPiece(pc);
  }

  bool isSelectable(ChessPiece pc) {
    // SquareBoard uses 0/1 for the side to move while ChessPiece exposes
    // 1/0 for red/black. Convert through the engine's side tag constants.
    return SquareBoard.isSideTag(innerBoard.sdPlayer) ==
        (pc.sideTag == 1 ? 8 : 16);
  }

  Board copyWith({BuiltList<BoardAction>? actions}) {
    return Board(actions ?? this.actions, initialSideToMove: initialSideToMove);
  }

  @override
  List<Object?> get props => [actions, initialSideToMove];

  // 轮到我走
  bool isTurn(PlaySide playSide) {
    return innerBoard.sdPlayer == playSide.index;
  }
}
