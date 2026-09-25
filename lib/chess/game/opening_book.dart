import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/storage/game_record.dart';
import 'package:flutter_cchess/utils/fen.dart';

/// Builds a small, local opening repertoire from saved and imported games.
abstract class OpeningBook {
  static const int maxRecords = 512;
  static const int maxBookPlies = 24;
  static const int minBookPlies = 2;

  static List<List<int>> fromRecords(Iterable<GameRecord> records) {
    final lines = <List<int>>[];
    for (final record in records) {
      if (record.initialFen != initialFenString ||
          record.moves.length < minBookPlies) {
        continue;
      }
      lines.add(
        record.moves
            .take(maxBookPlies)
            .map((move) => SquareBoard.getMove(move.from, move.to))
            .toList(growable: false),
      );
      if (lines.length >= maxRecords) break;
    }
    return lines;
  }
}
