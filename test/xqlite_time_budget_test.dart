import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledClock extends Stopwatch {
  int Function() read = () => 0;

  @override
  int get elapsedMilliseconds => read();
}

void main() {
  test('deadline inside a deeper iteration retains the complete result', () {
    final clock = _ControlledClock();
    final search = XqwlSearch(clock: clock);
    final squares = List<int>.of(search.pos.ucpcSquares);
    final key = search.pos.zobr.dwKey;
    final evaluation = search.pos.evaluate();
    int? completedMove;
    int? completedScore;
    clock.read = () {
      if (search.completedDepth >= 3) {
        completedMove ??= search.mvResult;
        completedScore ??= search.scoreResult;
        if (search.pos.nDistance >= 2) return 100;
      }
      return 0;
    };

    search.searchMain(maxThinkMs: 100, useOpeningBook: false);

    expect(search.stoppedOnTime, isTrue);
    expect(search.completedDepth, 3);
    expect(search.mvResult, completedMove);
    expect(search.scoreResult, completedScore);
    expect(search.pos.ucpcSquares, squares);
    expect(search.pos.zobr.dwKey, key);
    expect(search.pos.evaluate(), evaluation);
    expect(search.pos.nMoveNum, 1);
    expect(search.pos.nDistance, 0);
    expect(search.pos.makeMove(search.mvResult), isTrue);
  });

  test('automatic search uses its real budget and returns a legal move', () {
    final search = XqwlSearch();
    search.searchMain(maxThinkMs: 250, useOpeningBook: false);
    expect(search.stoppedOnTime, isTrue);
    expect(search.completedDepth, greaterThan(0));
    expect(search.elapsedMs, inInclusiveRange(250, 1500));
    expect(search.pos.makeMove(search.mvResult), isTrue);
    // ignore: avoid_print
    print(
      '250ms budget: ${search.elapsedMs}ms, depth ${search.completedDepth}, '
      '${search.nodesSearched} nodes',
    );
  });

  test('manual depth can stop before the time limit', () {
    final search = XqwlSearch(clock: _ControlledClock());
    search.searchMain(maxDepth: 2, maxThinkMs: 5000, useOpeningBook: false);
    expect(search.completedDepth, 2);
    expect(search.stoppedOnTime, isFalse);
  });

  test('zero legal moves is a loss even without check', () {
    final search = XqwlSearch();
    final board = FenUtil.parse('3k5/9/9/9/9/9/9/9/3r1r3/4K4 w - - 0 1');
    search.pos.clearBoard();
    for (final piece in board.pcPairs) {
      search.pos.addPiece(piece.sq, piece.piece.pc);
    }
    search.pos.setIrrev();
    expect(search.pos.inCheck(), isFalse);
    search.searchMain(maxThinkMs: 100);
    expect(search.mvResult, 0);
    expect(search.scoreResult, -XqwlPosition.MATE_VALUE);
  });
}
