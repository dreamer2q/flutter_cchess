import 'package:flutter/material.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/theme/models/board_skin.dart';
import 'package:flutter_cchess/theme/themes/board_theme.dart';

class AssetBoardTheme extends BoardTheme {
  const AssetBoardTheme(this.skin);

  final BoardSkin skin;

  static Future<AssetBoardTheme> load(String configAsset) async {
    return AssetBoardTheme(await BoardSkin.load(configAsset));
  }

  @override
  Size get boardSize => skin.boardSize;

  @override
  EdgeInsets get boardPadding => EdgeInsets.zero;

  @override
  String get boardAsset => skin.boardAsset;

  @override
  double get pieceSize => skin.pieceSize;

  @override
  String get pieceAssets => skin.id;

  @override
  Widget buildBoard(BuildContext context) {
    return Image.asset(boardAsset, fit: BoxFit.fill);
  }

  @override
  Widget buildPiece(BuildContext context, ChessPiece piece) {
    return Image.asset(
      skin.pieceAsset(piece),
      width: pieceSize,
      height: pieceSize,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget buildSelectedPiece(BuildContext context, ChessPiece piece) {
    return Container(
      width: pieceSize,
      height: pieceSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDA3A3D), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x66DA3A3D), blurRadius: 8),
        ],
      ),
      child: buildPiece(context, piece),
    );
  }

  @override
  Widget buildPieceMask(BuildContext context) {
    return SizedBox.square(
      dimension: pieceSize,
      child: const Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF49B88B),
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 18),
        ),
      ),
    );
  }

  @override
  Widget buildMovePrint(BuildContext context, bool footprint) {
    return SizedBox.square(
      dimension: pieceSize,
      child: Center(
        child: Container(
          width: footprint ? 18 : 52,
          height: footprint ? 18 : 52,
          decoration: BoxDecoration(
            color: footprint ? const Color(0xFFE3B35C) : Colors.transparent,
            border: footprint
                ? null
                : Border.all(color: const Color(0xFFE3B35C), width: 3),
            borderRadius: BorderRadius.circular(footprint ? 9 : 4),
          ),
        ),
      ),
    );
  }

  @override
  Alignment getAlignment(PiecePos pos) {
    return skin.anchors.alignmentFor(
      pos,
      boardSize: boardSize,
      pieceSize: pieceSize,
    );
  }

  @override
  PiecePos? hitTest(Offset localPosition) {
    return skin.anchors.hitTest(localPosition, radius: pieceSize * .48);
  }
}
