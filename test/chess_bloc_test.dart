import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/game.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/fen.dart';

void main() {
  test(
    'initializes local two-player mode and persists a game snapshot',
    () async {
      final repository = InMemoryGameRepository();
      final bloc = _bloc(repository: repository);

      await _initialize(bloc, PlayMode.withSelf);
      expect(bloc.state.playMode, PlayMode.withSelf);

      await Future<void>.delayed(Duration.zero);
      final record = await repository.getCurrent();
      expect(record, isNotNull);
      expect(record!.mode, GamePlayMode.self);
      expect(record.moves, isEmpty);

      await bloc.close();
    },
  );

  test('pauses an idle game, clears selection, and resumes it', () async {
    final bloc = _bloc();
    await _initialize(bloc, PlayMode.withSelf);
    final selectable = bloc.state.board.pcPairs.firstWhere(
      (pair) => bloc.state.board.isSelectable(pair.piece),
    );

    bloc.add(ChessEventBoardTap(selectable.pos));
    await _waitFor(bloc, (state) => state.selected != null);
    bloc.add(const ChessEventPause());
    await _waitFor(bloc, (state) => state.status == BoardStatus.paused);
    expect(bloc.state.selected, isNull);

    bloc.add(const ChessEventResume());
    await _waitFor(bloc, (state) => state.status == BoardStatus.idle);
    await bloc.close();
  });

  test('restores AI engine history before accepting input', () async {
    final engine = ControlledChessEngine();
    final initialBoard = FenUtil.parse(initialFenString);
    final firstMove = initialBoard.getMoves().first;
    final restoredBoard = initialBoard.copyWith(
      actions: initialBoard.actions.rebuild(
        (actions) => actions..add(BoardMoveAction(firstMove.mv)),
      ),
    );
    final bloc = _bloc(engine: engine);

    bloc.add(
      ChessEventInitialized(
        initialBoard: restoredBoard,
        playMode: PlayMode.withAI,
      ),
    );
    await _waitFor(bloc, (state) => state.status == BoardStatus.idle);

    expect(engine.restoredMoves, [firstMove.mv]);
    expect(bloc.state.board.lastMoves, [firstMove]);
    await bloc.close();
  });

  test(
    'hint locks the board, returns a marker, and selection clears it',
    () async {
      final engine = ControlledChessEngine();
      final bloc = _bloc(engine: engine);
      await _initialize(bloc, PlayMode.withAI);
      final hint = bloc.state.board.getMoves().first;

      bloc.add(const ChessEventGetHint());
      await _waitFor(bloc, (state) => state.status == BoardStatus.thinking);
      expect(bloc.state.board.lastMoves, isEmpty);

      engine.hintCompleter.complete(hint.mv);
      await _waitFor(
        bloc,
        (state) =>
            state.status == BoardStatus.idle && state.hintMoves?.single == hint,
      );
      expect(bloc.state.board.lastMoves, isEmpty);

      bloc.add(ChessEventBoardTap(hint.srcPos));
      await _waitFor(
        bloc,
        (state) => state.selected != null && state.hintMoves == null,
      );
      await bloc.close();
    },
  );

  test('pausing AI thinking caches its move until resume', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final playerMove = bloc.state.board.getMoves().first;

    await _completeMove(bloc, playerMove, BoardStatus.thinking);
    final aiMove = bloc.state.board.getMoves().first;
    bloc.add(const ChessEventPause());
    await _waitFor(bloc, (state) => state.status == BoardStatus.paused);

    engine.aiMoveCompleter.complete(aiMove.mv);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, BoardStatus.paused);
    expect(bloc.state.animeMove, isNull);

    bloc.add(const ChessEventResume());
    await _waitFor(
      bloc,
      (state) => state.status == BoardStatus.busy && state.animeMove == aiMove,
    );
    await bloc.close();
  });

  test(
    'duplicate move-end events do not turn AI thinking back to idle',
    () async {
      final engine = ControlledChessEngine();
      final bloc = _bloc(engine: engine);
      await _initialize(bloc, PlayMode.withAI);
      final playerMove = bloc.state.board.getMoves().first;

      await _completeMove(bloc, playerMove, BoardStatus.thinking);
      bloc.add(const ChessEventMoveEnd());
      bloc.add(ChessEventMoveEnd(playerMove));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.status, BoardStatus.thinking);
      expect(bloc.state.board.lastMoves, [playerMove]);

      final aiMove = bloc.state.board.getMoves().first;
      engine.aiMoveCompleter.complete(aiMove.mv);
      await _waitFor(bloc, (state) => state.animeMove == aiMove);
      await bloc.close();
    },
  );

  test(
    'move completion timeout commits once when animation callback is lost',
    () async {
      final bloc = _bloc(
        animationCompletionTimeout: const Duration(milliseconds: 10),
      );
      await _initialize(bloc, PlayMode.withSelf);
      final move = bloc.state.board.getMoves().first;

      bloc.add(ChessEventMoveBegin(move));
      await _waitFor(bloc, (state) => state.status == BoardStatus.busy);
      await _waitFor(
        bloc,
        (state) =>
            state.status == BoardStatus.idle &&
            state.board.lastMoves.length == 1,
      );
      expect(bloc.state.lastMove, move);

      bloc.add(ChessEventMoveEnd(move));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.board.lastMoves, [move]);
      await bloc.close();
    },
  );

  test('a stale move-end callback cannot complete the active move', () async {
    final bloc = _bloc();
    await _initialize(bloc, PlayMode.withSelf);
    final move = bloc.state.board.getMoves().first;
    final staleMove = bloc.state.board.getMoves().last;

    bloc.add(ChessEventMoveBegin(move));
    await _waitFor(bloc, (state) => state.status == BoardStatus.busy);
    bloc.add(ChessEventMoveEnd(staleMove));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.status, BoardStatus.busy);
    expect(bloc.state.board.lastMoves, isEmpty);

    bloc.add(ChessEventMoveEnd(move));
    await _waitFor(bloc, (state) => state.status == BoardStatus.idle);
    expect(bloc.state.board.lastMoves, [move]);
    await bloc.close();
  });

  test(
    'undo restores the previous last move and eventually clears it',
    () async {
      final bloc = _bloc();
      await _initialize(bloc, PlayMode.withSelf);
      final redMove = bloc.state.board.getMoves().first;
      await _completeMove(bloc, redMove, BoardStatus.idle);
      final blackMove = bloc.state.board.getMoves().first;
      await _completeMove(bloc, blackMove, BoardStatus.idle);

      bloc.add(const ChessEventUndo());
      await _waitFor(
        bloc,
        (state) =>
            state.board.lastMoves.length == 1 && state.lastMove == redMove,
      );

      bloc.add(const ChessEventUndo());
      await _waitFor(bloc, (state) => state.board.lastMoves.isEmpty);
      expect(bloc.state.lastMove, isNull);
      await bloc.close();
    },
  );

  test(
    'local resignation awards the win to the opponent of the active side',
    () async {
      final repository = InMemoryGameRepository();
      final bloc = _bloc(repository: repository);
      await _initialize(bloc, PlayMode.withSelf);
      final redMove = bloc.state.board.getMoves().first;
      await _completeMove(bloc, redMove, BoardStatus.idle);
      expect(bloc.state.board.innerBoard.sdPlayer, PlaySide.black.index);

      bloc.add(const ChessEventResign());
      await _waitFor(bloc, (state) => state.status == BoardStatus.finished);
      expect(bloc.state.winningSide, PlaySide.red);
      expect(bloc.state.playStatus, PlayStatus.lose);

      await Future<void>.delayed(Duration.zero);
      expect((await repository.getCurrent())!.result, GameResult.redWin);
      await bloc.close();
    },
  );

  test('resigning during AI thinking ignores the later AI result', () async {
    final engine = ControlledChessEngine();
    final bloc = _bloc(engine: engine);
    await _initialize(bloc, PlayMode.withAI);
    final playerMove = bloc.state.board.getMoves().first;
    await _completeMove(bloc, playerMove, BoardStatus.thinking);
    final movesBeforeResign = bloc.state.board.lastMoves.toList();

    bloc.add(const ChessEventResign());
    await _waitFor(bloc, (state) => state.status == BoardStatus.finished);
    engine.aiMoveCompleter.complete(bloc.state.board.getMoves().first.mv);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(bloc.state.status, BoardStatus.finished);
    expect(bloc.state.board.lastMoves, movesBeforeResign);
    expect(bloc.state.winningSide, PlaySide.black);
    await bloc.close();
  });
}

