import 'package:flutter_cchess/chess/game/chess_engine.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/utils/board.dart';

class ChessGame {
  ChessGame({
    List<Piece>? initialPieces,
  }) {
    initialPieces?.forEach((p) {
      _delegate.addPiece(p.sq, p.pc);
    });
  }

  final ChessEngine _engine = ChessEngine();
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
    return _delegate.makeMove(BoardUtil.calcMove(src, dst));
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
      final dstPos = BoardUtil.makePosition(dstSq);
      final srcPc = _delegate.ucpcSquares[srcSq];
      final Piece piece = BoardUtil.makePiece(srcSq, srcPc);
      return PieceMove(piece, dstPos);
    }).toList();
  }

  bool isSelectable(Piece selected) {
    final int sideTag = GameBoard.isSideTag(_delegate.sdPlayer);
    return selected.side.code == sideTag;
  }
}
