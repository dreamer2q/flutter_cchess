import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/theme/models/board_skin.dart';

void main() {
  group('BoardAnchors', () {
    const anchors = BoardAnchors(
      topLeft: Offset(50, 50),
      topRight: Offset(850, 50),
      bottomLeft: Offset(50, 950),
      bottomRight: Offset(850, 950),
    );

    test('interpolates all board intersections from four anchors', () {
      expect(anchors.pointFor(0, 0), const Offset(50, 50));
      expect(anchors.pointFor(8, 0), const Offset(850, 50));
      expect(anchors.pointFor(0, 9), const Offset(50, 950));
      expect(anchors.pointFor(8, 9), const Offset(850, 950));
      expect(anchors.pointFor(4, 5), const Offset(450, 550));
    });

    test('aligns corner pieces by their centers', () {
      expect(
        anchors.alignmentFor(
          PiecePos(SquareBoard.coordXYFix(0, 0)),
          boardSize: const Size(900, 1000),
          pieceSize: 100,
        ),
        const Alignment(-1, -1),
      );
      expect(
        anchors.alignmentFor(
          PiecePos(SquareBoard.coordXYFix(8, 9)),
          boardSize: const Size(900, 1000),
          pieceSize: 100,
        ),
        const Alignment(1, 1),
      );
    });

    test('maps taps to the nearest valid intersection', () {
      final position = anchors.hitTest(const Offset(454, 547), radius: 48);

      expect(position, isNotNull);
      expect(
        SquareBoard.getFileX(position!.sq) - SquareBoard.FILE_LEFT,
        4,
      );
      expect(
        SquareBoard.getRankY(position.sq) - SquareBoard.RANK_TOP,
        5,
      );
      expect(anchors.hitTest(const Offset(0, 0), radius: 20), isNull);
    });
  });

  test('night skin manifest contains a complete swappable theme', () async {
    final source = await File('assets/skins/night/config.json').readAsString();
    final skin = BoardSkin.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );

    expect(skin.id, 'night-walnut');
    expect(skin.boardSize, const Size(900, 1000));
    expect(skin.redPieces, hasLength(7));
    expect(skin.blackPieces, hasLength(7));
    expect(skin.mobileBackground, isNotNull);
    expect(skin.desktopBackground, isNotNull);
    expect(skin.pieceAsset(const ChessPiece(8)), endsWith('/rk.png'));
    expect(skin.pieceAsset(const ChessPiece(16)), endsWith('/bk.png'));

    final runtimeAssets = <String>{
      skin.boardAsset,
      ...skin.redPieces.values,
      ...skin.blackPieces.values,
      skin.mobileBackground!,
      skin.desktopBackground!,
    };
    expect(runtimeAssets.every((asset) => File(asset).existsSync()), isTrue);
  });

  test('classic skin uses the same four-anchor contract', () async {
    final source = await File('assets/skins/woods/config.json').readAsString();
    final skin = BoardSkin.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );

    expect(skin.id, 'classic-wood');
    expect(skin.boardAsset, endsWith('/board.jpg'));
    expect(skin.anchors.topLeft, const Offset(32.5, 31.5));
    expect(skin.anchors.bottomRight, const Offset(488.5, 544.5));
    expect(skin.redPieces, hasLength(7));
    expect(skin.blackPieces, hasLength(7));
  });

  test('skin catalog discovers themes without renderer changes', () async {
    final source = await File('assets/skins/catalog.json').readAsString();
    final catalog = BoardSkinCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );

    expect(catalog.configAssets, [
      'assets/skins/woods/config.json',
      'assets/skins/night/config.json',
    ]);
  });
}
