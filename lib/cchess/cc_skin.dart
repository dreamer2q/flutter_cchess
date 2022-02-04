import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cc_piece.dart';

class CcSkin {
  static const assetPrefix = 'assets/skins';
  static const assetConfig = 'config.json';

  final String name;
  late final double width; // board
  late final double height; // board
  late final double size; // piece
  late final String board;
  late final Offset offset;
  final _piecesMap = <String, String>{};

  CcSkin({
    this.name = 'woods',
  });

  Future init() {
    final configKey = '$assetPrefix/$name/$assetConfig';
    return rootBundle.loadString(configKey).then((configString) {
      final config = json.decode(configString) as Map<String, dynamic>;
      width = config['width'].toDouble();
      height = config['height'].toDouble();
      size = config['size'].toDouble();
      board = config['board'];
      final val = config['offset'];
      offset = Offset(val['dx'].toDouble(), val['dy'].toDouble());
      _piecesMap.addAll(config['red'].cast<String, String>());
      _piecesMap.addAll(config['black'].cast<String, String>());
    });
  }

  String get assetBoard => '$assetPrefix/$name/$board';

  Widget buildPiece(CcPiece piece) {
    if (piece.isBlank) {
      return SizedBox.shrink();
    }
    return Image.asset(
      pieceAsset(piece.pieceChar),
      fit: BoxFit.fill,
      width: size,
      height: size,
    );
  }

  String pieceAsset(String charcode) {
    final piece = _piecesMap[charcode]!;
    return '$assetPrefix/$name/$piece';
  }

  Alignment pieceAlign(CcPiecePos pos) {
    final x = (2 * (pos.x * size + offset.dx)) / (width - size);
    final y = (2 * (pos.y * size + offset.dy)) / (height - size);
    return Alignment(x - 1, y - 1);
  }

  CcPiecePos offsetToPos(Offset tap) {
    final x = (tap.dx - offset.dx) ~/ size;
    final y = (tap.dy - offset.dy) ~/ size;
    return CcPiecePos.fromXY(x, y);
  }

  BoxDecoration get decoration {
    return BoxDecoration(
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
        Radius.circular(size / 2),
      ),
    );
  }

  BoxDecoration get hoverDecoration {
    return BoxDecoration(
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
        Radius.circular(size / 2),
      ),
    );
  }
}
