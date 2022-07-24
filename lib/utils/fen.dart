import 'package:flutter_cchess/helpers/helpers.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:built_collection/built_collection.dart';

const initialFenString =
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

abstract class FenUtil {
  static Map<String, PieceKind> charToKind = {
    'r': PieceKind.ROOK,
    'n': PieceKind.KNIGHT,
    'b': PieceKind.BISHOP,
    'a': PieceKind.ADVISOR,
    'k': PieceKind.KING,
    'c': PieceKind.CANNON,
    'p': PieceKind.PAWN,
  };

  static Board parse(String fenString) {
    final parts = fenString.split(' ');
    final fenPos = parts.first;
    final pieces = <Piece>[];
    if (fenPos.isNotEmpty) {
      final rows = fenPos.split('/');
      if (rows.length != 10) {
        throw Exception('rows.length != 10');
      }
      int i = 0;
      for (final row in rows.reversed) {
        row.split('').forEach((char) {
          if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0) {
            final skipNum = int.tryParse(char) ?? 0;
            i += skipNum;
          } else {
            final kind = charToKind[char.toLowerCase()];
            if (kind == null) {
              throw Exception('invalid format: $char not recognizable');
            }
            final side = char.isLowerCase() ? PieceSide.RED : PieceSide.BLACK;
            final piece = Piece(kind, side, PiecePosition.fromIndex(i));
            pieces.add(piece);
            i++;
          }
        });
      }
      // TODO: parse piece moves
    }

    return Board(
      pieces: BuiltList.of(pieces),
      moves: BuiltList(),
    );
  }
}
