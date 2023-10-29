import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cchess/models/piece.dart';

abstract class BoardTheme extends Equatable {
  const BoardTheme();

  Size get boardSize;

  EdgeInsets get boardPadding;

  String get boardAsset;

  double get pieceSize;

  String get pieceAssets;

  Widget buildBoard(BuildContext context);

  Widget buildPiece(BuildContext context, ChessPiece piece);

  Widget buildSelectedPiece(BuildContext context, ChessPiece piece) =>
      buildPiece(context, piece);

  Widget buildPieceMask(BuildContext context);

  Widget buildMovePrint(BuildContext context, bool footprint);

  Alignment getAlignment(PiecePos pos);

  @override
  List<Object?> get props => [boardSize, boardPadding, pieceSize, pieceAssets];
}
