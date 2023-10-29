import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/helpers/helpers.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:built_collection/built_collection.dart';

const initialFenString =
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

abstract class FenUtil {
  static Map<String, PieceKind> fenCharMap = {
    'r': PieceKind.ROOK,
    'n': PieceKind.KNIGHT,
    'b': PieceKind.BISHOP,
    'a': PieceKind.ADVISOR,
    'k': PieceKind.KING,
    'c': PieceKind.CANNON,
    'p': PieceKind.PAWN,
  };

  static List<String> fenCharacterList = ['k', 'a', 'b', 'n', 'r', 'c', 'p'];

  static Board parse(String fenString) {
    final List<BoardAction> actions = [];

    final parts = fenString.split(' ');
    final fenPos = parts.first;
    if (fenPos.isNotEmpty) {
      final rows = fenPos.split('/');
      if (rows.length != 10) {
        throw Exception('rows.length != 10');
      }
      int i = 0;
      for (final String line in rows.reversed) {
        for (final String char in line.split('')) {
          if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0) {
            final skip = int.tryParse(char) ?? 0;
            i += skip;
          } else {
            int x = i % 9, y = i ~/ 9;
            int sq = SquareBoard.coordXYFix(x, y);
            int pc = fenCharacterList.indexOf(char.toLowerCase());
            if (pc < 0) {
              throw Exception('invalid format: $char not recognizable');
            }
            int sideTag = char.isLowerCase() ? 0x08 : 0x10;
            pc |= sideTag;
            actions.add(BoardPutAction(pc, sq));
            i++;
          }
        }
      }

      // TODO: parse piece moves
    }

    return Board(
      BuiltList.of(actions),
    );
  }
}
