import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';

import 'ai_strength.dart';

class _Request<T> {
  static int incrementalId = 1;

  final int id;
  final String method; // board.move
  final T params;

  _Request(this.id, this.method, this.params);

  _Request.method(this.method, this.params) : id = _Request.incrementalId++;

  _Response makeResult(dynamic result) {
    return _Response(id, result, null);
  }

  _Response makeError(dynamic error) {
    return _Response(id, null, error);
  }
}

class _Response {
  final int id;
  final dynamic result;
  final dynamic error;

  _Response(this.id, this.result, this.error);
}

class _PendingResponse<T> {
  final _Request request;

  final Completer<T> completer = Completer<T>();

  _PendingResponse(this.request);

  Future<T> get future => completer.future;
}

class EnginePositionEvaluation {
  const EnginePositionEvaluation({required this.score, required this.depth});

  final int score;
  final int depth;
}

abstract class ChessEnginePort {
  Future<void> setOpeningBook(Iterable<List<int>> lines);

  Future<void> setStrength(
    AiStrength strength, {
    int? maxDepth,
    int? maxThinkMs,
  });

  Future<void> restore(Iterable<int> moves);

  Future<int> makeMove(int mv, {int? maxThinkMs});

  Future<int> requestMove();

  Future<EnginePositionEvaluation> evaluatePosition({
    required List<int> squares,
    required int sideToMove,
    required int maxDepth,
    required int maxThinkMs,
  });

  /// Searches the current position and commits the returned move in the
  /// engine. Used when restoring a game that stopped on the computer turn.
  Future<int> requestAndMakeMove({int? maxThinkMs});

  void startPonder({
    required List<int> squares,
    required int sideToMove,
    required int maxDepth,
    required int maxThinkMs,
  }) {}

  void stopPonder() {}

  Future<void> requestUndo(int mv, int pc);

  Future<void> dispose();
}

class ChessEngine implements ChessEnginePort {
  static void _ponderHandler(_PonderRequest request) {
    final search = XqwlSearch();
    final candidates = <(int, int)>[];
    void loadPosition() {
      search.pos.clearBoard();
      for (var square = 0; square < request.squares.length; square++) {
        final piece = request.squares[square];
        if (piece != 0) search.pos.addPiece(square, piece);
      }
      if (request.sideToMove == 1) search.pos.changeSide();
      search.pos.setIrrev();
    }

    loadPosition();
    final moves = <int>[];
    search.pos.generateMoves(moves);
    for (final move in moves) {
      if (!search.pos.makeMove(move)) continue;
      final score = -search.pos.evaluate();
      search.pos.undoMakeMove();
      candidates.add((move, score));
    }
    candidates.sort((a, b) => b.$2.compareTo(a.$2));

    // Cover likely replies first, then deepen the best few while the human
    // clock runs. Only completed iterations are published to the game isolate.
    for (var index = 0; index < candidates.length; index++) {
      final humanMove = candidates[index].$1;
      loadPosition();
      if (!search.pos.makeMove(humanMove)) continue;
      search.searchMain(
        maxDepth: request.maxDepth,
        maxThinkMs: index < 8 ? 120 : 40,
        useOpeningBook: false,
        onCompletedDepth: (reply, depth) {
          if (reply != 0) {
            request.sendPort.send(
              _PonderProgress(request.generation, humanMove, reply, depth),
            );
          }
        },
      );
    }
    for (final candidate in candidates.take(5)) {
      loadPosition();
      if (!search.pos.makeMove(candidate.$1)) continue;
      search.searchMain(
        maxDepth: request.maxDepth,
        maxThinkMs: request.maxThinkMs,
        useOpeningBook: false,
        onCompletedDepth: (reply, depth) {
          if (reply != 0) {
            request.sendPort.send(
              _PonderProgress(request.generation, candidate.$1, reply, depth),
            );
          }
        },
      );
    }
  }

