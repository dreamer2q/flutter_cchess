import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
            ..add(ChessInitialized(
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
        title: const Text('ChessView'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ChessBoard(),
          ),
        ],
      ),
    );
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
                    final pos = PiecePosition(x, y);
                    bloc.add(ChessBoardTapped(pos));
                  },
                  child: Stack(
                    children: [
                      // chess
                      ...board.pieces.map((p) {
                        final pos = p.position;
                        Widget child = theme.buildPiece(context, p);

                        if (state.animeMoveInvalid?.piece == p) {
                          return const SizedBox();
                        }

                        if (state.selected == p) {
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
                          alignment: FractionalOffset(pos.x / 8, pos.y / 9),
                          child: child,
                        );
                      }).toList(),

                      /// available move actions
                      if (state.selectedMoves != null)
                        ...state.selectedMoves!.map((pos) {
                          // TODO(@dreamer2q) 加入显示延迟过度动画
                          return Align(
                            alignment: theme.getAlignment(pos),
                            child: theme.buildPositionMask(context, pos),
                          );
                        }),

                      /// anime invalid move
                      if (state.animeMoveInvalid != null)
                        AnimatedInvalidMove(
                          begin:
                              theme.getAlignment(state.animeMoveInvalid!.src),
                          end: theme.getAlignment(state.animeMoveInvalid!.dst),
                          child: theme.buildPiece(
                              context, state.animeMoveInvalid!.piece),
                          onEnd: () => context
                              .read<ChessBloc>()
                              .add(const PieceInvalidMoveEnd()),
                        ),

                      /// anime move
                      if (state.animeMove != null)
                        AnimatedMove(
                          begin: theme.getAlignment(state.animeMove!.src),
                          end: theme.getAlignment(state.animeMove!.dst),
                          child:
                              theme.buildPiece(context, state.animeMove!.piece),
                          onEnd: () => context
                              .read<ChessBloc>()
                              .add(const PieceEndMovingEvent()),
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
