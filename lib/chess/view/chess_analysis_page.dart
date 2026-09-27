import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/analysis_line.dart';
import 'package:flutter_cchess/chess/notation/chinese_notation.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/timer/ticker.dart';

import 'chess_page.dart';

class ChessAnalysisPage extends StatefulWidget {
  const ChessAnalysisPage({
    super.key,
    required this.origin,
    required this.initialFen,
  });

  final Board origin;
  final String initialFen;

  @override
  State<ChessAnalysisPage> createState() => _ChessAnalysisPageState();
}

class _ChessAnalysisPageState extends State<ChessAnalysisPage> {
  late final AnalysisLine _line = AnalysisLine(widget.origin);
  late final ChessBloc _bloc =
      ChessBloc(
        ticker: const Ticker(),
        analysisMode: true,
        initialFen: widget.initialFen,
      )..add(
        ChessEventInitialized(
          initialBoard: _line.origin,
          playMode: PlayMode.withSelf,
          timeControlSeconds: 0,
        ),
      );

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  void _handleState(BuildContext context, ChessState state) {
    final effect = state.activePresentation;
    if (effect?.stage == PresentationStage.feedback) {
      _bloc.add(ChessEventPresentationAcknowledged(effect!.id));
    }
    if (state.board.lastMoves.length == _line.originPly + _line.cursor + 1) {
      if (_line.play(state.board.lastMoves.last)) setState(() {});
    }
  }

  void _seek(int ply) {
    if (_bloc.state.presentations.isNotEmpty || ply == _line.cursor) return;
    setState(() => _line.seek(ply));
    _bloc.add(ChessEventAnalysisLoadBoard(_line.board));
  }

  Future<void> _copyNotation() async {
    if (_line.length == 0) return;
    await Clipboard.setData(
      ClipboardData(text: _line.toRecord(widget.initialFen).encode()),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模拟棋谱已复制')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<ChessBloc, ChessState>(
        listener: _handleState,
        child: BlocBuilder<ChessBloc, ChessState>(
          builder: (context, state) {
            final theme = context.select((ThemeBloc bloc) => bloc.state.theme);
            return Scaffold(
              backgroundColor: const Color(0xFFF0F2F1),
              appBar: AppBar(
                title: const Text('棋局拆解'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '返回对局',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 850;
                  final backdrop = desktop
                      ? theme.desktopBackgroundAsset
                      : theme.mobileBackgroundAsset;
                  return Stack(
                    children: [
                      if (backdrop != null)
                        Positioned.fill(
                          child: Image.asset(backdrop, fit: BoxFit.cover),
                        ),
                      SafeArea(
                        child: desktop
                            ? Row(
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: ChessBoard(),
                                    ),
                                  ),
                                  SizedBox(
                                    width: math.min(
                                      360,
                                      constraints.maxWidth * .32,
                                    ),
                                    child: _movePanel(state),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 8,
                                      ),
                                      child: ChessBoard(),
                                    ),
                                  ),
                                  SizedBox(
                                    height: math.min(
                                      260,
                                      constraints.maxHeight * .4,
                                    ),
                                    child: _movePanel(state),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _movePanel(ChessState state) {
    final notations = ChineseChessNotation.formatHistory(
      _line.fullBoard,
    ).skip(_line.originPly).toList(growable: false);
    final busy = state.presentations.isNotEmpty;
    return Material(
      color: const Color(0xF5F6F7F5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '模拟棋谱',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '复制棋谱',
                  onPressed: _line.length == 0 ? null : _copyNotation,
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  state.phase == GamePhase.finished
                      ? '推演结束'
                      : '轮到${state.board.innerBoard.sdPlayer == 0 ? '红方' : '黑方'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text('${_line.cursor}/${_line.length} 手'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: '回到起点',
                  onPressed: busy || _line.cursor == 0 ? null : () => _seek(0),
                  icon: const Icon(Icons.first_page),
                ),
                IconButton(
                  tooltip: '后退一步',
                  onPressed: busy || _line.cursor == 0
                      ? null
                      : () => _seek(_line.cursor - 1),
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: '前进一步',
                  onPressed: busy || _line.cursor == _line.length
                      ? null
                      : () => _seek(_line.cursor + 1),
                  icon: const Icon(Icons.redo),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '翻转棋盘',
                  onPressed: busy
                      ? null
                      : () => _bloc.add(const ChessEventFlipBoard()),
                  icon: const Icon(Icons.flip_camera_android_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _line.length + 1,
              itemBuilder: (context, index) {
                final start = index == 0;
                final move = start ? null : notations[index - 1];
                return ListTile(
                  dense: true,
                  selected: index == _line.cursor,
                  selectedTileColor: const Color(0x1F23795D),
                  leading: SizedBox(
                    width: 32,
                    child: Text(start ? '·' : '$index.'),
                  ),
                  title: Text(start ? '起始局面' : move!.text),
                  trailing: start ? null : Text(move!.isRed ? '红' : '黑'),
                  onTap: busy ? null : () => _seek(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
