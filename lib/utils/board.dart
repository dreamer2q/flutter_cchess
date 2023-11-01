import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/piece.dart';

// extension PiecePositionEx on PiecePosition {
//   int get sq => (SquareBoard.RANK_TOP + y) * 16 + (SquareBoard.FILE_LEFT + x);
// }

// extension PieceEx on Piece {
//   int get pc => side.code | kind.code;
//   int get sq => position.sq;
// }

// abstract class BoardUtil {
//   static int calcMove(PiecePosition src, PiecePosition dst) {
//     return src.sq | (dst.sq << 8);
//   }

//   static PiecePosition makePosition(int sq) {
//     final x = SquareBoard.getFileX(sq) - SquareBoard.FILE_LEFT;
//     final y = SquareBoard.getRankY(sq) - SquareBoard.RANK_TOP;
//     return PiecePosition(x, y);
//   }

//   static Piece makePiece(int sq, int pc) {
//     final PieceSide side =
//         SquareBoard.getSideTag(pc) == 1 ? PieceSide.RED : PieceSide.BLACK;
//     final PieceKind kind = PieceKind.values[pc & 0x07];
//     final PiecePosition position = makePosition(sq);
//     return Piece(kind, side, position);
//   }
// }
