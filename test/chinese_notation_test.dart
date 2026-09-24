import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/chess/notation/chinese_notation.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats opening cannon moves as readable Chinese notation', () {
    final board = FenUtil.parse(initialFenString);
    final moves = <MovePos>[
      MovePos(SquareBoard.coordXYFix(7, 7), SquareBoard.coordXYFix(4, 7)),
      MovePos(SquareBoard.coordXYFix(7, 2), SquareBoard.coordXYFix(4, 2)),
    ];
    var history = board;
    for (final move in moves) {
      history = history.copyWith(
        actions: history.actions.rebuild(
          (actions) => actions..add(BoardMoveAction(move.mv)),
        ),
      );
    }

    final notation = ChineseChessNotation.formatHistory(history);
    expect(notation.map((move) => move.text), ['炮二平五', '炮八平五']);
    expect(notation.map((move) => move.isRed), [true, false]);
  });

  test('disambiguates same-file pawns by front and rear position', () {
    final board = FenUtil.parse('3k5/9/9/4P4/4P4/9/9/9/9/4K4 w - - 0 1');
    final frontPawnMove = MovePos(
      SquareBoard.coordXYFix(4, 3),
      SquareBoard.coordXYFix(4, 2),
    );
    final rearPawnMove = MovePos(
      SquareBoard.coordXYFix(4, 4),
      SquareBoard.coordXYFix(4, 3),
    );
    var history = board.copyWith(
      actions: board.actions.rebuild(
        (actions) => actions..add(BoardMoveAction(frontPawnMove.mv)),
      ),
    );
    history = history.copyWith(
      actions: history.actions.rebuild(
        (actions) => actions..add(BoardMoveAction(rearPawnMove.mv)),
      ),
    );

    final notation = ChineseChessNotation.formatHistory(history);
    expect(notation.map((move) => move.text), ['前兵进一', '后兵进一']);
  });
}
