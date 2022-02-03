/// 红方  黑方 字母	 数字
/// 帅	  将	 K	    1
/// 仕	  士	 A	    2
/// 相	  象	 B      3
/// 马	  马	 N      4
/// 车	  车	 R	    5
/// 炮	  炮	 C	    6
/// 兵	  卒	 P	    7
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
/// 车(r) 马(n) 相(b) 仕(a) 帅(K) 仕(a) 相(b) 马(n) 车(r)
/// ==================================================
///
const _initialFenString =
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

enum CcPlayerSide { red, black }

class CcPiece {
  static const nameMap = {
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

  int _code = 0;

  bool get isBlank => _code == 0;

  int get code => _code;
  String get char => side == CcPlayerSide.black
      ? charsMap[_code % 8].toUpperCase()
      : charsMap[_code % 8];

  CcPlayerSide get side =>
      (_code & bitRedSide > 0) ? CcPlayerSide.red : CcPlayerSide.black;

  CcPiece.blank();

  CcPiece.fromChar(String char) {
    if (char.toUpperCase() == char) {
      _code = codesMap[char.toLowerCase()]! | bitBlackSide;
    } else {
      _code = codesMap[char]! | bitRedSide;
    }
  }
}

class CcFen {
  final List<CcPiece> _ccBoard = List.filled(
    9 /*columes*/ * 10 /*rows*/,
    CcPiece.blank(),
  );

  List<CcPiece> get ccboard => _ccBoard;

  String get fenString {
    // TODO generate fenString from _ccBoard
    return _initialFenString;
  }

  CcFen.fromString([String fenString = _initialFenString]) {
    final parts = fenString.split(' ');
    final fenPos = parts[0];
    if (fenPos.isNotEmpty) {
      final rows = fenPos.split('/');
      assert(rows.length == 10, 'invalid fen format');
      int i = 0;
      // red first but lines at last
      // so reverse it to match its orders
      for (final row in rows.reversed) {
        row.split('').forEach((char) {
          if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0) {
            final skipNum = int.tryParse(char) ?? 0;
            i += skipNum;
          } else {
            _ccBoard[i++] = CcPiece.fromChar(char);
          }
        });
      }
    }
    //TODO add and parse moves
  }
}

class CcMove {
  final int from;
  final int to;

  CcMove(this.from, this.to);

  CcMove copyWith({
    int? from,
    int? to,
  }) {
    return CcMove(from ?? this.from, to ?? this.to);
  }
}
