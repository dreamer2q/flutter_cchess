import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/piece.dart';

import 'package:flutter_cchess/theme/themes/board_theme.dart';
import 'package:flutter_cchess/utils/utils.dart';

class WoodsBoardTheme extends BoardTheme {
  const WoodsBoardTheme();

  @override
  EdgeInsets get boardPadding => const EdgeInsets.symmetric(
        vertical: 3,
        horizontal: 4,
      );

  @override
  String get boardAsset => 'assets/skins/woods/board.jpg';

  @override
  Size get boardSize => const Size(521, 577);

  @override
  String get pieceAssets => 'assets/skins/woods';

  @override
  double get pieceSize => 57;

  @override
  Widget buildBoard(BuildContext context) {
    return Image.asset(boardAsset);
  }

  @override
  Widget buildPiece(BuildContext context, ChessPiece piece) {
    String side = piece.isRedSide() ? 'r' : 'b';
    String char = FenUtil.fenCharacterList[piece.numTag];
    String png = side + char;
    return Image.asset('assets/skins/woods/$png.png');
  }

  @override
  Widget buildPieceMask(BuildContext context) {
    return Container(
      width: pieceSize,
      height: pieceSize,
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.withOpacity(0.6),
        ),
        child: SizedBox(width: 12, height: 12),
      ),
    );
  }

  @override
  Alignment getAlignment(PiecePos pos) {
    int x = SquareBoard.getFileX(pos.sq) - SquareBoard.FILE_LEFT,
        y = SquareBoard.getRankY(pos.sq) - SquareBoard.RANK_TOP;
    return FractionalOffset(x / 8, y / 9);
  }
}
