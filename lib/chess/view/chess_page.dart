import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/chess/widget/animated_invalid_move.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/utils/utils.dart';

import '../bloc/chess_bloc.dart';
import '../widget/animated_move.dart';

class ChessPage extends StatelessWidget {
  const ChessPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ThemeBloc(),
        ),
        BlocProvider(
          create: (_) => ChessBloc()
            ..add(ChessEventInitialized(
              initialBoard: FenUtil.parse(initialFenString),
            )),
        ),
      ],
      child: ChessView(),
    );
  }
}

class ChessView extends StatelessWidget {
  const ChessView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ChessView',
          style: TextStyle(color: Colors.green),
        ),
        shadowColor: Colors.transparent,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ChessBoard(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                child: Text('Restart'),
                onPressed: () {},
              ),
              TextButton(
                child: Text("Hint"),
                onPressed: () {},
              ),
              BlocBuilder<ChessBloc, ChessState>(
                builder: (context, state) => TextButton(
                  onPressed: state.status != BoardStatus.idle
                      ? null
                      : () => context.read<ChessBloc>().add(ChessEventUndo()),
                  child: Text('Undo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MyColor extends MaterialStateColor {
  const MyColor() : super(_defaultColor);

  static const int _defaultColor = 0xcafefeed;
  static const int _pressedColor = 0xdeadbeef;

  @override
  Color resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.pressed)) {
      return const Color(_pressedColor);
    }
    return const Color(_defaultColor);
  }
}

class ChessBoard extends StatelessWidget {
  const ChessBoard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.select((ThemeBloc bloc) => bloc.state.theme);
    final state = context.select((ChessBloc bloc) => bloc.state);
    final board = state.board;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: FittedBox(
        child: SizedBox(
          height: theme.boardSize.height,
          width: theme.boardSize.width,
          child: Stack(
            children: [
              // board (with border)
              // Image.asset('assets/skins/woods/board.jpg'),
              Image.asset(theme.boardAsset),
              // padding is used to remove border
              Padding(
                padding: theme.boardPadding,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails tap) {
                    final bloc = context.read<ChessBloc>();
                    final loc = tap.localPosition;
                    final x = loc.dx ~/ theme.pieceSize;
                    final y = loc.dy ~/ theme.pieceSize;
                    debugPrint('tap: ${tap.localPosition}, {$x,$y}');
                    bloc.add(ChessEventBoardTap(
                      PiecePos(SquareBoard.coordXYFix(x, y)),
                    ));
                  },
                  child: Stack(
                    children: [
                      // chess
                      ...board!.pcPairs.map((p) {
                        int sq = p.sq;

                        if (state.animeMoveInvalid?.sqSrc == sq ||
                            state.animeMove?.sqSrc == sq) {
                          return const SizedBox();
                        }

                        Widget child = theme.buildPiece(context, p.piece);

                        if (state.selected?.sq == p.sq) {
                          child = DecoratedBox(
                            decoration: BoxDecoration(
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
                                Radius.circular(57 / 2),
                              ),
                            ),
                            child: child,
                          );
                        }

                        return Align(
                          alignment: theme.getAlignment(p.pos),
                          child: child,
                        );
                      }).toList(),

                      /// available move actions
                      if (state.selectedMoves != null)
                        ...state.selectedMoves!.map((mv) {
                          // TODO(@dreamer2q) 加入显示延迟过度动画
                          return Align(
                            alignment: theme.getAlignment(mv.dstPos),
                            child: theme.buildPieceMask(context),
                          );
                        }),

                      /// anime invalid move
                      if (state.animeMoveInvalid != null)
                        AnimatedInvalidMove(
                          begin: theme
                              .getAlignment(state.animeMoveInvalid!.srcPos),
                          end: theme
                              .getAlignment(state.animeMoveInvalid!.dstPos),
                          child: theme.buildPiece(
                            context,
                            state.board!
                                .getPiece(state.animeMoveInvalid!.sqSrc)!,
                          ),
                          onEnd: () => context
                              .read<ChessBloc>()
                              .add(const ChessEventMoveEnd()),
                        ),

                      /// anime move
                      if (state.animeMove != null &&
                          state.board!.getPiece(state.animeMove!.sqSrc) != null)
                        AnimatedMove(
                          begin: theme.getAlignment(state.animeMove!.srcPos),
                          end: theme.getAlignment(state.animeMove!.dstPos),
                          child: theme.buildPiece(
                            context,
                            state.board!.getPiece(state.animeMove!.sqSrc)!,
                          ),
                          onEnd: () => context
                              .read<ChessBloc>()
                              .add(const ChessEventMoveEnd()),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
