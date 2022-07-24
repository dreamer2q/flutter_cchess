import 'package:equatable/equatable.dart';

enum PieceKind {
  KING(0, 'k'),
  ADVISOR(1, 'a'),
  BISHOP(2, 'b'),
  KNIGHT(3, 'n'),
  ROOK(4, 'r'),
  CANNON(5, 'c'),
  PAWN(6, 'p');

  const PieceKind(this.code, this.char);

  final int code;
  final String char;
}

enum PieceSide {
  RED(8, 'r'),
  BLACK(16, 'b');

  const PieceSide(this.code, this.char);
  final int code;
  final String char;
}

class PiecePosition extends Equatable {
  const PiecePosition(this.x, this.y)
      : assert(x >= 0 && x < 9 && y >= 0 && y < 10);

  factory PiecePosition.fromIndex(int index) {
    return PiecePosition(index % 9, index ~/ 9);
  }

  // [1, 9] from left to right
  final int x;
  // [1, 10] from top to bottom
  final int y;

  PiecePosition copyWith({int? x, int? y}) {
    return PiecePosition(x ?? this.x, y ?? this.y);
  }

  @override
  List<Object?> get props => [x, y];

  @override
  String toString() => '{$x, $y}';
}

class PieceMove extends Equatable {
  const PieceMove(this.piece, this.dst);

  final Piece piece;
  final PiecePosition dst;
  PiecePosition get src => piece.position;
  Piece get dstPiece => piece.copyWith(position: dst);

  @override
  List<Object?> get props => [piece, dst];
}

class Piece extends Equatable {
  // 棋子编号
  // 红黑标记(红子是8，黑子是16)
  const Piece(this.kind, this.side, this.position);

  final PieceKind kind;
  final PieceSide side;
  final PiecePosition position;

  bool isSameSide(Piece p) {
    return side == p.side;
  }

  Piece copyWith({
    PieceKind? kind,
    PieceSide? side,
    PiecePosition? position,
  }) {
    return Piece(
      kind ?? this.kind,
      side ?? this.side,
      position ?? this.position,
    );
  }

  @override
  List<Object?> get props => [kind, side, position];

  @override
  String toString() => 'Piece{${kind.char}, ${side.char}, $position}';
}
