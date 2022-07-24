import 'package:flutter_cchess/chess/game/positions.dart';
import 'package:flutter_cchess/models/piece.dart';

extension _PieceEx on Piece {
  int get pc => side.code | kind.code;
  int get sq => position.sq;
}

extension _PiecePosEx on PiecePosition {
  int get sq => (GameBoard.RANK_TOP + y) * 16 + (GameBoard.FILE_LEFT + x);
}

extension _MoveEx on PieceMove {}

int _calcMove(PiecePosition src, PiecePosition dst) {
  return src.sq | (dst.sq << 8);
}

PiecePosition _parsePosition(int sq) {
  final x = GameBoard.getFileX(sq) - GameBoard.FILE_LEFT;
  final y = GameBoard.getRankY(sq) - GameBoard.RANK_TOP;
  return PiecePosition(x, y);
}

Piece _makePiece(int sq, int pc) {
  final PieceSide side =
      GameBoard.getSideTag(pc) == 1 ? PieceSide.RED : PieceSide.BLACK;
  final PieceKind kind = PieceKind.values[pc & 0x07];
  final PiecePosition position = _parsePosition(sq);
  return Piece(kind, side, position);
}

class ChessGame {
  ChessGame({
    List<Piece>? initialPieces,
  }) {
    initialPieces?.forEach((p) {
      _delegate.addPiece(p.sq, p.pc);
    });
  }

  final GameBoard _delegate = GameBoard();
  List<PieceMove> _validMoves = [];
  List<PieceMove> get validMoves => _validMoves;

  void resetBoard({
    List<Piece>? initialPieces,
    List<PieceMove>? initialMoves,
  }) {
    _delegate.reset();
    initialPieces?.forEach((p) {
      _delegate.addPiece(p.sq, p.pc);
    });
  }

  int get player => _delegate.sdPlayer;

  bool makeMove(PiecePosition src, PiecePosition dst) {
    final int moveIndex =
        validMoves.indexWhere((mv) => mv.src == src && mv.dst == dst);
    if (moveIndex == -1) {
      return false;
    }
    return _delegate.makeMove(_calcMove(src, dst));
  }

  List<PiecePosition> getPieceMoves(Piece piece) {
    return validMoves
        .where((move) => move.piece == piece)
        .map((move) => move.dst)
        .toList();
  }

  /// 获取当前局面所有合法的状态变换
  void prepareMoves() {
    final List<int> mvs = [];
    _delegate.generateMoves(mvs);
    _validMoves = mvs.map((mv) {
      final int srcSq = GameBoard.getSrc(mv);
      final int dstSq = GameBoard.getDst(mv);
      final dstPos = _parsePosition(dstSq);
      final srcPc = _delegate.ucpcSquares[srcSq];
      final Piece piece = _makePiece(srcSq, srcPc);
      return PieceMove(piece, dstPos);
    }).toList();
  }

  bool isSelectable(Piece selected) {
    final int sideTag = GameBoard.isSideTag(_delegate.sdPlayer);
    return selected.side.code == sideTag;
  }
}
