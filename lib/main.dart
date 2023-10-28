import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cchess/cchess/cc_board.dart';
import 'package:flutter_cchess/cchess/cc_fen.dart';
import 'package:flutter_cchess/cchess/manager.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';
import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_cchess/widgets/chess_piece.dart';

import 'package:bloc/bloc.dart';
import 'cchess/cc_piece.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  Bloc.observer = AppBlocObserver();
  runApp(const MyApp());

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
      // debugShowCheckedModeBanner: false,
      // home: const GamePlayPage(),
      home: const ChessPage(),
    );
  }
}

class GamePlayPage extends StatelessWidget {
  const GamePlayPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('Chess'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder(
        future: GameManager().ready,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Chess(),
          );
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
      // mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: FittedBox(
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
        ),
        ChessMenu(),
      ],
    );
  }
}

class ChessMenu extends StatelessWidget {
  const ChessMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MenuItem(
            label: '菜单',
            icon: Icons.menu,
            onPressed: () {},
          ),
          _MenuItem(
            label: '分析',
            icon: Icons.analytics,
            onPressed: () {},
          ),
          _MenuItem(
            label: '悔棋',
            icon: Icons.undo,
            onPressed: () {},
          ),
          _MenuItem(
            label: '提示',
            icon: Icons.info_outline,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    Key? key,
    this.label = '',
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    bool down = false;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: StatefulBuilder(
        builder: (context, setter) {
          final double size = down ? 32 : 38;
          return GestureDetector(
            onTapDown: (details) {
              setter(() {
                down = true;
              });
            },
            onTapUp: (details) {
              setter(() {
                down = false;
              });
            },
            onTap: onPressed,
            child: AnimatedContainer(
              width: size,
              height: size,
              duration: const Duration(milliseconds: 50),
              child: FittedBox(
                child: Column(
                  children: [
                    Icon(icon),
                    Text(label),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
