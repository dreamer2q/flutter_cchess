import 'package:flutter/material.dart';
import 'package:flutter_cchess/models/piece.dart';

import 'package:flutter_cchess/theme/themes/board_theme.dart';

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
  Widget buildPiece(BuildContext context, Piece piece) {
    final png = piece.side.char + piece.kind.char;
    return Image.asset('assets/skins/woods/$png.png');
  }

  @override
  Widget buildPositionMask(BuildContext context, PiecePosition position) {
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
  Alignment getAlignment(PiecePosition position) {
    return FractionalOffset(
      position.x / 8,
      position.y / 9,
    );
  }
}
