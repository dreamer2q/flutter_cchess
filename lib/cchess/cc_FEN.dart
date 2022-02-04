import 'cc_piece.dart';

const initialFenString =
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

enum CcPlayerSide { red, black }

mixin CcFenMixin {
  final List<CcPiece> fenBoard = List.filled(
    9 /*columes*/ * 10 /*rows*/,
    CcPiece.blank(),
  );

  final List<CcPieceMov> moves = [];

  CcPlayerSide _playerSide = CcPlayerSide.red;
  CcPlayerSide get currentPlayerSide => _playerSide;
  int get currentPlayerSd => CcPlayerSide.values.indexOf(_playerSide);

  void nextPlayerSide() {
    _playerSide = CcPlayerSide
        .values[(_playerSide.index + 1) % CcPlayerSide.values.length];
  }

  void loadFenString([String fenString = initialFenString]) {
    final parts = fenString.split(' ');
    final fenPos = parts[0];
    if (fenPos.isNotEmpty) {
      final rows = fenPos.split('/');
      assert(rows.length == 10, 'invalid fen format');
      // clear previous fenBoard
      fenBoard.fillRange(0, fenBoard.length, CcPiece.blank());
      // red player first but it's lined at last
      // so reverse it to match its orders
      int i = 0;
      for (final row in rows.reversed) {
        row.split('').forEach((char) {
          if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0) {
            final skipNum = int.tryParse(char) ?? 0;
            i += skipNum;
          } else {
            fenBoard[i] = CcPiece(code: CcPiece.char2code(char));
            i++;
          }
        });
      }
    }
    //TODO add and parse moves
  }

  String toFenString() {
    // TODO export to fenString
    return '';
  }
}
