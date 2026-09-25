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

  test(
    'clock switches sides, pauses, persists, and awards a timeout',
    () async {
      var now = 0;
      final ticker = _ManualTicker();
      final repository = InMemoryGameRepository();
      final bloc = _bloc(
        ticker: ticker,
        clockNowMs: () => now,
        repository: repository,
      );
      bloc.add(
        ChessEventInitialized(
          initialBoard: FenUtil.parse(initialFenString),
          playMode: PlayMode.withSelf,
          timeControlSeconds: 5,
        ),
      );
      await _waitFor(bloc, (s) => s.phase == GamePhase.playerTurn);
      expect(bloc.state.remainingSeconds(PlaySide.red), 5);

      now = 1200;
      ticker.fire();
      await _waitFor(bloc, (s) => s.redElapsedMs == 1200);
      expect(bloc.state.remainingSeconds(PlaySide.red), 4);

      now = 2300;
      bloc.add(ChessEventMoveRequested(bloc.state.board.getMoves().first));
      await _waitFor(bloc, (s) => s.board.lastMoves.length == 1);
      expect(bloc.state.redElapsedMs, 2300);
      now = 3500;
      bloc.add(const ChessEventPause());
      await _waitFor(bloc, (s) => s.phase == GamePhase.paused);
      expect(bloc.state.blackElapsedMs, 1200);
      now = 10000;
      ticker.fire();
      expect(bloc.state.blackElapsedMs, 1200);

      bloc.add(const ChessEventResume());
      await _waitFor(bloc, (s) => s.phase == GamePhase.playerTurn);
      now = 13800;
      ticker.fire();
      await _waitFor(bloc, (s) => s.phase == GamePhase.finished);
      expect(bloc.state.winningSide, PlaySide.red);
      await bloc.flushPersistence();
      final record = await repository.getCurrent();
      expect(record?.timeControlSeconds, 5);
      expect(record?.redElapsedMs, 2300);
      expect(record?.blackElapsedMs, 5000);
      expect(record?.result, GameResult.redWin);
      await bloc.close();
      await ticker.dispose();
    },
  );

  test('selected AI strength reaches the engine', () async {
    final engine = ControlledChessEngine();
    final repository = InMemoryGameRepository();
    final bloc = _bloc(engine: engine, repository: repository);
    bloc.add(
      ChessEventInitialized(
        initialBoard: FenUtil.parse(initialFenString),
        aiStrength: AiStrength.hard,
        aiMaxDepth: 11,
        aiMaxThinkMs: 2800,
        openingBookLines: const [
          [1, 2],
          [3, 4],
        ],
      ),
    );
    await _waitFor(bloc, (s) => s.phase == GamePhase.playerTurn);
    expect(engine.strength, AiStrength.hard);
    expect(engine.maxDepth, 11);
    expect(engine.maxThinkMs, 2800);
    expect(engine.openingBookLines, [
      [1, 2],
      [3, 4],
    ]);
    expect(bloc.state.aiStrength, AiStrength.hard);

    bloc.add(
      const ChessEventAiSettingsChanged(
        aiStrength: AiStrength.easy,
        aiMaxDepth: 2,
        aiMaxThinkMs: 450,
      ),
    );
    await _waitFor(bloc, (s) => s.aiMaxDepth == 2);
    await bloc.flushPersistence();
    expect(engine.maxThinkMs, 450);
    expect((await repository.getCurrent())?.aiMaxDepth, 2);
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

  test('AI turn and pending animations reject all board input', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final human = bloc.state.board.getMoves().first;
    bloc.add(ChessEventMoveRequested(human));
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);

    final ai = bloc.state.board.getMoves().first;
    bloc.add(ChessEventBoardTap(ai.srcPos));
    bloc.add(ChessEventMoveRequested(ai));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.board.lastMoves, [human]);
    expect(bloc.state.selected, isNull);
    expect(bloc.state.canInteractBoard, isFalse);

    engine.makeMoveCompleter.complete(ai.mv);
    await _waitFor(bloc, (s) => s.board.lastMoves.length == 2);
    final nextHuman = bloc.state.board.getMoves().first;
    bloc.add(ChessEventMoveRequested(nextHuman));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.board.lastMoves, [human, ai]);
    expect(bloc.state.canInteractBoard, isFalse);

    for (final effect in bloc.state.presentations.toList()) {
      bloc.add(ChessEventPresentationAcknowledged(effect.id));
      await _waitFor(bloc, (s) => s.activePresentation?.id != effect.id);
    }
    expect(bloc.state.canInteractBoard, isTrue);
    await bloc.close();
  });

  test('real engine returns a legal reply to the opening move', () async {
    final bloc = _bloc();
    await _initialize(bloc, PlayMode.withAI);
    final human = bloc.state.board.getMoves().first;
    bloc.add(ChessEventMoveRequested(human));
    final reply = await bloc.stream
        .firstWhere((state) => state.board.lastMoves.length == 2)
        .timeout(const Duration(seconds: 20));
    expect(reply.phase, GamePhase.playerTurn);
    expect(reply.board.lastMoves.first, human);
    expect(reply.board.isTurn(PlaySide.red), isTrue);
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

  test('retry restores the visible position before asking AI again', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final human = bloc.state.board.getMoves().first;
    bloc.add(ChessEventMoveRequested(human));
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);
    final legalAi = bloc.state.board.getMoves().first;
    engine.makeMoveCompleter.complete(human.mv);
    await _waitFor(bloc, (s) => s.phase == GamePhase.failure);

    bloc.add(const ChessEventRetryAi());
    await _waitFor(bloc, (s) => s.phase == GamePhase.aiThinking);
    await Future<void>.delayed(Duration.zero);
    expect(engine.restoredMoves, [human.mv]);
    engine.resumeMoveCompleter.complete(legalAi.mv);
    await _waitFor(bloc, (s) => s.board.lastMoves.length == 2);
    expect(bloc.state.board.lastMoves, [human, legalAi]);
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

ChessBloc _bloc({
  GameRepository? repository,
  ChessEnginePort? engine,
  Ticker ticker = const Ticker(),
  int Function()? clockNowMs,
}) => ChessBloc(
  ticker: ticker,
  repository: repository,
  engine: engine,
  clockNowMs: clockNowMs,
);

class _ManualTicker extends Ticker {
  final _controller = StreamController<int>();

  @override
  Stream<int> tick({required int ticks}) => _controller.stream;

  void fire() => _controller.add(0);

  Future<void> dispose() => _controller.close();
}

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
  AiStrength strength = AiStrength.normal;
  int maxDepth = AiStrength.normal.maxDepth;
  int maxThinkMs = AiStrength.normal.maxThinkMs;
  final Completer<int> makeMoveCompleter = Completer<int>();
  final Completer<int> hintCompleter = Completer<int>();
  final Completer<int> resumeMoveCompleter = Completer<int>();
  final List<int> restoredMoves = <int>[];
  bool disposed = false;
  List<List<int>> openingBookLines = const [];

  @override
  Future<void> setOpeningBook(Iterable<List<int>> lines) async {
    openingBookLines = lines.map(List<int>.from).toList(growable: false);
  }

  @override
  Future<void> setStrength(
    AiStrength value, {
    int? maxDepth,
    int? maxThinkMs,
  }) async {
    strength = value;
    this.maxDepth = maxDepth ?? value.maxDepth;
    this.maxThinkMs = maxThinkMs ?? value.maxThinkMs;
  }

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
