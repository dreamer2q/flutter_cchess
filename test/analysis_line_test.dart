import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/game/analysis_line.dart';
import 'package:flutter_cchess/chess/notation/game_notation.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/utils/fen.dart';

void main() {
  test('variation starts from a snapshot and replaces only its future', () {
    final source = FenUtil.parse(initialFenString);
    final line = AnalysisLine(source);
    final red = line.board.getMoves().first;
    expect(line.play(red), isTrue);
    final black = line.board.getMoves();
    expect(black.length, greaterThan(1));
    expect(line.play(black.first), isTrue);
    expect(line.cursor, 2);
    expect(line.length, 2);

    line.seek(1);
    expect(line.board.lastMoves, [red]);
    expect(line.play(black[1]), isTrue);
    expect(line.cursor, 2);
    expect(line.moves, [red, black[1]]);
    expect(source.lastMoves, isEmpty);

    final imported = GameNotationImporter.parse(
      line.toRecord(initialFenString).encode(),
    );
    expect(imported.moves.length, 2);
    expect(imported.moves.last.from, black[1].sqSrc);
    expect(imported.moves.last.to, black[1].sqDst);
  });

  test('seeking between plies leaves the complete variation available', () {
    final line = AnalysisLine(FenUtil.parse(initialFenString));
    final move = line.board.getMoves().first;
    line.play(move);
    line.seek(0);
    expect(line.board.lastMoves, isEmpty);
    expect(line.fullBoard.lastMoves, [move]);
    line.seek(1);
    expect(line.board.lastMoves, [move]);
    expect(() => line.seek(2), throwsRangeError);
  });

  test('export retains the original game prefix before the variation', () {
    final initial = FenUtil.parse(initialFenString);
    final red = initial.getMoves().first;
    final current = initial.copyWith(
      actions: initial.actions.rebuild(
        (actions) => actions.add(BoardMoveAction(red.mv)),
      ),
    );
    final line = AnalysisLine(current);
    final black = line.board.getMoves().first;
    expect(line.play(black), isTrue);

    final imported = GameNotationImporter.parse(
      line.toRecord(initialFenString).encode(),
    );
    expect(imported.moves.length, 2);
    expect(imported.moves.first.from, red.sqSrc);
    expect(imported.moves.last.to, black.sqDst);
    expect(current.lastMoves, [red]);
  });
}
