import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/storage/game_record.dart';

/// A disposable variation rooted at one position of the real game.
class AnalysisLine {
  AnalysisLine(Board origin) : origin = origin.copyWith();

  final Board origin;
  final List<MovePos> _moves = [];
  int _cursor = 0;

  int get cursor => _cursor;
  int get length => _moves.length;
  int get originPly => origin.lastMoves.length;
  List<MovePos> get moves => List.unmodifiable(_moves);
  Board get board => boardAt(_cursor);
  Board get fullBoard => boardAt(_moves.length);

  Board boardAt(int ply) {
    RangeError.checkValueInInterval(ply, 0, _moves.length, 'ply');
    return origin.copyWith(
      actions: origin.actions.rebuild(
        (actions) => actions.addAll(
          _moves.take(ply).map((move) => BoardMoveAction(move.mv)),
        ),
      ),
    );
  }

  bool play(MovePos move) {
    if (originPly + _cursor >= SquareBoard.MAX_MOVES ||
        !board.isMovable(move)) {
      return false;
    }
    _moves.removeRange(_cursor, _moves.length);
    _moves.add(move);
    _cursor++;
    return true;
  }

  void seek(int ply) {
    RangeError.checkValueInInterval(ply, 0, _moves.length, 'ply');
    _cursor = ply;
  }

  GameRecord toRecord(String initialFen) {
    final now = DateTime.now();
    return GameRecord(
      id: 'analysis-${now.microsecondsSinceEpoch}',
      initialFen: initialFen,
      moves: fullBoard.lastMoves
          .map((move) => GameMove(from: move.sqSrc, to: move.sqDst))
          .toList(growable: false),
      mode: GamePlayMode.self,
      createdAt: now,
      updatedAt: now,
      timeControlSeconds: 0,
    );
  }
}
