import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/chess/widget/animated_invalid_move.dart';
import 'package:flutter_cchess/chess/widget/animated_overlay.dart';
import 'package:flutter_cchess/chess/widget/chess_menu.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/timer/ticker.dart';
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
          create: (_) => ChessBloc(ticker: Ticker())
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
    handleGameStatus(BuildContext context, ChessState state) {
      if (state.playEffect != null) {
        PlayEffect playEffect = state.playEffect!;
        switch (playEffect) {
          case PlayEffect.check:
            AnimatedOverlay.show(
              context: context,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  child: Text(
                    '将军',
                    style: TextStyle(fontSize: 32),
                  ),
                ),
              ),
            );
            break;

          case PlayEffect.eat:
            AnimatedOverlay.show(
              context: context,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  child: Text(
                    '吃',
                    style: TextStyle(
                      fontSize: 48,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            );
            break;

          case PlayEffect.mate:
            AnimatedOverlay.show(
              context: context,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  child: Text(
                    '绝杀',
                    style: TextStyle(
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
            );
            break;
        }
      }

      if (state.playStatus != null) {
        PlayStatus status = state.playStatus!;
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Game Over"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == PlayStatus.win) Text("You win!"),
                  if (status == PlayStatus.lose) Text("You lose!"),
                  if (status == PlayStatus.draw) Text("draw!"),
                ],
              ),
            );
          },
        );
      }
    }

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close),
            color: Colors.black,
            onPressed: () {},
          ),
          title: const Text(
            'ChessView',
            style: TextStyle(color: Colors.green),
          ),
          shadowColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          actions: [],
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocListener<ChessBloc, ChessState>(
                listenWhen: (previous, current) {
                  return previous.playEffect != current.playEffect ||
                      previous.playStatus != current.playStatus;
                },
                listener: handleGameStatus,
                child: ChessBoard(),
              ),
            ),
            ChessBoardMenu(),
            SizedBox(height: 12),
          ],
        ),
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
                    bloc.add(ChessEventBoardTap(
                      PiecePos(SquareBoard.coordXYFix(x, y)),
                    ));
                  },
                  child: Stack(
                    children: [
                      // chess
                      ...board.pcPairs.map((p) {
                        int sq = p.sq;

                        if (state.animeMoveInvalid?.sqSrc == sq ||
                            state.animeMove?.sqSrc == sq) {
                          return const SizedBox();
                        }

                        Widget child;
                        if (state.selected?.sq == p.sq) {
                          child = theme.buildSelectedPiece(context, p.piece);
                        } else {
                          child = theme.buildPiece(context, p.piece);
                        }

                        return Align(
                          alignment: theme.getAlignment(p.pos),
                          child: child,
                        );
                      }).toList(),

                      /// available move actions
                      if (state.selectedMoves != null)
                        ...state.selectedMoves!.map((mv) {
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
                            state.board
                                .getPiece(state.animeMoveInvalid!.sqSrc)!,
                          ),
                          onEnd: () => context
                              .read<ChessBloc>()
                              .add(const ChessEventMoveEnd()),
                        ),

                      /// anime move
                      if (state.animeMove != null &&
                          state.board.getPiece(state.animeMove!.sqSrc) != null)
                        AnimatedMove(
                          begin: theme.getAlignment(state.animeMove!.srcPos),
                          end: theme.getAlignment(state.animeMove!.dstPos),
                          child: theme.buildPiece(
                            context,
                            state.board.getPiece(state.animeMove!.sqSrc)!,
                          ),
                          onEnd: () => context
                              .read<ChessBloc>()
                              .add(const ChessEventMoveEnd()),
                        ),

                      /// hints
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
