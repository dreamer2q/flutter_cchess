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

    return Container(
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .1),
            offset: Offset(2, 3),
            blurRadius: 1,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .1),
            offset: Offset(4, 6),
            blurRadius: 2,
            spreadRadius: 2,
          )
        ],
        //border: Border.all(color: Color.fromRGBO(255, 255, 255, .7), width: 2),
        borderRadius: BorderRadius.all(
          Radius.circular(pieceSize / 2),
        ),
      ),
      child: Image.asset(
        'assets/skins/woods/$png.png',
        fit: BoxFit.fill,
        width: pieceSize,
        height: pieceSize,
      ),
    );
  }

  @override
  Widget buildMovePrint(BuildContext context, bool footprint) {
    if (footprint) {
      return Container(
        width: pieceSize,
        height: pieceSize,
        alignment: Alignment.center,
        padding: EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, .1),
                offset: Offset(2, 3),
                blurRadius: 1,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, .1),
                offset: Offset(4, 6),
                blurRadius: 2,
                spreadRadius: 2,
              )
            ],
            borderRadius: BorderRadius.all(
              Radius.circular(pieceSize / 2),
            ),
          ),
          child: SizedBox.expand(),
        ),
      );
    }

    return Container(
      width: pieceSize,
      height: pieceSize,
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .2),
            offset: Offset(2, 2),
            blurRadius: 1,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .1),
            offset: Offset(3, 3),
            blurRadius: 1,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.white54,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(pieceSize / 2),
        ),
      ),
    );
  }

  @override
  Widget buildSelectedPiece(BuildContext context, ChessPiece piece) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .2),
            offset: Offset(2, 2),
            blurRadius: 1,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .1),
            offset: Offset(3, 3),
            blurRadius: 1,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.white54,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(pieceSize / 2),
        ),
      ),
      child: buildPiece(context, piece),
    );
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
