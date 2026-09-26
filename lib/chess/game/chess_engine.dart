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

  Future<int> makeMove(int mv);

  Future<int> requestMove();

  Future<EnginePositionEvaluation> evaluatePosition({
    required List<int> squares,
    required int sideToMove,
    required int maxDepth,
    required int maxThinkMs,
  });

  /// Searches the current position and commits the returned move in the
  /// engine. Used when restoring a game that stopped on the computer turn.
  Future<int> requestAndMakeMove();

  Future<void> requestUndo(int mv, int pc);

  Future<void> dispose();
}

class ChessEngine implements ChessEnginePort {
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
          search.searchMain(maxDepth: maxDepth, maxThinkMs: maxThinkMs);
          search.pos.makeMove(search.mvResult);
          return search.mvResult;
        case 'board.makeMove':
          final int mv = params;
          if (!search.pos.legalMove(mv)) {
            throw Exception('illegal move: $mv');
          }
          if (!search.pos.makeMove(mv)) {
            throw Exception('king is checked');
          }
          search.searchMain(maxDepth: maxDepth, maxThinkMs: maxThinkMs);
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
  Future<int> makeMove(int mv) async {
    return await invokeMethod('board.makeMove', mv);
  }

  @override
  Future<void> restore(Iterable<int> moves) async {
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
  Future<int> requestAndMakeMove() async {
    return await invokeMethod('board.requestAndMakeMove', null);
  }

  @override
  Future<void> requestUndo(int mv, int pc) async {
    await invokeMethod('board.undoMove', [mv, pc]);
  }
}
