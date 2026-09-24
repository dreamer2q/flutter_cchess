import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/chess/game/opening_book.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_cchess/storage/game_record.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final redCannonToCenter = SquareBoard.getMove(
    SquareBoard.coordXYFix(7, 7),
    SquareBoard.coordXYFix(4, 7),
  );
  final blackCannonToCenter = SquareBoard.getMove(
    SquareBoard.coordXYFix(7, 2),
    SquareBoard.coordXYFix(4, 2),
  );

  test('looks up the next move from a matching local game line', () {
    final search = XqwlSearch()
      ..loadBook([
        [redCannonToCenter, blackCannonToCenter],
      ]);

    expect(search.pos.makeMove(redCannonToCenter), isTrue);
    expect(search.searchBook(), blackCannonToCenter);
  });

  test('does not use an opening line after a different first move', () {
    final search = XqwlSearch()
      ..loadBook([
        [redCannonToCenter, blackCannonToCenter],
      ]);
    final otherCannonMove = SquareBoard.getMove(
      SquareBoard.coordXYFix(1, 7),
      SquareBoard.coordXYFix(4, 7),
    );

    expect(search.pos.makeMove(otherCannonMove), isTrue);
    expect(search.searchBook(), 0);
  });

  test('builds book lines only from standard-start games', () {
    final now = DateTime.utc(2026, 9, 25);
    final record = GameRecord(
      id: 'imported-line',
      initialFen: initialFenString,
      moves: [
        GameMove(
          from: SquareBoard.coordXYFix(7, 7),
          to: SquareBoard.coordXYFix(4, 7),
        ),
        GameMove(
          from: SquareBoard.coordXYFix(7, 2),
          to: SquareBoard.coordXYFix(4, 2),
        ),
      ],
      mode: GamePlayMode.self,
      createdAt: now,
      updatedAt: now,
    );

    expect(OpeningBook.fromRecords([record]), [
      [redCannonToCenter, blackCannonToCenter],
    ]);
  });
}
