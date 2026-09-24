import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cchess/models/piece.dart';

abstract class BoardTheme extends Equatable {
  const BoardTheme();

  Size get boardSize;

  EdgeInsets get boardPadding;

  String get boardAsset;

  String? get mobileBackgroundAsset => null;

  String? get desktopBackgroundAsset => null;

  double get pieceSize;

  String get pieceAssets;

  Widget buildBoard(BuildContext context);

  Widget buildBoardSurface(Widget child) => DecoratedBox(
    decoration: const BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0x260F1714),
          offset: Offset(0, 12),
          blurRadius: 26,
          spreadRadius: 2,
        ),
        BoxShadow(color: Color(0x18A07845), blurRadius: 34, spreadRadius: 2),
      ],
    ),
    child: child,
  );

  Widget buildPiece(BuildContext context, ChessPiece piece);

  Widget buildSelectedPiece(BuildContext context, ChessPiece piece) =>
      buildPiece(context, piece);

  Widget buildPieceMask(BuildContext context);

  Widget buildMovePrint(BuildContext context, bool footprint);

  Alignment getAlignment(PiecePos pos);

  PiecePos? hitTest(Offset localPosition);

  @override
  List<Object?> get props => [
    boardSize,
    boardPadding,
    pieceSize,
    pieceAssets,
    mobileBackgroundAsset,
    desktopBackgroundAsset,
  ];
}