  static void _engineHandler(SendPort sendPort) {
    final XqwlSearch search = XqwlSearch();
    final ReceivePort recvPort = ReceivePort();
    var strength = AiStrength.normal;
    var maxDepth = strength.maxDepth;
    var maxThinkMs = strength.maxThinkMs;

    dynamic methodHandler(String method, dynamic params) {
      switch (method) {
        case 'board.setStrength':
          final settings = Map<String, Object?>.from(params as Map);
          strength = AiStrength.fromName(settings['strength'] as String?);
          maxDepth = AiStrength.clampDepth(
            settings['maxDepth'] as int? ?? strength.maxDepth,
          );
          maxThinkMs = AiStrength.clampThinkMs(
            settings['maxThinkMs'] as int? ?? strength.maxThinkMs,
          );
          break;
        case 'board.setOpeningBook':
          final lines = (params as Iterable).map(
            (line) => List<int>.from(line as Iterable),
          );
          search.loadBook(lines);
          break;
        case 'board.requestMove':
          search.searchMain(maxDepth: maxDepth, maxThinkMs: maxThinkMs);
          return search.mvResult;
        case 'board.evaluatePosition':
          final position = Map<String, Object?>.from(params as Map);
          final squares = List<int>.from(position['squares'] as Iterable);
          search.pos.clearBoard();
          for (var square = 0; square < squares.length; square++) {
            final piece = squares[square];
            if (piece != 0) search.pos.addPiece(square, piece);
          }
          if (position['sideToMove'] == 1) search.pos.changeSide();
          search.pos.setIrrev();
          final score = search.evaluatePosition(
            maxDepth: AiStrength.clampDepth(position['maxDepth'] as int),
            maxThinkMs: AiStrength.clampThinkMs(position['maxThinkMs'] as int),
          );
          return {'score': score, 'depth': search.completedDepth};
        case 'board.requestAndMakeMove':
          search.searchMain(
            maxDepth: maxDepth,
            maxThinkMs: (params as int?) ?? maxThinkMs,
          );
          search.pos.makeMove(search.mvResult);
          return search.mvResult;
        case 'board.makeMove':
          final values = Map<String, int>.from(params as Map);
          final mv = values['move']!;
          if (!search.pos.legalMove(mv)) {
            throw Exception('illegal move: $mv');
          }
          if (!search.pos.makeMove(mv)) {
            throw Exception('king is checked');
          }
          final cachedMove = values['cachedMove'] ?? 0;
          final cachedDepth = values['cachedDepth'] ?? 0;
          final reusableDepth = maxDepth > 0
              ? maxDepth
              : switch (strength) {
                  AiStrength.easy => 4,
                  AiStrength.normal => 6,
                  AiStrength.hard => 7,
                };
          if (cachedDepth >= reusableDepth &&
              cachedMove != 0 &&
              search.pos.legalMove(cachedMove) &&
              search.pos.makeMove(cachedMove)) {
            return cachedMove;
          }
          search.searchMain(
            maxDepth: maxDepth,
            maxThinkMs: values['maxThinkMs'] ?? maxThinkMs,
            preferredMove: cachedMove,
          );
          search.pos.makeMove(search.mvResult);
          return search.mvResult;
        case 'board.reset':
          search.pos.startup();
          break;
        case 'board.restore':
          search.pos.startup();
          for (final mv in List<int>.from(params as Iterable)) {
            if (!search.pos.legalMove(mv) || !search.pos.makeMove(mv)) {
              throw Exception('cannot restore illegal move: $mv');
            }
          }
          break;
        case 'board.undoMove':
          search.pos.undoMakeMove();
          break;
        default:
          throw Exception('unsupported method: $method');
      }
      return null;
    }

    recvPort.listen((message) {
      if (message is _Request) {
        final _Request e = message;
        try {
          final result = methodHandler(e.method, e.params);
          sendPort.send(e.makeResult(result));
        } catch (err) {
          sendPort.send(e.makeError(err));
        }
      }
    });

    // 建立通讯
    sendPort.send(recvPort.sendPort);
  }

  ChessEngine() {
    Isolate.spawn(
      _engineHandler,
      _recvPort.sendPort,
      debugName: '_engineIsolate',
    ).then((isolate) {
      if (_disposed) {
        isolate.kill();
      } else {
        _isolate = isolate;
      }
    });

    _recvPort.listen(_onMessage);
  }

  final ReceivePort _recvPort = ReceivePort();
  Isolate? _isolate;
  final Completer<SendPort> _readyPort = Completer<SendPort>();
  final Map<int, _PendingResponse> pendingResponseMap = {};
  bool _disposed = false;
  Isolate? _ponderIsolate;
  ReceivePort? _ponderPort;
  int _ponderGeneration = 0;
  final Map<int, _PonderProgress> _ponderCache = {};

  @visibleForTesting
  List<int> get ponderedHumanMoves => List<int>.unmodifiable(_ponderCache.keys);

  void _onMessage(message) {
    if (message is _Response) {
      final _PendingResponse? pending = pendingResponseMap[message.id];
      if (pending == null) {
        // warning
        debugPrint('pendingRequest ${message.id} is null');
        return;
      }

      if (message.error != null) {
        pending.completer.completeError(message.error);
      } else {
        pending.completer.complete(message.result);
      }
      pendingResponseMap.remove(message.id);
    } else if (message is SendPort) {
      if (!_readyPort.isCompleted) _readyPort.complete(message);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    stopPonder();
    _disposed = true;
    final isolate = _isolate;
    _recvPort.close();
    isolate?.kill();
    for (final pending in pendingResponseMap.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(StateError('Chess engine disposed'));
      }
    }
    pendingResponseMap.clear();
  }

