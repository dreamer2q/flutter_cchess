import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UI and search use the same piece-square values', () {
    expect(SquareBoard.cucvlPiecePos, XqwlPosition.cucvlPiecePos);
  });

  test('incremental evaluation matches a full sum after moves and undo', () {
    final position = XqwlPosition();
    final initial = position.evaluate();
    final moves = <int>[];
    position.generateMoves(moves);
    for (final move in moves) {
      if (!position.makeMove(move)) continue;
      var red = 0;
      var black = 0;
      for (var square = 0; square < 256; square++) {
        final piece = position.ucpcSquares[square];
        if (piece == 0) continue;
        if (piece < 16) {
          red += XqwlPosition.cucvlPiecePos[piece - 8][square];
        } else {
          black += XqwlPosition
              .cucvlPiecePos[piece - 16][position.getSquareFlip(square)];
        }
      }
      expect(position.vlWhite, red);
      expect(position.vlBlack, black);
      expect(position.evaluate(), black - red + XqwlPosition.ADVANCED_VALUE);
      position.undoMakeMove();
      expect(position.evaluate(), initial);
    }
  });

  test(
    'changing side negates the base score but keeps tempo for the mover',
    () {
      final position = XqwlPosition();
      position.delPiece(SquareBoard.coordXYFix(0, 0), 20);
      final redScore = position.evaluate();
      position.changeSide();
      expect(position.evaluate(), -redScore + 2 * XqwlPosition.ADVANCED_VALUE);
    },
  );

  test('position score is always measured from Red perspective', () {
    const redRookFen = '4k4/9/9/9/9/9/9/9/9/3K4R w - - 0 1';
    const blackRookFen = '4k3r/9/9/9/9/9/9/9/9/3K5 w - - 0 1';

    final redAdvantage = FenUtil.parse(redRookFen).staticEvaluationForRed;
    final blackAdvantage = FenUtil.parse(blackRookFen).staticEvaluationForRed;
    final samePositionBlackToMove = FenUtil.parse(
      redRookFen.replaceFirst(' w ', ' b '),
    ).staticEvaluationForRed;

    expect(redAdvantage, greaterThan(0));
    expect(blackAdvantage, lessThan(0));
    expect(samePositionBlackToMove, redAdvantage);
  });
}
