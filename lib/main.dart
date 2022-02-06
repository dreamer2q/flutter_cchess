import 'package:flutter/material.dart';
import 'package:flutter_cchess/cchess/cc_board.dart';
import 'package:flutter_cchess/cchess/cc_fen.dart';
import 'package:flutter_cchess/cchess/manager.dart';
import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_cchess/widgets/chess_piece.dart';

import 'cchess/cc_piece.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GamePlayPage(),
    );
  }
}

class GamePlayPage extends StatelessWidget {
  const GamePlayPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chinese Chess'),
      ),
      body: FutureBuilder(
        future: GameManager().ready,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          return Chess();
        },
      ),
    );
  }
}

class Chess extends StatefulWidget {
  const Chess({Key? key}) : super(key: key);

  @override
  State<Chess> createState() => _ChessState();
}

class _ChessState extends State<Chess> {
  final game = GameManager.instance;
  final xqwl = XqwlSearch();

  CcBoard get board => game.board;
  bool animating = false;
  CcPiece? _selectedPiece;
  CcPiecePos? _selectedPos;
  CcPiecePos? _destPos;

  void eventHandler(CcPiecePos pos) {
    final piece = board.get(pos);
    if (!piece.isBlank && piece.matchSide(CcPlayerSide.red)) {
      _selectedPos = pos;
      _selectedPiece = piece;
      setState(() {});
      // TODO play sound
    } else if (_selectedPos != null) {
      final move = CcPieceMov(_selectedPos!, pos);
      if (board.isLegalMove(move)) {
        if (board.isCheckedMove(move)) {
          // 不能送死
          return;
        }

        // 检查对手情况
        board.nextPlayerSide();
        if (board.isMated()) {
          // 绝杀无解
          return;
        }

        _destPos = pos;
        board.pushMove(move);
        board.set(_selectedPos!); // remove src piece
        setState(() {
          animating = true;
        });
      } else {
        debugPrint('illegal: $move');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = game.skin;
    final _layers = <Widget>[];

    final layout1 = <Widget>[];
    game.board.forEach((piece, pos) {
      final child = ChessPiece(
        piece: piece,
        alignment: skin.pieceAlign(pos),
      );
      layout1.add(child);
    });

    _layers.addAll([
      /* background */
      Image.asset(game.skin.assetBoard),
      /* pieces */
      Stack(children: layout1),

      /* selected piece */
      if (_selectedPos != null && _destPos == null)
        ChessPiece(
          piece: _selectedPiece!,
          alignment: skin.pieceAlign(_selectedPos!),
          selected: true,
        ),

      /* animated pieces */
      if (_destPos != null)
        AnimatedPieceMove(
          begin: skin.pieceAlign(_selectedPos!),
          end: skin.pieceAlign(_destPos!),
          onEnd: () {
            board.set(_destPos!, _selectedPiece!);
            final mv =
                XqwlPosition.getMove(_selectedPos!.index, _destPos!.index);
            xqwl.pos.makeMove(mv);
            _destPos = null;
            _selectedPos = null;
            setState(() {
              animating = false;
              Future(() {
                xqwl.searchMain();
                xqwl.pos.makeMove(xqwl.mvResult);
                final from =
                    CcPiecePos.fromIndex(XqwlPosition.getSrc(xqwl.mvResult));
                final to =
                    CcPiecePos.fromIndex(XqwlPosition.getDst(xqwl.mvResult));
                final move = CcPieceMov(from, to);
                setState(() {
                  board.movePiece(move);
                  board.nextPlayerSide();
                });
              });
            });
          },
          child: skin.buildPiece(_selectedPiece!),
        ),
    ]);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: GestureDetector(
            onTapUp: (TapUpDetails tap) {
              final position = skin.offsetToPos(tap.localPosition);
              debugPrint('tap: ${tap.localPosition}, $position');
              if (!animating) eventHandler(position);
            },
            child: SizedBox(
              width: skin.width,
              height: skin.height,
              child: Stack(
                fit: StackFit.expand,
                children: _layers,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
