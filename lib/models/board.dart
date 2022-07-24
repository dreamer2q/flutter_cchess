import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/models/piece.dart';

import 'package:built_collection/built_collection.dart';

extension _PiecePositionEx on PiecePosition {
  int get rawIndex => y * 16 + x;
}

class Board extends Equatable {
  Board({
    required this.pieces,
    required this.moves,
  }) : _rawBoard = Uint8List(256) {
    for (final p in pieces) {
      final int i = p.position.rawIndex;
      _rawBoard[i] = p.side.code | p.kind.code;
    }
  }

  final BuiltList<Piece> pieces;
  final BuiltList<PieceMove> moves;
  final Uint8List _rawBoard;

  Piece? get(PiecePosition position) {
    if (_rawBoard[position.rawIndex] == 0) {
      return null;
    }
    return pieces.firstWhere((p) => p.position == position);
  }

  // bool makeMove(PieceMove move) {}
  BuiltList<PieceMove> addMove(PieceMove move) {
    return moves.rebuild((b) => b.add(move));
  }

  Board removePiece(Piece? piece) {
    return copyWith(
      pieces: pieces.rebuild((p) => p.remove(piece)),
    );
  }

  Board addPiece(Piece piece) {
    return copyWith(
      pieces: pieces.rebuild((p) => p.add(piece)),
    );
  }

  @override
  List<Object?> get props => [pieces, moves];

  @override
  String toString() => 'Board{pieces: $pieces, moves: $moves}';

  Board copyWith({
    BuiltList<Piece>? pieces,
    BuiltList<PieceMove>? moves,
  }) {
    return Board(
      pieces: pieces ?? this.pieces,
      moves: moves ?? this.moves,
    );
  }
}
