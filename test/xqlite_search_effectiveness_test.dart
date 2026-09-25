import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds a free rook capture in a tactical position', () {
    final search = XqwlSearch();
    _loadFen(search, '4k4/9/4p4/9/9/r8/R8/9/9/4K4 w - - 0 1');

    search.searchMain(maxDepth: 3, maxThinkMs: 10000);

    final expectedCapture = SquareBoard.getMove(
      SquareBoard.coordXYFix(0, 6),
      SquareBoard.coordXYFix(0, 5),
    );
    expect(search.mvResult, expectedCapture);
    expect(search.completedDepth, 3);
  });

  test('finds a legal king escape while in check', () {
    final search = XqwlSearch();
    _loadFen(search, '4k4/9/9/9/4r4/9/9/9/9/4K4 w - - 0 1');
    expect(search.pos.inCheck(), isTrue);

    search.searchMain(maxDepth: 3, maxThinkMs: 10000);

    expect(search.mvResult, isNot(0));
    expect(search.pos.makeMove(search.mvResult), isTrue);
    expect(XqwlPosition.getSrc(search.mvResult), SquareBoard.coordXYFix(4, 9));
    final destination = XqwlPosition.getDst(search.mvResult);
    expect(
      destination,
      anyOf(SquareBoard.coordXYFix(3, 9), SquareBoard.coordXYFix(5, 9)),
    );
  });

  test('reaches configured depth and reuses transposition results', () {
    final search = XqwlSearch();
    search.searchMain(maxDepth: 3, maxThinkMs: 10000);
    final coldNodeCount = search.nodesSearched;

    expect(search.completedDepth, 3);
    expect(coldNodeCount, greaterThan(0));

    search.searchMain(maxDepth: 3, maxThinkMs: 10000);

    expect(search.completedDepth, 3);
    expect(search.transpositionCutoffs, greaterThan(0));
    expect(search.nodesSearched, lessThan(coldNodeCount));
  });
}

void _loadFen(XqwlSearch search, String fen) {
  final parsed = FenUtil.parsePosition(fen);
  final position = search.pos;
  position.clearBoard();
  for (final pair in parsed.board.pcPairs) {
    position.addPiece(pair.sq, pair.piece.pc);
  }
  if (!parsed.redToMove) position.changeSide();
  position.setIrrev();
}
