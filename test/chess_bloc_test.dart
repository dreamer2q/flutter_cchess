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

  test('analysis board replacement is ignored by a real local game', () async {
    final bloc = _bloc();
    await _initialize(bloc, PlayMode.withSelf);
    final initial = bloc.state.board;
    final proposed = _apply(initial, initial.getMoves().first);
    bloc.add(ChessEventAnalysisLoadBoard(proposed));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.board, initial);
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
        aiMaxDepth: 7,
        aiMaxThinkMs: 1900,
        openingBookLines: const [
          [1, 2],
          [3, 4],
        ],
      ),
    );
    await _waitFor(bloc, (s) => s.phase == GamePhase.playerTurn);
    expect(engine.strength, AiStrength.hard);
    expect(engine.maxDepth, 7);
    expect(engine.maxThinkMs, 1900);
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

  test('AI receives a clock-based budget when restored on its turn', () async {
    final initial = FenUtil.parse(initialFenString);
    final humanMove = initial.getMoves().first;
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    bloc.add(
      ChessEventInitialized(
        initialBoard: _apply(initial, humanMove),
        aiStrength: AiStrength.hard,
        blackElapsedMs: 870000,
        timeControlSeconds: 900,
      ),
    );
    await _waitFor(bloc, (state) => engine.requestedAutoThinkMs.isNotEmpty);
    expect(engine.requestedAutoThinkMs.single, 1000);
    await bloc.close();
  });

  test('pondering follows the human turn and stops while paused', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    expect(engine.ponderStarts, 1);

    bloc.add(const ChessEventPause());
    await _waitFor(bloc, (state) => state.phase == GamePhase.paused);
    expect(engine.ponderStops, 1);

    bloc.add(const ChessEventResume());
    await _waitFor(bloc, (state) => state.phase == GamePhase.playerTurn);
    expect(engine.ponderStarts, 2);
    await bloc.close();
  });

  test(
    'AI position score uses Red perspective and clears after a move',
    () async {
      final engine = ControlledChessEngine();
      final board = FenUtil.parse(initialFenString.replaceFirst(' w ', ' b '));
      final bloc = _bloc(analysisEngine: engine);
      bloc.add(
        ChessEventInitialized(
          initialBoard: board,
          playMode: PlayMode.withSelf,
          aiMaxDepth: 4,
          aiMaxThinkMs: 800,
        ),
      );
      await _waitFor(bloc, (state) => state.phase == GamePhase.playerTurn);

      bloc.add(const ChessEventEvaluatePosition());
      await _waitFor(bloc, (state) => state.isEvaluating);
      expect(engine.evaluationSideToMove, 1);
      expect(engine.evaluationMaxDepth, 4);
      expect(engine.evaluationMaxThinkMs, 800);
      engine.evaluationCompleter.complete(
        const EnginePositionEvaluation(score: 64, depth: 3),
      );
      await _waitFor(bloc, (state) => state.aiEvaluationForRed != null);

      expect(bloc.state.aiEvaluationForRed, -64);
      expect(bloc.state.aiEvaluationDepth, 3);

      final move = bloc.state.board.getMoves().first;
      bloc.add(ChessEventMoveRequested(move));
      await _waitFor(bloc, (state) => state.board.lastMoves.length == 1);
      expect(bloc.state.aiEvaluationForRed, isNull);
      expect(bloc.state.isEvaluating, isFalse);
      await bloc.close();
    },
  );

  test('AI-vs-AI alternates side strengths and blocks board input', () async {
    final engine = ControlledChessEngine()
      ..queueAiVsAiMove()
      ..queueAiVsAiMove();
    final repository = InMemoryGameRepository();
    final bloc = _bloc(engine: engine, repository: repository);
    final initial = FenUtil.parse(initialFenString);
    final redMove = initial.getMoves().first;

    bloc.add(
      ChessEventInitialized(
        initialBoard: initial,
        playMode: PlayMode.withAIvsAI,
        redAiStrength: AiStrength.easy,
        blackAiStrength: AiStrength.hard,
        redAiMaxDepth: 4,
        blackAiMaxDepth: 8,
        aiVsAiStepDelayMs: 50,
      ),
    );
    await _waitFor(bloc, (state) => engine.requestedAutoStrengths.length == 1);
    expect(engine.requestedAutoStrengths, [AiStrength.easy]);
    expect(engine.requestedAutoDepths, [4]);
    expect(engine.requestedAutoThinkMs, [2400]);
    expect(bloc.state.canInteractBoard, isFalse);

    bloc.add(ChessEventMoveRequested(redMove));
    bloc.add(ChessEventBoardTap(redMove.srcPos));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.board.lastMoves, isEmpty);

    engine.completeAiVsAiMove(redMove.mv);
    await _waitFor(bloc, (state) => state.board.lastMoves.length == 1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(engine.requestedAutoStrengths, [AiStrength.easy]);
    await _waitFor(bloc, (state) => engine.requestedAutoStrengths.length == 2);
    expect(engine.requestedAutoStrengths, [AiStrength.easy, AiStrength.hard]);
    expect(engine.requestedAutoDepths, [4, 8]);
    expect(bloc.state.phase, GamePhase.aiThinking);

    final blackMove = bloc.state.board.getMoves().first;
    engine.completeAiVsAiMove(blackMove.mv);
    await _waitFor(bloc, (state) => state.board.lastMoves.length == 2);
    await bloc.flushPersistence();
    final record = await repository.getCurrent();
    expect(record?.mode, GamePlayMode.aiVsAi);
    expect(record?.redAiStrength, AiStrength.easy);
    expect(record?.blackAiStrength, AiStrength.hard);
    expect(record?.redAiMaxDepth, 4);
    expect(record?.blackAiMaxDepth, 8);
    expect(record?.aiVsAiStepDelayMs, 50);
    await bloc.close();
  });

  test('AI-vs-AI animation delay does not consume the next clock', () async {
    Future<void> waitForRequests(ControlledChessEngine engine, int count) async {
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (engine.requestedAutoStrengths.length < count) {
        if (DateTime.now().isAfter(deadline)) {
          fail('AI request $count did not start');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    var now = 0;
    final ticker = _ManualTicker();
    final engine = ControlledChessEngine()
      ..queueAiVsAiMove()
      ..queueAiVsAiMove();
    final bloc = _bloc(engine: engine, ticker: ticker, clockNowMs: () => now);
    final initial = FenUtil.parse(initialFenString);
    bloc.add(
      ChessEventInitialized(
        initialBoard: initial,
        playMode: PlayMode.withAIvsAI,
        timeControlSeconds: 15,
        aiVsAiStepDelayMs: 200,
      ),
    );
    await waitForRequests(engine, 1);
    now = 1000;
    engine.completeAiVsAiMove(initial.getMoves().first.mv);
    await _waitFor(bloc, (state) => state.board.lastMoves.length == 1);
    expect(bloc.state.redElapsedMs, 1000);

    now = 5000;
    ticker.fire();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.blackElapsedMs, 0);
    await waitForRequests(engine, 2);

    now = 5600;
    ticker.fire();
    await _waitFor(bloc, (state) => state.blackElapsedMs == 600);
    await bloc.close();
    await ticker.dispose();
  });

  test(
    'AI-vs-AI result while paused waits for resume before next search',
    () async {
      final engine = ControlledChessEngine()
        ..queueAiVsAiMove()
        ..queueAiVsAiMove();
      final bloc = _bloc(engine: engine);
      final initial = FenUtil.parse(initialFenString);
      final redMove = initial.getMoves().first;
      bloc.add(
        ChessEventInitialized(
          initialBoard: initial,
          playMode: PlayMode.withAIvsAI,
        ),
      );
      await _waitFor(
        bloc,
        (state) => engine.requestedAutoStrengths.length == 1,
      );

      bloc.add(const ChessEventPause());
      await _waitFor(bloc, (state) => state.phase == GamePhase.paused);
      engine.completeAiVsAiMove(redMove.mv);
      await _waitFor(
        bloc,
        (state) =>
            state.phase == GamePhase.paused &&
            state.board.lastMoves.length == 1,
      );
      expect(engine.requestedAutoStrengths, [AiStrength.normal]);

      final blackMove = bloc.state.board.getMoves().first;
      bloc.add(const ChessEventResume());
      await _waitFor(
        bloc,
        (state) => engine.requestedAutoStrengths.length == 2,
      );
      engine.completeAiVsAiMove(blackMove.mv);
      await _waitFor(bloc, (state) => state.board.lastMoves.length == 2);
      await bloc.close();
    },
  );

  test(
    'discards an AI score if the position changes during analysis',
    () async {
      final engine = ControlledChessEngine();
      final bloc = _bloc(analysisEngine: engine);
      await _initialize(bloc, PlayMode.withSelf);

      bloc.add(const ChessEventEvaluatePosition());
      await _waitFor(bloc, (state) => state.isEvaluating);
      final move = bloc.state.board.getMoves().first;
      bloc.add(ChessEventMoveRequested(move));
      await _waitFor(bloc, (state) => state.board.lastMoves.length == 1);
      engine.evaluationCompleter.complete(
        const EnginePositionEvaluation(score: 75, depth: 2),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.aiEvaluationForRed, isNull);
      expect(bloc.state.isEvaluating, isFalse);
      await bloc.close();
    },
  );

  test('real engine completes two legal AI-vs-AI plies', () async {
    final bloc = _bloc();
    bloc.add(
      ChessEventInitialized(
        initialBoard: FenUtil.parse(initialFenString),
        playMode: PlayMode.withAIvsAI,
        timeControlSeconds: 0,
        redAiStrength: AiStrength.easy,
        blackAiStrength: AiStrength.easy,
      ),
    );
    final state = await bloc.stream
        .firstWhere((state) => state.board.lastMoves.length >= 2)
        .timeout(const Duration(seconds: 10));

    expect(state.board.lastMoves, hasLength(2));
    expect(state.board.isTurn(PlaySide.red), isTrue);
    expect(state.phase, GamePhase.aiThinking);
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
  ChessEnginePort? analysisEngine,
  Ticker ticker = const Ticker(),
  int Function()? clockNowMs,
}) => ChessBloc(
  ticker: ticker,
  repository: repository,
  engine: engine,
  analysisEngine: analysisEngine,
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
  final Completer<EnginePositionEvaluation> evaluationCompleter =
      Completer<EnginePositionEvaluation>();
  final List<int> restoredMoves = <int>[];
  int? evaluationSideToMove;
  int? evaluationMaxDepth;
  int? evaluationMaxThinkMs;
  final List<AiStrength> requestedAutoStrengths = <AiStrength>[];
  final List<int> requestedAutoDepths = <int>[];
  final List<int> requestedAutoThinkMs = <int>[];
  final List<int> requestedReplyThinkMs = <int>[];
  int ponderStarts = 0;
  int ponderStops = 0;
  final List<Completer<int>> _aiVsAiMoves = <Completer<int>>[];
  Completer<int>? _activeAiVsAiMove;
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
  Future<int> makeMove(int mv, {int? maxThinkMs}) {
    requestedReplyThinkMs.add(maxThinkMs ?? this.maxThinkMs);
    return makeMoveCompleter.future;
  }

  @override
  Future<int> requestMove() => hintCompleter.future;
  @override
  Future<EnginePositionEvaluation> evaluatePosition({
    required List<int> squares,
    required int sideToMove,
    required int maxDepth,
    required int maxThinkMs,
  }) {
    evaluationSideToMove = sideToMove;
    evaluationMaxDepth = maxDepth;
    evaluationMaxThinkMs = maxThinkMs;
    return evaluationCompleter.future;
  }

  @override
  Future<int> requestAndMakeMove({int? maxThinkMs}) {
    requestedAutoStrengths.add(strength);
    requestedAutoDepths.add(maxDepth);
    requestedAutoThinkMs.add(maxThinkMs ?? this.maxThinkMs);
    if (_aiVsAiMoves.isNotEmpty) {
      _activeAiVsAiMove = _aiVsAiMoves.removeAt(0);
      return _activeAiVsAiMove!.future;
    }
    return resumeMoveCompleter.future;
  }

  void queueAiVsAiMove() => _aiVsAiMoves.add(Completer<int>());

  @override
  void startPonder({
    required List<int> squares,
    required int sideToMove,
    required int maxDepth,
    required int maxThinkMs,
  }) {
    ponderStarts++;
  }

  @override
  void stopPonder() => ponderStops++;

  void completeAiVsAiMove(int move) {
    final completer = _activeAiVsAiMove;
    if (completer != null && !completer.isCompleted) {
      completer.complete(move);
      _activeAiVsAiMove = null;
      return;
    }
    fail('No queued AI-vs-AI search to complete.');
  }

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
