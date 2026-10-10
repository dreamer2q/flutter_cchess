import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_cchess/engine/xqlite/position_evaluator.dart';
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
      final positional = PositionEvaluator.evaluateSquares(
        position.ucpcSquares,
      );
      expect(
        position.evaluate(),
        black - red - positional + XqwlPosition.ADVANCED_VALUE,
      );
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

  test('an advanced rook increases pressure on an exposed king', () {
    final squares = List<int>.filled(256, 0);
    final homeRook = SquareBoard.coordXYFix(0, 0);
    final advancedRook = SquareBoard.coordXYFix(0, 8);
    squares[homeRook] = 20;
    final homeScore = PositionEvaluator.evaluateSquares(squares);
    squares[homeRook] = 0;
    squares[advancedRook] = 20;
    expect(PositionEvaluator.evaluateSquares(squares), lessThan(homeScore));
  });

  test('defensive pieces retain more value against attacking material', () {
    final squares = List<int>.filled(256, 0);
    final advisor = SquareBoard.coordXYFix(4, 8);
    final rook = SquareBoard.coordXYFix(0, 0);
    squares[advisor] = 9;
    final loneDefender = PositionEvaluator.evaluateSquares(squares);
    squares[advisor] = 0;
    final noAttackerMarginal =
        loneDefender - PositionEvaluator.evaluateSquares(squares);

    squares[rook] = 20;
    final withoutDefender = PositionEvaluator.evaluateSquares(squares);
    squares[advisor] = 9;
    final withAttackerMarginal =
        PositionEvaluator.evaluateSquares(squares) - withoutDefender;
    expect(withAttackerMarginal, greaterThan(noAttackerMarginal));
  });

  test('board-dependent terms are symmetric under color rotation', () {
    final position = XqwlPosition();
    final moves = <int>[];
    position.generateMoves(moves);
    final move = moves.firstWhere(position.makeMove);
    final score = PositionEvaluator.evaluateSquares(position.ucpcSquares);
    final rotated = List<int>.filled(256, 0);
    for (var square = 0; square < 256; square++) {
      final piece = position.ucpcSquares[square];
      if (piece == 0) continue;
      rotated[254 - square] = piece < 16 ? piece + 8 : piece - 8;
    }
    expect(PositionEvaluator.evaluateSquares(rotated), -score);
    position.undoMakeMove();
    expect(move, isNot(0));
  });

  test('UI static score agrees with search score excluding tempo', () {
    final board = FenUtil.parse('4k4/9/9/9/9/4R4/9/9/9/3K5 w - - 0 1');
    final position = XqwlPosition()..clearBoard();
    for (final pair in board.pcPairs) {
      position.addPiece(pair.sq, pair.piece.pc);
    }
    position.setIrrev();
    expect(
      board.staticEvaluationForRed,
      position.evaluate() - XqwlPosition.ADVANCED_VALUE,
    );
  });
}
