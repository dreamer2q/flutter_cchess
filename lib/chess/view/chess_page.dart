import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cchess/chess/widget/animated_invalid_move.dart';
import 'package:flutter_cchess/chess/widget/animated_overlay.dart';
import 'package:flutter_cchess/chess/widget/chess_menu.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/utils.dart';
import 'package:flutter_cchess/storage/storage.dart';

import '../bloc/chess_bloc.dart';
import '../widget/animated_move.dart';

class ChessPage extends StatelessWidget {
  const ChessPage({Key? key, this.playMode = PlayMode.withAI})
      : super(key: key);

  final PlayMode playMode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildGame(
          SharedPreferencesGameRepository(snapshot.data!),
        );
      },
    );
  }

  Widget _buildGame(GameRepository repository) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ThemeBloc()
            ..add(const ThemeAssetRequested(
              'assets/skins/night/config.json',
            )),
        ),
        BlocProvider(
          create: (_) => ChessBloc(
            ticker: Ticker(),
            repository: repository,
          )..add(ChessEventInitialized(
              initialBoard: FenUtil.parse(initialFenString),
              playMode: playMode,
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

      if (state.playMode == PlayMode.withSelf && state.winningSide != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('对局结束'),
            content: Text(
              state.winningSide == PlaySide.red ? '红方胜利' : '黑方胜利',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
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
                      previous.playStatus != current.playStatus ||
                      previous.winningSide != current.winningSide;
                },
                listener: handleGameStatus,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BlocBuilder<ChessBloc, ChessState>(
                      builder: (context, state) {
                        final s = state.board.innerBoard.evaluate();
                        return Container(
                          child: Row(
                            children: [Text('$s')],
                          ),
                        );
                      },
                    ),
                    const Expanded(child: ChessBoard()),
                  ],
                ),
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
              theme.buildBoard(context),
              // padding is used to remove border
              Padding(
                padding: theme.boardPadding,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails tap) {
                    final bloc = context.read<ChessBloc>();
                    final loc = tap.localPosition;
                    final position = theme.hitTest(loc);
                    if (position == null) return;
                    debugPrint('tap: ${tap.localPosition}, $position');
                    bloc.add(ChessEventBoardTap(position));
                  },
                  child: Stack(
                    children: [
                      /// last move
                      if (state.lastMove != null) ...[
                        Align(
                          alignment: theme.getAlignment(state.lastMove!.srcPos),
                          child: theme.buildMovePrint(context, true),
                        ),
                        Align(
                          alignment: theme.getAlignment(state.lastMove!.dstPos),
                          child: theme.buildMovePrint(context, false),
                        ),
                      ],

                      if (state.animeMove != null)
                        Align(
                          alignment:
                              theme.getAlignment(state.animeMove!.srcPos),
                          child: theme.buildMovePrint(context, true),
                        ),

                      if (state.animeMoveInvalid != null)
                        Align(
                          alignment: theme
                              .getAlignment(state.animeMoveInvalid!.srcPos),
                          child: theme.buildMovePrint(context, true),
                        ),

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
