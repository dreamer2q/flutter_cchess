import 'package:flutter_cchess/cchess/cc_const.dart';

import 'cc_fen.dart';
import 'cc_piece.dart';

class CcBoard with CcFenMixin {
  static int rankTop = 3;
  static int rankBottom = 12;
  static int fileLeft = 3;
  static int fileRight = 11;

  bool get hasMove => moves.isNotEmpty;
  CcPieceMov get lastMove => moves.last;

  CcPieceMov popMove() {
    return moves.removeLast();
  }

  void pushMove(CcPieceMov move) {
    moves.add(move);
  }

  final List<CcPieceMov> availableMoves = [];

  void forEach(Function(CcPiece, CcPiecePos) cb) {
    for (int i = rankTop; i <= rankBottom; i++) {
      for (int j = fileLeft; j <= fileRight; j++) {
        final index = i * 16 + j;
        final piece = chessboard[index];
        if (!piece.isBlank) {
          final pos = CcPiecePos.fromIndex(index);
          cb(piece, pos);
        }
      }
    }
  }

  /// pieces chessboard data
  final List<CcPiece> chessboard = List.filled(256, CcPiece.blank());

  CcBoard() {
    loadFenString();
    setupBoard();
  }

  void setupBoard() {
    chessboard.fillRange(0, chessboard.length, CcPiece.blank());
    int index = 0;
    for (int i = rankTop; i <= rankBottom; i++) {
      for (int j = fileLeft; j <= fileRight; j++) {
        final piece = fenBoard[index++];
        if (!piece.isBlank) {
          chessboard[i * 16 + j] = piece;
        }
      }
    }
  }

  CcPiece get(CcPiecePos pos) {
    return chessboard[pos.index];
  }

  CcPiece set(CcPiecePos pos, [CcPiece piece = const CcPiece.blank()]) {
    final prev = chessboard[pos.index];
    chessboard[pos.index] = piece;
    return prev;
  }

  CcPiece movePiece(CcPieceMov mov) {
    final src = mov.from.index;
    final dst = mov.to.index;
    final capPiece = chessboard[dst];
    chessboard[dst] = chessboard[src];
    chessboard[src] = CcPiece.blank();
    return capPiece;
  }

  void undoMovePiece(CcPieceMov mov, CcPiece prevPiece) {
    final src = mov.from.index;
    final dst = mov.to.index;
    chessboard[src] = chessboard[dst];
    chessboard[dst] = prevPiece;
  }

  bool isCheckedMove(CcPieceMov mov) {
    final capPc = movePiece(mov);
    final checked = isChecked();
    undoMovePiece(mov, capPc);
    return checked;
  }

  bool isChecked() {
    CcPiecePos? kingPos;
    forEach((piece, pos) {
      if (piece.pureCode == 0 /*king*/) {
        kingPos = pos;
      }
    });
    if (kingPos == null) {
      return false; /* missing kind */
    }

    int src = kingPos!.index;
    int oppside = CcRules.getOppSideTag(currentPlayerSd);

    // 1. 判断是否被对方的兵(卒)将军
    if (chessboard[CcRules.squareForward(src, currentPlayerSd)].pieceCode ==
        oppside + 6 /*pawn*/) {
      return true;
    }
    for (final delta in [-1, 1]) {
      if (chessboard[src + delta].pieceCode == oppside + 6 /*pawn*/) {
        return true;
      }
    }

    // 2. 判断是否被对方的马将军(以仕(士)的步长当作马腿)
    for (int i = 0; i < 4; i++) {
      if (!chessboard[src + CcRules.ccAdvisorDelta[i]].isBlank) {
        continue; // knight pin
      }
      for (final delta in CcRules.ccKnightCheckDelta[i]) {
        if (chessboard[src + delta].pieceCode == oppside + 3 /*knight*/) {
          return true;
        }
      }
    }

    // 3. 判断是否被对方的车或炮将军(包括将帅对脸)
    for (final delta in CcRules.ccKingDelta) {
      int dst = src + delta;
      while (CcRules.isInBoard(dst)) {
        final dstPc = chessboard[dst];
        if (!dstPc.isBlank) {
          if (dstPc.pieceCode == oppside + 4 /*rook*/ ||
              dstPc.pieceCode == oppside + 0 /*king*/) {
            return true;
          }
          break;
        }
        dst += delta;
      }
      dst += delta;
      while (CcRules.isInBoard(dst)) {
        final dstPc = chessboard[dst];
        if (!dstPc.isBlank) {
          if (dstPc.pieceCode == oppside + 5 /*cannon*/) {
            return true;
          }
          break;
        }
        dst += delta;
      }
    }

    return false;
  }

  bool isMated() {
    final mvs = generateMoves();
    for (final mv in mvs) {
      final pcCap = movePiece(mv);
      final check = isChecked();
      undoMovePiece(mv, pcCap);
      if (!check) {
        return false;
      }
    }
    return true;
  }

