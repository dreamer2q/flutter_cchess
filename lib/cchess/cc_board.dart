// CChess 棋子位置
import 'package:flutter_cchess/cchess/cc_fen.dart';

class CcPiecePos {
  final int x;
  final int y;

  int get index => (y + CcBoard.rankTop) * 16 + (x + CcBoard.fileLeft);

  CcPiecePos.fromXY(this.x, this.y);
  CcPiecePos.fromIndex(int index)
      : x = (index % 16 - CcBoard.fileLeft),
        y = (index ~/ 16 - CcBoard.rankTop);

  @override
  String toString() {
    return 'CcPiecePos{x: $x, y: $y, index: $index}';
  }
}

class CcBoard {
  static int rankTop = 3;
  static int rankBottom = 12;
  static int fileLeft = 3;
  static int fileRight = 11;

  static List<CcPiece> get initialPosition {
    final _fullBoard = List.filled(256, CcPiece.blank());
    final ccboard = CcFen.fromString().ccboard;
    for (int i = rankTop; i <= rankBottom; i++) {
      for (int j = fileLeft; j <= fileRight; j++) {
        _fullBoard[i * 16 + j] = ccboard[(i - rankTop) * 9 + (j - fileLeft)];
      }
    }
    return _fullBoard;
  }

  final List<CcPiece> board = List.unmodifiable(initialPosition);

  // CcBoard() {
  //   board[0] = CcPiece.blank();
  // }

  void forEach(Function(CcPiece, CcPiecePos) cb) {
    for (int y = 0; y <= rankBottom - rankTop; y++) {
      for (int x = 0; x <= fileRight - fileLeft; x++) {
        final pos = CcPiecePos.fromXY(x, y);
        final piece = board[pos.index];
        if (!piece.isBlank) {
          cb(piece, pos);
        }
      }
    }
  }
}
