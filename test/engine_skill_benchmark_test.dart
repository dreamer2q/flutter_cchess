import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _MoveCheck = bool Function(int move);

class _PositionCase {
  const _PositionCase(this.name, this.fen, this.accept);

  final String name;
  final String fen;
  final _MoveCheck accept;
}

int _move(int fromFile, int fromRank, int toFile, int toRank) =>
    XqwlPosition.getMove(
      SquareBoard.coordXYFix(fromFile, fromRank),
      SquareBoard.coordXYFix(toFile, toRank),
    );

final _positions = <_PositionCase>[
  _PositionCase(
    'red captures exposed rook, left file',
    '4k4/9/4p4/9/9/r8/R8/9/9/4K4 w - - 0 1',
    (move) => move == _move(0, 6, 0, 5),
  ),
  _PositionCase(
    'red captures exposed rook, right file',
    '4k4/9/4p4/9/9/8r/8R/9/9/4K4 w - - 0 1',
    (move) => move == _move(8, 6, 8, 5),
  ),
  _PositionCase(
    'black captures exposed rook, left file',
    '4k4/9/4p4/9/9/r8/R8/9/9/4K4 b - - 0 1',
    (move) => move == _move(0, 5, 0, 6),
  ),
  _PositionCase(
    'black captures exposed rook, right file',
    '4k4/9/4p4/9/9/8r/8R/9/9/4K4 b - - 0 1',
    (move) => move == _move(8, 5, 8, 6),
  ),
  _PositionCase(
    'red escapes a rook check',
    '4k4/9/9/9/4r4/9/9/9/9/4K4 w - - 0 1',
    (move) => move == _move(4, 9, 3, 9) || move == _move(4, 9, 5, 9),
  ),
  _PositionCase(
    'black escapes a rook check',
    '4k4/9/9/9/4R4/9/9/9/9/4K4 b - - 0 1',
    (move) => move == _move(4, 0, 3, 0) || move == _move(4, 0, 5, 0),
  ),
];

void _load(XqwlSearch search, String fen) {
  final parsed = FenUtil.parsePosition(fen);
  final pos = search.pos;
  pos.clearBoard();
  for (final pair in parsed.board.pcPairs) {
    pos.addPiece(pair.sq, pair.piece.pc);
  }
  if (!parsed.redToMove) pos.changeSide();
  pos.setIrrev();
}

void main() {
  test('repeatable tactical and search-cost benchmark', () {
    const budgetMs = 300;
    var correct = 0;
    var totalNodes = 0;
    var totalDepth = 0;
    var totalTimeMs = 0;
    for (final position in _positions) {
      final search = XqwlSearch();
      _load(search, position.fen);
      search.searchMain(maxThinkMs: budgetMs, useOpeningBook: false);
      final move = search.mvResult;
      final hit = position.accept(move);
      if (hit) correct++;
      expect(move, isNot(0), reason: position.name);
      expect(search.pos.makeMove(move), isTrue, reason: position.name);
      totalNodes += search.nodesSearched;
      totalDepth += search.completedDepth;
      totalTimeMs += search.elapsedMs;
      // ignore: avoid_print
      print(
        '${position.name}: hit=$hit depth=${search.completedDepth} '
        'nodes=${search.nodesSearched} time=${search.elapsedMs}ms',
      );
    }
    // ignore: avoid_print
    print(
      'TACTICAL_SCORE $correct/${_positions.length} '
      'AVG_DEPTH ${(totalDepth / _positions.length).toStringAsFixed(2)} '
      'NODES $totalNodes TIME_MS $totalTimeMs',
    );
    expect(correct, _positions.length);
  });

  test('fixed-time opening throughput benchmark', () {
    const positions = [
      'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1',
      'rnbakabnr/9/1c5c1/p1p1p1p1p/9/4P4/P1P3P1P/1C5C1/9/RNBAKABNR b - - 0 1',
      'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/4C2C1/9/RNBAKABNR b - - 0 1',
    ];
    var depth = 0;
    var nodes = 0;
    for (final fen in positions) {
      final search = XqwlSearch();
      _load(search, fen);
      search.searchMain(maxThinkMs: 500, useOpeningBook: false);
      expect(search.pos.makeMove(search.mvResult), isTrue);
      depth += search.completedDepth;
      nodes += search.nodesSearched;
      // ignore: avoid_print
      print(
        'OPENING depth=${search.completedDepth} '
        'nodes=${search.nodesSearched} time=${search.elapsedMs}ms',
      );
    }
    // ignore: avoid_print
    print('OPENING_TOTAL_DEPTH $depth NODES $nodes');
  });

  test('late endgames from a 15-minute AI match remain searchable', () {
    const positions = [
      '5k3/4a4/3a5/3N5/4c3C/9/3p4P/B4A3/3n5/5K3 w - - 0 1',
      '3k1a3/9/3ac4/9/9/2N6/3n4P/9/5K3/2BC5 w - - 0 1',
      '5a3/4k4/5N3/9/9/8P/3n5/4B4/5K3/3C3c1 w - - 0 1',
      '4kN3/9/9/9/9/8P/9/4B4/2nC1K3/7c1 b - - 0 1',
    ];
    for (final fen in positions) {
      final search = XqwlSearch();
      _load(search, fen);
      search.searchMain(maxThinkMs: 300, useOpeningBook: false);
      expect(search.mvResult, isNot(0), reason: fen);
      expect(search.pos.makeMove(search.mvResult), isTrue, reason: fen);
      // ignore: avoid_print
      print(
        'ENDGAME depth=${search.completedDepth} score=${search.scoreResult} '
        'nodes=${search.nodesSearched} time=${search.elapsedMs}ms',
      );
    }
  });
}
