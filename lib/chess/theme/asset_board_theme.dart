import 'package:flutter/material.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/chess/theme/board_corner_marker.dart';
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
  String? get mobileBackgroundAsset => skin.mobileBackground;

  @override
  String? get desktopBackgroundAsset => skin.desktopBackground;

  @override
  double get pieceSize => skin.pieceSize;

  @override
  String get pieceAssets => skin.id;

  @override
  Widget buildBoard(BuildContext context) {
    final riverStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF92734C),
      fontSize: 30,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
    return buildBoardSurface(
      SizedBox(
        width: boardSize.width,
        height: boardSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(boardAsset, fit: BoxFit.fill),
            if (skin.riverLabels['left'] case final left?)
              Positioned(
                left: boardSize.width * .22,
                top: boardSize.height / 2 - 18,
                width: boardSize.width * .24,
                child: Text(
                  left,
                  textAlign: TextAlign.center,
                  style: riverStyle,
                ),
              ),
            if (skin.riverLabels['right'] case final right?)
              Positioned(
                right: boardSize.width * .22,
                top: boardSize.height / 2 - 18,
                width: boardSize.width * .24,
                child: Text(
                  right,
                  textAlign: TextAlign.center,
                  style: riverStyle,
                ),
              ),
          ],
        ),
      ),
    );
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
    return BoardCornerMarker(
      dimension: pieceSize,
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