ChessBloc _bloc({
  GameRepository? repository,
  ChessEnginePort? engine,
  Duration animationCompletionTimeout = ChessBloc.moveCompletionTimeout,
}) {
  return ChessBloc(
    ticker: Ticker(),
    repository: repository,
    engine: engine,
    animationCompletionTimeout: animationCompletionTimeout,
  );
}

Future<void> _initialize(ChessBloc bloc, PlayMode mode) async {
  bloc.add(
    ChessEventInitialized(
      initialBoard: FenUtil.parse(initialFenString),
      playMode: mode,
    ),
  );
  await _waitFor(bloc, (state) => state.status == BoardStatus.idle);
}

Future<void> _completeMove(
  ChessBloc bloc,
  MovePos move,
  BoardStatus expectedStatus,
) async {
  bloc.add(ChessEventMoveBegin(move));
  await _waitFor(
    bloc,
    (state) => state.status == BoardStatus.busy && state.animeMove == move,
  );
  bloc.add(ChessEventMoveEnd(move));
  await _waitFor(bloc, (state) => state.status == expectedStatus);
}

Future<ChessState> _waitFor(
  ChessBloc bloc,
  bool Function(ChessState state) predicate,
) async {
  if (predicate(bloc.state)) return bloc.state;
  return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 2));
}

class ControlledChessEngine implements ChessEnginePort {
  final Completer<int> aiMoveCompleter = Completer<int>();
  final Completer<int> hintCompleter = Completer<int>();
  final List<List<int>> undoRequests = <List<int>>[];
  final List<int> restoredMoves = <int>[];

  @override
  Future<int> makeMove(int mv) => aiMoveCompleter.future;

  @override
  Future<int> requestMove() => hintCompleter.future;

  @override
  Future<void> restore(Iterable<int> moves) async {
    restoredMoves
      ..clear()
      ..addAll(moves);
  }

  @override
  Future<void> requestUndo(int mv, int pc) async {
    undoRequests.add([mv, pc]);
  }
}
