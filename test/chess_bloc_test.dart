import 'dart:async';

import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/game.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initializes local game and persists its initial snapshot', () async {
    final repository = InMemoryGameRepository();
    final bloc = _bloc(repository: repository);

    await _initialize(bloc, PlayMode.withSelf);
    expect(bloc.state.phase, GamePhase.playerTurn);
    await bloc.flushPersistence();
    expect((await repository.getCurrent())?.mode, GamePlayMode.self);
    await bloc.close();
  });

  test('legal move commits before presentation is acknowledged', () async {
    final bloc = _bloc();
    await _initialize(bloc, PlayMode.withSelf);
    final move = bloc.state.board.getMoves().first;

    bloc.add(ChessEventMoveRequested(move));
    await _waitFor(bloc, (s) => s.board.lastMoves.length == 1);
    final effect = bloc.state.activePresentation!;
    expect(effect.move, move);
    expect(effect.beforeBoard.lastMoves, isEmpty);
    expect(effect.afterBoard.lastMoves, [move]);

    bloc.add(ChessEventPresentationAcknowledged(effect.id));
    await _waitFor(bloc, (s) => s.presentations.isEmpty);
    expect(bloc.state.board.lastMoves, [move]);
    await bloc.close();
  });

  test(
    'stale presentation acknowledgement cannot consume a new effect',
    () async {
      final bloc = _bloc();
      await _initialize(bloc, PlayMode.withSelf);
      final move = bloc.state.board.getMoves().first;
      bloc.add(ChessEventMoveRequested(move));
      await _waitFor(bloc, (s) => s.presentations.isNotEmpty);
      final id = bloc.state.activePresentation!.id;

      bloc.add(ChessEventPresentationAcknowledged(id + 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.activePresentation?.id, id);
      await bloc.close();
    },
  );

  test('invalid move retains selection and creates unique effects', () async {
    final bloc = _bloc();
    await _initialize(bloc, PlayMode.withSelf);
    final pair = bloc.state.board.pcPairs.firstWhere(
      (candidate) => bloc.state.board.isSelectable(candidate.piece),
    );
    bloc.add(ChessEventBoardTap(pair.pos));
    await _waitFor(bloc, (s) => s.selected != null);
    final invalid = MovePos(pair.sq, pair.sq);

    bloc.add(ChessEventMoveRequested(invalid));
    await _waitFor(bloc, (s) => s.presentations.isNotEmpty);
    final first = bloc.state.activePresentation!;
    expect(first.kind, PresentationEffectKind.invalidMove);
    expect(bloc.state.selected?.sq, pair.sq);
    bloc.add(ChessEventPresentationAcknowledged(first.id));
    await _waitFor(bloc, (s) => s.presentations.isEmpty);

    bloc.add(ChessEventMoveRequested(invalid));
    await _waitFor(bloc, (s) => s.presentations.isNotEmpty);
    expect(bloc.state.activePresentation!.id, isNot(first.id));
    await bloc.close();
  });

  test('fast AI result queues behind human presentation', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final human = bloc.state.board.getMoves().first;
    bloc.add(ChessEventMoveRequested(human));
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);
    final ai = bloc.state.board.getMoves().first;
    engine.makeMoveCompleter.complete(ai.mv);

    await _waitFor(bloc, (s) => s.board.lastMoves.length == 2);
    expect(bloc.state.presentations.map((e) => e.move), [human, ai]);
    expect(bloc.state.phase, GamePhase.playerTurn);
    final humanId = bloc.state.presentations.first.id;
    final aiId = bloc.state.presentations.last.id;
    bloc.add(ChessEventPresentationAcknowledged(humanId));
    await _waitFor(bloc, (s) => s.activePresentation?.id == aiId);
    await bloc.close();
  });

  test('restored AI turn resumes and commits the computer move', () async {
    final engine = ControlledChessEngine();
    final initial = FenUtil.parse(initialFenString);
    final human = initial.getMoves().first;
    final restored = _apply(initial, human);
    final bloc = _bloc(engine: engine);

    bloc.add(ChessEventInitialized(initialBoard: restored));
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);
    expect(engine.restoredMoves, [human.mv]);
    final ai = restored.getMoves().first;
    engine.resumeMoveCompleter.complete(ai.mv);
    await _waitFor(bloc, (s) => s.board.lastMoves.length == 2);
    expect(bloc.state.board.lastMoves.last, ai);
    await bloc.close();
  });

  test('AI result is committed while paused and shown after resume', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final human = bloc.state.board.getMoves().first;
    bloc.add(ChessEventMoveRequested(human));
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);
    final ai = bloc.state.board.getMoves().first;
    bloc.add(const ChessEventPause());
    await _waitFor(bloc, (s) => s.phase == GamePhase.paused);
    engine.makeMoveCompleter.complete(ai.mv);
    await _waitFor(bloc, (s) => s.board.lastMoves.length == 2);
    expect(bloc.state.phase, GamePhase.paused);

    bloc.add(const ChessEventResume());
    await _waitFor(bloc, (s) => s.phase == GamePhase.playerTurn);
    await bloc.close();
  });

  test('resigning invalidates a later AI result', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final human = bloc.state.board.getMoves().first;
    bloc.add(ChessEventMoveRequested(human));
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);
    final ai = bloc.state.board.getMoves().first;
    bloc.add(const ChessEventResign());
    await _waitFor(bloc, (s) => s.phase == GamePhase.finished);
    engine.makeMoveCompleter.complete(ai.mv);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.board.lastMoves, [human]);
    expect(bloc.state.winningSide, PlaySide.black);
    await bloc.close();
  });

  test('hint never commits a move', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final hint = bloc.state.board.getMoves().first;
    bloc.add(const ChessEventGetHint());
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);
    engine.hintCompleter.complete(hint.mv);
    await _waitFor(bloc, (s) => s.hintMoves.isNotEmpty);
    expect(bloc.state.board.lastMoves, isEmpty);
    expect(bloc.state.phase, GamePhase.playerTurn);
    await bloc.close();
  });

  test(
    'local undo commits immediately and emits reverse presentation',
    () async {
      final bloc = _bloc();
      await _initialize(bloc, PlayMode.withSelf);
      final move = bloc.state.board.getMoves().first;
      bloc.add(ChessEventMoveRequested(move));
      await _waitFor(bloc, (s) => s.board.lastMoves.length == 1);
      bloc.add(
        ChessEventPresentationAcknowledged(bloc.state.activePresentation!.id),
      );
      await _waitFor(bloc, (s) => s.presentations.isEmpty);

      bloc.add(const ChessEventUndo());
      await _waitFor(
        bloc,
        (s) => s.board.lastMoves.isEmpty && s.presentations.isNotEmpty,
      );
      expect(bloc.state.activePresentation!.kind, PresentationEffectKind.undo);
      await bloc.close();
    },
  );

  test('flip only changes presentation orientation', () async {
    final bloc = _bloc();
    await _initialize(bloc, PlayMode.withSelf);
    final board = bloc.state.board;
    bloc.add(const ChessEventFlipBoard());
    await _waitFor(bloc, (s) => s.boardFlipped);
    expect(bloc.state.board, board);
    await bloc.close();
  });
}

