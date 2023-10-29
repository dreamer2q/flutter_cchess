import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/utils/board.dart';

import 'game_board.dart';

enum _RequestType {
  resetBoard,
  requestMove,
  makeMove,
  undoMove,
}

class _RequestEvent {
  final _RequestType type;
  final dynamic argument;
  final Completer completer;

  _RequestEvent(this.type, this.argument, this.completer);
}

class _ResponseEvent {
  final _RequestEvent request;
  final dynamic result;

  _ResponseEvent(this.request, this.result);
}

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

class ChessEngine {
  static void _engineHandler(SendPort sendPort) {
    final XqwlSearch search = XqwlSearch();
    final ReceivePort recvPort = ReceivePort();

    dynamic methodHandler(String method, dynamic params) {
      switch (method) {
        case 'board.requestMove':
          search.searchMain();
          return search.mvResult;
        case 'board.makeMove':
          final int mv = params;
          if (!search.pos.legalMove(mv)) {
            throw Exception('illegal move: $mv');
          }
          if (!search.pos.makeMove(mv)) {
            throw Exception('king is checked');
          }
          search.searchMain();
          search.pos.makeMove(search.mvResult);
          return search.mvResult;
        case 'board.reset':
          search.pos.startup();
          break;
        case 'board.undoMove':
          int mv = params[0];
          int pc = params[1];
          search.pos.undoMakeMove(mv, pc);
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
      _isolate = isolate;
    });

    _recvPort.listen(_onMessage);
  }

  final ReceivePort _recvPort = ReceivePort();
  bool _initialized = false;
  late Isolate _isolate;
  late SendPort _sendPort;
  final Map<int, _PendingResponse> pendingResponseMap = {};

  void _onMessage(message) {
    if (message is _Response) {
      final _PendingResponse? pending = pendingResponseMap[message.id];
      if (pending == null) {
        // warning
        debugPrint('pendingRequest ${message.id} is null');
        return;
      }

      if (message.error != null) {
        pending.completer.completeError(
          message.error,
        );
      } else {
        pending.completer.complete(message.result);
      }
      pendingResponseMap.remove(message.id);
    } else if (message is SendPort) {
      _sendPort = message;
      _initialized = true;
    }
  }

  void dispose() {
    _isolate.kill();
  }

  Future invokeMethod(String method, dynamic params) {
    final _Request request = _Request.method(method, params);
    final _PendingResponse pendingRes = _PendingResponse(request);
    pendingResponseMap[request.id] = pendingRes;
    _sendPort.send(request);
    return pendingRes.future;
  }

  Future<int> makeMove(int mv) async {
    return await invokeMethod('board.makeMove', mv);
  }

  Future<int> requestMove() async {
    return await invokeMethod('board.requestMove', null);
  }

  Future requestUndo(int mv, int pc) async {
    return await invokeMethod('board.undoMove', [mv, pc]);
  }
}
