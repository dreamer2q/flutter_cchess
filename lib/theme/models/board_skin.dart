import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/piece.dart';

class BoardSkinCatalog {
  const BoardSkinCatalog(this.configAssets);

  final List<String> configAssets;

  static Future<BoardSkinCatalog> load([
    String assetPath = 'assets/skins/catalog.json',
  ]) async {
    final source = await rootBundle.loadString(assetPath);
    return BoardSkinCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory BoardSkinCatalog.fromJson(Map<String, dynamic> json) {
    final themes = json['themes'];
    if (themes is! List || themes.isEmpty) {
      throw const FormatException('themes must be a non-empty list');
    }
    return BoardSkinCatalog(
      themes.map((asset) => _string(asset, 'themes[]')).toList(),
    );
  }

  Future<List<BoardSkin>> loadSkins() {
    return Future.wait(configAssets.map(BoardSkin.load));
  }
}

class BoardSkin {
  const BoardSkin({
    required this.id,
    required this.name,
    required this.boardAsset,
    required this.boardSize,
    required this.anchors,
    required this.pieceSize,
    required this.redPieces,
    required this.blackPieces,
    this.riverLabels = const <String, String>{},
    this.mobileBackground,
    this.desktopBackground,
  });

  final String id;
  final String name;
  final String boardAsset;
  final Size boardSize;
  final BoardAnchors anchors;
  final double pieceSize;
  final Map<String, String> redPieces;
  final Map<String, String> blackPieces;
  final Map<String, String> riverLabels;
  final String? mobileBackground;
  final String? desktopBackground;

  static Future<BoardSkin> load(String assetPath) async {
    final source = await rootBundle.loadString(assetPath, cache: false);
    return BoardSkin.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  factory BoardSkin.fromJson(Map<String, dynamic> json) {
    final board = _map(json['board'], 'board');
    final anchors = _map(board['anchors'], 'board.anchors');
    final pieces = _map(json['pieces'], 'pieces');
    final backgrounds = json['backgrounds'] is Map
        ? Map<String, dynamic>.from(json['backgrounds'] as Map)
        : const <String, dynamic>{};

    return BoardSkin(
      id: _string(json['id'], 'id'),
      name: _string(json['name'], 'name'),
      boardAsset: _string(board['asset'], 'board.asset'),
      boardSize: Size(
        _number(board['width'], 'board.width'),
        _number(board['height'], 'board.height'),
      ),
      anchors: BoardAnchors(
        topLeft: _offset(anchors['topLeft'], 'board.anchors.topLeft'),
        topRight: _offset(anchors['topRight'], 'board.anchors.topRight'),
        bottomLeft: _offset(anchors['bottomLeft'], 'board.anchors.bottomLeft'),
        bottomRight: _offset(
          anchors['bottomRight'],
          'board.anchors.bottomRight',
        ),
      ),
      pieceSize: _number(json['pieceSize'], 'pieceSize'),
      redPieces: _stringMap(pieces['red'], 'pieces.red'),
      blackPieces: _stringMap(pieces['black'], 'pieces.black'),
      riverLabels: json['riverLabels'] is Map
          ? _stringMap(json['riverLabels'], 'riverLabels')
          : const <String, String>{},
      mobileBackground: backgrounds['mobile'] as String?,
      desktopBackground: backgrounds['desktop'] as String?,
    );
  }

  String pieceAsset(ChessPiece piece) {
    const codes = ['k', 'a', 'b', 'n', 'r', 'c', 'p'];
    final assets = piece.isRedSide() ? redPieces : blackPieces;
    final asset = assets[codes[piece.numTag]];
    if (asset == null) {
      throw StateError('Missing piece asset for ${codes[piece.numTag]}');
    }
    return asset;
  }
}

class BoardAnchors {
  const BoardAnchors({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRight;

  Offset pointFor(int file, int rank) {
    assert(file >= 0 && file < 9);
    assert(rank >= 0 && rank < 10);
    final u = file / 8;
    final v = rank / 9;
    final top = Offset.lerp(topLeft, topRight, u)!;
    final bottom = Offset.lerp(bottomLeft, bottomRight, u)!;
    return Offset.lerp(top, bottom, v)!;
  }

  Alignment alignmentFor(
    PiecePos position, {
    required Size boardSize,
    required double pieceSize,
  }) {
    final file = SquareBoard.getFileX(position.sq) - SquareBoard.FILE_LEFT;
    final rank = SquareBoard.getRankY(position.sq) - SquareBoard.RANK_TOP;
    final point = pointFor(file, rank);
    final availableWidth = boardSize.width - pieceSize;
    final availableHeight = boardSize.height - pieceSize;
    return Alignment(
      ((point.dx - pieceSize / 2) / availableWidth) * 2 - 1,
      ((point.dy - pieceSize / 2) / availableHeight) * 2 - 1,
    );
  }

  PiecePos? hitTest(Offset point, {required double radius}) {
    var bestDistance = double.infinity;
    PiecePos? best;
    for (var rank = 0; rank < 10; rank++) {
      for (var file = 0; file < 9; file++) {
        final distance = (pointFor(file, rank) - point).distance;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = PiecePos(SquareBoard.coordXYFix(file, rank));
        }
      }
    }
    return bestDistance <= radius ? best : null;
  }
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object');
  return Map<String, dynamic>.from(value);
}

Map<String, String> _stringMap(Object? value, String field) {
  final source = _map(value, field);
  return source.map((key, value) {
    if (value is! String) throw FormatException('$field.$key must be a string');
    return MapEntry(key, value);
  });
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value;
}

double _number(Object? value, String field) {
  if (value is! num || value <= 0) {
    throw FormatException('$field must be a positive number');
  }
  return value.toDouble();
}

Offset _offset(Object? value, String field) {
  if (value is! List || value.length != 2) {
    throw FormatException('$field must contain x and y');
  }
  final x = value[0];
  final y = value[1];
  if (x is! num || y is! num) {
    throw FormatException('$field must contain numeric coordinates');
  }
  return Offset(x.toDouble(), y.toDouble());
}
