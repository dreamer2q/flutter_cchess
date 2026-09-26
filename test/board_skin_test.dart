import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/theme/models/board_skin.dart';
import 'package:flutter_cchess/chess/theme/wood_theme.dart';

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
      expect(SquareBoard.getFileX(position!.sq) - SquareBoard.FILE_LEFT, 4);
      expect(SquareBoard.getRankY(position.sq) - SquareBoard.RANK_TOP, 5);
      expect(anchors.hitTest(const Offset(0, 0), radius: 20), isNull);
    });
  });

  test('night skin manifest contains a complete swappable theme', () async {
    final source = await File('assets/skins/night/config.json').readAsString();
    final skin = BoardSkin.fromJson(jsonDecode(source) as Map<String, dynamic>);

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
    final skin = BoardSkin.fromJson(jsonDecode(source) as Map<String, dynamic>);

    expect(skin.id, 'classic-wood');
    expect(skin.boardAsset, endsWith('/board.jpg'));
    expect(skin.anchors.topLeft, const Offset(32.5, 31.5));
    expect(skin.anchors.bottomRight, const Offset(488.5, 544.5));
    expect(skin.redPieces, hasLength(7));
    expect(skin.blackPieces, hasLength(7));

    const theme = WoodsBoardTheme();
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 9; x++) {
        final pos = PiecePos(SquareBoard.coordXYFix(x, y));
        final alignment = theme.getAlignment(pos);
        final content = Size(
          theme.boardSize.width - theme.boardPadding.horizontal,
          theme.boardSize.height - theme.boardPadding.vertical,
        );
        final center = Offset(
          theme.boardPadding.left +
              theme.pieceSize / 2 +
              (alignment.x + 1) * (content.width - theme.pieceSize) / 2,
          theme.boardPadding.top +
              theme.pieceSize / 2 +
              (alignment.y + 1) * (content.height - theme.pieceSize) / 2,
        );
        expect(center.dx, closeTo(skin.anchors.pointFor(x, y).dx, .01));
        expect(center.dy, closeTo(skin.anchors.pointFor(x, y).dy, .01));
        expect(theme.hitTest(center - theme.boardPadding.topLeft), pos);
      }
    }
  });

  test('night skin matches the anchor-driven asset contract', () async {
    final source = await File('assets/skins/night/config.json').readAsString();
    final skin = BoardSkin.fromJson(jsonDecode(source) as Map<String, dynamic>);

    expect(skin.id, 'night-walnut');
    expect(skin.boardSize, const Size(900, 1000));
    expect(skin.anchors.topLeft, const Offset(50, 50));
    expect(skin.anchors.bottomRight, const Offset(850, 950));
    expect(skin.redPieces, hasLength(7));
    expect(skin.blackPieces, hasLength(7));

    final runtimeAssets = <String>{
      skin.boardAsset,
      ...skin.redPieces.values,
      ...skin.blackPieces.values,
    };
    expect(runtimeAssets.every((asset) => File(asset).existsSync()), isTrue);
  });

  test('warm wood skin keeps the licensed board and pieces modular', () async {
    final source = await File(
      'assets/skins/qqclassic/config.json',
    ).readAsString();
    final skin = BoardSkin.fromJson(jsonDecode(source) as Map<String, dynamic>);

    expect(skin.id, 'qqclassic-warm-wood');
    expect(skin.boardSize, const Size(628, 730));
    expect(skin.anchors.topLeft, const Offset(44, 61));
    expect(skin.anchors.bottomRight, const Offset(585, 668));
    expect(skin.redPieces, hasLength(7));
    expect(skin.blackPieces, hasLength(7));
    expect(skin.riverLabels, {'left': '楚河', 'right': '汉界'});
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

  test('skin catalog discovers themes without renderer changes', () async {
    final source = await File('assets/skins/catalog.json').readAsString();
    final catalog = BoardSkinCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );

    expect(catalog.configAssets, [
      'assets/skins/woods/config.json',
      'assets/skins/night/config.json',
      'assets/skins/qqclassic/config.json',
    ]);
  });
}
