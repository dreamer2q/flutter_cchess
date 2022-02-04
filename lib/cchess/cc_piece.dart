import 'cc_board.dart';
import 'cc_fen.dart';

/// ==================================================
/// 車(R) 馬(B) 象(B) 士(A) 将(K) 士(A) 象(B) 馬(N) 車(R)
///
///       砲(C)                             砲(C)
/// 卒(P)       卒(P)      卒(P)       卒(P)       卒(P)
/// --------------------------------------------------
/// --------------------------------------------------
/// 兵(p)       兵(p)      兵(p)       兵(p)       兵(p)
///       炮(c)                             炮(r)
///
/// 车(r) 马(n) 相(b) 仕(a) 帅(k) 仕(a) 相(b) 马(n) 车(r)
/// ==================================================
///
/// 红方  黑方 字母	 数字
/// 帅	  将	 K	    1
/// 仕	  士	 A	    2
/// 相	  象	 B      3
/// 马	  马	 N      4
/// 车	  车	 R	    5
/// 炮	  炮	 C	    6
/// 兵	  卒	 P	    7
const nameMap = {
  '将': 'k',
  '帅': 'K',
  '士': 'a',
  '仕': 'A',
  '象': 'b',
  '相': 'B',
  '马': 'n',
  '车': 'r',
  '炮': 'c',
  '砲': 'C',
  '卒': 'p',
  '兵': 'P',
  'k': '帅',
  'a': '仕',
  'b': '相',
  'n': '马',
  'r': '车',
  'c': '砲',
  'p': '兵',
  'K': '将',
  'A': '士',
  'B': '象',
  'N': '马',
  'R': '车',
  'C': '炮',
  'P': '卒',
};

class CcPiecePos {
  final int index;

  int get x => (index % 16 - CcBoard.fileLeft);
  int get y => (index ~/ 16 - CcBoard.rankTop);

  bool get isValid => (x >= 0 || x < 9) && (y >= 0 || y < 10);
  bool get isZero => index == 0;

  CcPiecePos.fromXY(int x, int y)
      : index = (y + CcBoard.rankTop) * 16 + (x + CcBoard.fileLeft);

  CcPiecePos.fromIndex(this.index);

  CcPiecePos.zero() : index = 0;

  @override
  String toString() {
    return 'CcPiecePos{x: $x, y: $y, index: $index}';
  }

  @override
  int get hashCode => index.hashCode;

  @override
  operator ==(Object other) {
    if (other is CcPiecePos) {
      return index == other.index;
    }
    return false;
  }
}

class CcPieceMov {
  final CcPiecePos from;
  final CcPiecePos to;

  CcPieceMov(this.from, this.to);

  @override
  String toString() {
    return 'CcPieceMove:{from: $from, to: $to}';
  }

  CcPieceMov copyWith({
    CcPiecePos? from,
    CcPiecePos? to,
  }) {
    return CcPieceMov(from ?? this.from, to ?? this.to);
  }
}

class CcPiece {
  static const codesMap = {
    'k': 0,
    'a': 1,
    'b': 2,
    'n': 3,
    'r': 4,
    'c': 5,
    'p': 6,
  };
  static const charsMap = ['k', 'a', 'b', 'n', 'r', 'c', 'p'];
  static const bitBlackSide = 1 << 4;
  static const bitRedSide = 1 << 3;

  static int char2code(String char) {
    if (char.toUpperCase() == char) {
      // black piece
      return codesMap[char.toLowerCase()]! | bitBlackSide;
    } else {
      // red piece
      return codesMap[char]! | bitRedSide;
    }
  }

  static String code2char(int code) {
    if (code & bitRedSide > 0) {
      // red piece
      return charsMap[code % 8];
    } else {
      // black piece
      return charsMap[code % 8].toUpperCase();
    }
  }

  /// piece code
  final int _piece;

  bool get isBlank => _piece == 0;

  int get pieceCode => _piece;

  int get pureCode => _piece % 8;

  String get pieceChar => code2char(pieceCode);

  CcPlayerSide get playerSide =>
      pieceCode & bitRedSide > 0 ? CcPlayerSide.red : CcPlayerSide.black;

  bool matchSide(CcPlayerSide side) {
    return !isBlank && side == playerSide;
  }

  const CcPiece.blank() : _piece = 0;

  CcPiece({required int code}) : _piece = code;

  CcPiece copyWith({
    int? code,
    int? index,
  }) =>
      CcPiece(code: code ?? _piece);
}