  Future invokeMethod(String method, dynamic params) async {
    final sendPort = await _readyPort.future;
    final _Request request = _Request.method(method, params);
    final _PendingResponse pendingRes = _PendingResponse(request);
    pendingResponseMap[request.id] = pendingRes;
    sendPort.send(request);
    return await pendingRes.future;
  }

  @override
  Future<void> setOpeningBook(Iterable<List<int>> lines) async {
    await invokeMethod(
      'board.setOpeningBook',
      lines.map((line) => List<int>.from(line)).toList(growable: false),
    );
  }

  @override
  Future<void> setStrength(
    AiStrength strength, {
    int? maxDepth,
    int? maxThinkMs,
  }) async {
    await invokeMethod('board.setStrength', {
      'strength': strength.name,
      'maxDepth': maxDepth ?? strength.maxDepth,
      'maxThinkMs': maxThinkMs ?? strength.maxThinkMs,
    });
  }

  @override
  Future<int> makeMove(int mv, {int? maxThinkMs}) async {
    final cached = _ponderCache[mv];
    stopPonder();
    return await invokeMethod('board.makeMove', {
      'move': mv,
      if (maxThinkMs != null) 'maxThinkMs': maxThinkMs,
      'cachedMove': cached?.reply ?? 0,
      'cachedDepth': cached?.depth ?? 0,
    });
  }

  @override
  Future<void> restore(Iterable<int> moves) async {
    stopPonder();
    await invokeMethod('board.restore', moves.toList(growable: false));
  }

  @override
  Future<int> requestMove() async {
    return await invokeMethod('board.requestMove', null);
  }

  @override
  Future<EnginePositionEvaluation> evaluatePosition({
    required List<int> squares,
    required int sideToMove,
    required int maxDepth,
    required int maxThinkMs,
  }) async {
    final result = await invokeMethod('board.evaluatePosition', {
      'squares': squares,
      'sideToMove': sideToMove,
      'maxDepth': maxDepth,
      'maxThinkMs': maxThinkMs,
    });
    final values = Map<String, int>.from(result as Map);
    return EnginePositionEvaluation(
      score: values['score']!,
      depth: values['depth']!,
    );
  }

  @override
  Future<int> requestAndMakeMove({int? maxThinkMs}) async {
    stopPonder();
    return await invokeMethod('board.requestAndMakeMove', maxThinkMs);
  }

  @override
  void startPonder({
    required List<int> squares,
    required int sideToMove,
    required int maxDepth,
    required int maxThinkMs,
  }) {
    stopPonder();
    if (_disposed) return;
    final generation = _ponderGeneration;
    final port = ReceivePort();
    _ponderPort = port;
    port.listen((message) {
      if (message is! _PonderProgress ||
          message.generation != _ponderGeneration) {
        return;
      }
      final previous = _ponderCache[message.humanMove];
      if (previous == null || message.depth >= previous.depth) {
        _ponderCache[message.humanMove] = message;
      }
    });
    Isolate.spawn(
      _ponderHandler,
      _PonderRequest(
        port.sendPort,
        generation,
        List<int>.from(squares),
        sideToMove,
        maxDepth,
        maxThinkMs.clamp(100, 90000).toInt(),
      ),
      debugName: '_ponderIsolate',
    ).then(
      (isolate) {
        if (_disposed || generation != _ponderGeneration) {
          isolate.kill(priority: Isolate.immediate);
        } else {
          _ponderIsolate = isolate;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Ponder unavailable: $error');
      },
    );
  }

  @override
  void stopPonder() {
    _ponderGeneration++;
    _ponderIsolate?.kill(priority: Isolate.immediate);
    _ponderIsolate = null;
    _ponderPort?.close();
    _ponderPort = null;
    _ponderCache.clear();
  }

  @override
  Future<void> requestUndo(int mv, int pc) async {
    await invokeMethod('board.undoMove', [mv, pc]);
  }
}

class _PonderRequest {
  const _PonderRequest(
    this.sendPort,
    this.generation,
    this.squares,
    this.sideToMove,
    this.maxDepth,
    this.maxThinkMs,
  );
  final SendPort sendPort;
  final int generation;
  final List<int> squares;
  final int sideToMove;
  final int maxDepth;
  final int maxThinkMs;
}

class _PonderProgress {
  const _PonderProgress(
    this.generation,
    this.humanMove,
    this.reply,
    this.depth,
  );
  final int generation;
  final int humanMove;
  final int reply;
  final int depth;
}