Board _apply(Board board, MovePos move) => board.copyWith(
  actions: board.actions.rebuild((b) => b..add(BoardMoveAction(move.mv))),
);

ChessBloc _bloc({GameRepository? repository, ChessEnginePort? engine}) =>
    ChessBloc(ticker: Ticker(), repository: repository, engine: engine);

Future<void> _initialize(ChessBloc bloc, PlayMode mode) async {
  bloc.add(
    ChessEventInitialized(
      initialBoard: FenUtil.parse(initialFenString),
      playMode: mode,
    ),
  );
  await _waitFor(bloc, (s) => s.phase == GamePhase.playerTurn);
}

Future<ChessState> _waitFor(
  ChessBloc bloc,
  bool Function(ChessState state) predicate,
) async {
  if (predicate(bloc.state)) return bloc.state;
  return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 2));
}

class ControlledChessEngine implements ChessEnginePort {
  final Completer<int> makeMoveCompleter = Completer<int>();
  final Completer<int> hintCompleter = Completer<int>();
  final Completer<int> resumeMoveCompleter = Completer<int>();
  final List<int> restoredMoves = <int>[];
  bool disposed = false;

  @override
  Future<int> makeMove(int mv) => makeMoveCompleter.future;
  @override
  Future<int> requestMove() => hintCompleter.future;
  @override
  Future<int> requestAndMakeMove() => resumeMoveCompleter.future;
  @override
  Future<void> restore(Iterable<int> moves) async {
    restoredMoves
      ..clear()
      ..addAll(moves);
  }

  @override
  Future<void> requestUndo(int mv, int pc) async {}
  @override
  Future<void> dispose() async => disposed = true;
}