  bool isLegalMove(CcPieceMov mov) {
    final src = mov.from.index;
    final dst = mov.to.index;
    final srcPc = chessboard[src];
    final dstPc = chessboard[dst];

    if (!srcPc.matchSide(currentPlayerSide)) {
      return false;
    }
    if (dstPc.matchSide(currentPlayerSide)) {
      return false;
    }

    switch (srcPc.pureCode) {
      case 0: // king
        return CcRules.isInFort(dst) && CcRules.isKingSpan(src, dst);
      case 1: //advisor
        return CcRules.isInFort(dst) && CcRules.isAdvisorSpan(src, dst);
      case 2: //bishop
        return CcRules.isHomeHalf(src, currentPlayerSd) &&
            CcRules.isBishopSpan(src, dst) &&
            chessboard[CcRules.getBishopPin(src, dst)].isBlank;
      case 3: //knight
        final pin = CcRules.getKnightPin(src, dst);
        return pin != src && chessboard[pin].isBlank;
      case 4: //rook
      // fallthrough
      case 5: //cannon
        int delta;
        if (CcRules.isSameRank(src, dst)) {
          delta = dst < src ? -1 : 1;
        } else if (CcRules.isSameFile(src, dst)) {
          delta = dst < src ? -16 : 16;
        } else {
          return false;
        }
        int pin = src + delta;
        while (pin != dst && chessboard[pin].isBlank) {
          pin += delta;
        }
        if (pin == dst) {
          return dstPc.isBlank || srcPc.pureCode == 4 /*rook*/;
        } else if (!dstPc.isBlank && srcPc.pureCode == 5 /*cannon*/) {
          pin += delta;
          while (pin != dst && chessboard[pin].isBlank) {
            pin += delta;
          }
          return pin == dst;
        }
        break;
      case 6: //pawn
        if (CcRules.isHomeAway(src, currentPlayerSd) &&
            (dst == src - 1 || dst == src + 1)) {
          return true;
        } else {
          return dst == CcRules.squareForward(src, currentPlayerSd);
        }
      default:
        return false;
    }
    return false;
  }

  List<CcPieceMov> generateMoves() {
    final gen = <CcPieceMov>[];

    addmove(int src, int dst) {
      final from = CcPiecePos.fromIndex(src);
      final to = CcPiecePos.fromIndex(src);
      final mv = CcPieceMov(from, to);
      gen.add(mv);
    }

    forEach((piece, pos) {
      if (!piece.matchSide(currentPlayerSide)) {
        return; // 1. 找到本方一个棋子
      }
      final src = pos.index;

      // check king and advisor
      void kingAdvisorDelta(int delta) {
        final dst = src + delta;
        if (CcRules.isInFort(dst)) {
          final pcDst = chessboard[dst];
          if (!pcDst.matchSide(currentPlayerSide)) {
            addmove(src, dst);
          }
        }
      }

      // 2. 根据棋子确定走法
      switch (piece.pieceCode % 8) {
        case 0: // kind
          CcRules.ccKingDelta.forEach(kingAdvisorDelta);
          break;
        case 1: // advisor
          CcRules.ccAdvisorDelta.forEach(kingAdvisorDelta);
          break;
        case 2: // bishop
          for (final delta in CcRules.ccAdvisorDelta) {
            int dst = src + delta;
            if (CcRules.isInBoard(dst) &&
                CcRules.isHomeHalf(dst, currentPlayerSd) &&
                chessboard[dst].isBlank) {
              dst += delta;
              if (!chessboard[dst].matchSide(currentPlayerSide)) {
                addmove(src, dst);
              }
            }
          }
          break;
        case 3: // knight
          for (int i = 0; i < 4; i++) {
            int dst = src + CcRules.ccKingDelta[i];
            if (chessboard[dst].isBlank) continue;
            for (final delta in CcRules.ccKnightDelta[i]) {
              dst = src + delta;
              if (!CcRules.isInBoard(dst)) continue;
              if (!chessboard[dst].matchSide(currentPlayerSide)) {
                addmove(src, dst);
              }
            }
          }
          break;
        case 4: // rook
          for (final delta in CcRules.ccKingDelta) {
            int dst = src + delta;
            while (CcRules.isInBoard(dst)) {
              final dstPc = chessboard[dst];
              if (dstPc.isBlank) {
                addmove(src, dst);
              } else {
                if (!dstPc.matchSide(currentPlayerSide)) {
                  addmove(src, dst);
                }
                break;
              }
              dst += delta;
            }
          }
          break;
        case 5: // cannon
          for (final delta in CcRules.ccKingDelta) {
            int dst = src + delta;
            while (CcRules.isInBoard(dst)) {
              if (chessboard[dst].isBlank) {
                addmove(src, dst);
              } else {
                break;
              }
              dst += delta;
            }
            dst += delta; // skip one piece
            while (CcRules.isInBoard(dst)) {
              final dstPc = chessboard[dst];
              if (!dstPc.isBlank) {
                if (!dstPc.matchSide(currentPlayerSide)) {
                  addmove(src, dst);
                }
                break;
              }
              dst += delta;
            }
          }
          break;
        case 6: // pawn
          int dst = CcRules.squareForward(src, currentPlayerSd);
          if (CcRules.isInBoard(dst)) {
            if (!chessboard[dst].matchSide(currentPlayerSide)) {
              addmove(src, dst);
            }
          }
          if (CcRules.isHomeAway(dst, currentPlayerSd)) {
            for (final delta in [-1, 1]) {
              dst = src + delta;
              if (CcRules.isInBoard(dst)) {
                if (!chessboard[dst].matchSide(currentPlayerSide)) {
                  addmove(src, dst);
                }
              }
            }
          }
          break;
      }
    });

    return gen;
  }
}
