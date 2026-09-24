import 'package:flutter_cchess/chess/game/game_board.dart';
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

  /// Parses a Xiangqi FEN and returns only its board position.
  ///
  /// The existing callers only need a [Board], so this method is kept as the
  /// backwards-compatible entry point. Use [parsePosition] when FEN metadata
  /// such as the active side or move counters is needed.
  static Board parse(String fenString) => parsePosition(fenString).board;

  /// Parses a Xiangqi FEN, including its optional metadata fields.
  static FenPosition parsePosition(String fenString) {
    final List<BoardAction> actions = [];

    final value = fenString.trim();
    if (value.isEmpty) {
      throw const FormatException('FEN must not be empty');
    }

    final parts = value.split(RegExp(r'\s+'));
    if (parts.length > 6) {
      throw const FormatException('FEN must contain at most six fields');
    }

    final fenPos = parts.first;
    final rows = fenPos.split('/');
    if (rows.length != 10) {
      throw const FormatException('Xiangqi FEN must contain ten ranks');
    }

    for (int rank = 0; rank < rows.length; rank++) {
      final line = rows[rank];
      int file = 0;
      for (final char in line.split('')) {
        final codeUnit = char.codeUnitAt(0);
        if (codeUnit >= 49 && codeUnit <= 57) {
          file += codeUnit - 48;
        } else {
          final pc = fenCharacterList.indexOf(char.toLowerCase());
          if (pc < 0) {
            throw FormatException('invalid piece character: $char');
          }
          if (file >= 9) {
            throw FormatException('rank ${rank + 1} contains too many files');
          }
          final sideTag = char == char.toLowerCase() ? 0x10 : 0x08;
          actions.add(
            BoardPutAction(
              pc | sideTag,
              // FEN ranks are listed from black's back rank to red's back
              // rank, which matches the engine's top-to-bottom coordinates.
              SquareBoard.coordXYFix(file, rank),
            ),
          );
          file++;
        }
      }
      if (file != 9) {
        throw FormatException(
          'rank ${rank + 1} must describe exactly nine files',
        );
      }
    }

    final activeColor = parts.length > 1 ? parts[1] : 'w';
    if (activeColor != 'w' && activeColor != 'b') {
      throw FormatException('invalid active color: $activeColor');
    }

    final castling = parts.length > 2 ? parts[2] : '-';
    final enPassant = parts.length > 3 ? parts[3] : '-';
    final halfmoveClock = parts.length > 4
        ? _parseCounter(parts[4], 'halfmove clock', minimum: 0)
        : 0;
    final fullmoveNumber = parts.length > 5
        ? _parseCounter(parts[5], 'fullmove number', minimum: 1)
        : 1;

    // SquareBoard uses 0 for red and 1 for black, matching FEN's w/b fields.
    final board = Board(
      BuiltList.of(actions),
      initialSideToMove: activeColor == 'w' ? 0 : 1,
    );
    return FenPosition(
      board: board,
      activeColor: activeColor,
      castling: castling,
      enPassant: enPassant,
      halfmoveClock: halfmoveClock,
      fullmoveNumber: fullmoveNumber,
    );
  }

  static int _parseCounter(
    String value,
    String field, {
    required int minimum,
  }) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < minimum) {
      throw FormatException('invalid $field: $value');
    }
    return parsed;
  }
}

/// The board and non-position fields represented by a FEN string.
class FenPosition {
  const FenPosition({
    required this.board,
    required this.activeColor,
    required this.castling,
    required this.enPassant,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  final Board board;
  final String activeColor;
  final String castling;
  final String enPassant;
  final int halfmoveClock;
  final int fullmoveNumber;

  bool get redToMove => activeColor == 'w';
}
