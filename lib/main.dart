import 'package:flutter/material.dart';
import 'package:flutter_cchess/cchess/cc_board.dart';
import 'package:flutter_cchess/cchess/manager.dart';

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
  final game = GameManager();

  @override
  Widget build(BuildContext context) {
    final _layers = <Widget>[];
    final gameBoard = Image.asset(game.skin.assetBoard);
    _layers.add(gameBoard);
    game.board.forEach((piece, pos) {
      _layers.add(
        Align(
          alignment: game.skin.pieceAlign(pos),
          child: Image.asset(
            game.skin.pieceAsset(piece.char),
            width: game.skin.size,
            height: game.skin.size,
          ),
        ),
      );
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: GestureDetector(
            onTapUp: (tap) {
              final w = MediaQuery.of(context).size;
              print('tapUp: ${tap.localPosition}');
              final pos = game.skin.offsetToPos(tap.localPosition);
              print('pos: $pos');
            },
            child: SizedBox(
              width: game.skin.width,
              height: game.skin.height,
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
