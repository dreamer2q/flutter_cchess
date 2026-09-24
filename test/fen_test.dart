import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/utils/fen.dart';

void main() {
  group('FenUtil', () {
    test('parses the initial position and active side', () {
      final position = FenUtil.parsePosition(initialFenString);

      expect(position.redToMove, isTrue);
      expect(position.halfmoveClock, 0);
      expect(position.fullmoveNumber, 1);
      expect(position.board.pcPairs, hasLength(32));
      expect(position.board.innerBoard.sdPlayer, 0);

      final redPawns = position.board.pcPairs
          .where((pair) =>
              pair.piece.pc == (PieceSide.RED.code | PieceKind.PAWN.code))
          .toList();
      expect(redPawns, hasLength(5));
    });

    test('preserves side, counters, and auxiliary fields', () {
      const fen = '9/9/9/9/9/9/9/9/9/4k4 b - - 12 34';
      final position = FenUtil.parsePosition(fen);

      expect(position.redToMove, isFalse);
      expect(position.activeColor, 'b');
      expect(position.castling, '-');
      expect(position.enPassant, '-');
      expect(position.halfmoveClock, 12);
      expect(position.fullmoveNumber, 34);
      expect(position.board.innerBoard.sdPlayer, 1);
      expect(position.board.pcPairs, hasLength(1));
    });

    test('keeps parse as a board-only compatibility API', () {
      final board = FenUtil.parse(initialFenString);

      expect(board.pcPairs, hasLength(32));
      expect(board.innerBoard.sdPlayer, 0);
    });

    test('rejects malformed board ranks and fields', () {
      expect(
        () => FenUtil.parse('9/9/9/9/9/9/9/9/9/8X w - - 0 1'),
        throwsFormatException,
      );
      expect(
        () => FenUtil.parse('9/9/9/9/9/9/9/9/9/9 x - - 0 1'),
        throwsFormatException,
      );
      expect(
        () => FenUtil.parse('9/9/9/9/9/9/9/9/9/9 w - - -1 1'),
        throwsFormatException,
      );
      expect(
        () => FenUtil.parse('9/9/9/9/9/9/9/9/9/9 w - - 0 0'),
        throwsFormatException,
      );
      expect(
        () => FenUtil.parse('9/9/9/9/9/9/9/9/9/8 w - - 0 1'),
        throwsFormatException,
      );
    });
  });

  group('SquareBoard rules', () {
    test('generates one legal forward move for an initial red pawn', () {
      final board = FenUtil.parse(initialFenString);
      final pawn = board.pcPairs.firstWhere(
        (pair) =>
            pair.piece.numTag == PieceKind.PAWN.code && pair.piece.isRedSide(),
      );

      expect(board.getMoves(pawn.sq), hasLength(1));
      expect(board.isMovable(board.getMoves(pawn.sq).single), isTrue);
    });

    test('does not allow a side to move the opponent piece', () {
      final board = FenUtil.parse(initialFenString);
      final blackPawn = board.pcPairs.firstWhere(
        (pair) =>
            pair.piece.numTag == PieceKind.PAWN.code && !pair.piece.isRedSide(),
      );

      expect(board.isSelectable(blackPawn.piece), isFalse);
      expect(board.getMoves(blackPawn.sq), isEmpty);
    });

    test('uses the FEN active side when generating moves', () {
      final position = FenUtil.parsePosition(
        initialFenString.replaceFirst(' w ', ' b '),
      );
      final blackPawn = position.board.pcPairs.firstWhere(
        (pair) =>
            pair.piece.numTag == PieceKind.PAWN.code && !pair.piece.isRedSide(),
      );

      expect(position.board.innerBoard.sdPlayer, 1);
      expect(position.board.isSelectable(blackPawn.piece), isTrue);
      expect(position.board.getMoves(blackPawn.sq), hasLength(1));
    });
  });
}
