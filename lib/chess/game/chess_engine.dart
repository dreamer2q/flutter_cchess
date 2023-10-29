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

    recvPort.listen((message) {
      if (message is _Request) {
        final _Request e = message;
        switch (e.method) {
          case 'board.requestMove':
            search.searchMain();
            sendPort.send(e.makeResult(search.mvResult));
            break;
          case 'board.makeMove':
            final int mv = e.params;
            if (!search.pos.legalMove(mv)) {
              sendPort.send(e.makeError(Exception('illegal move: $mv')));
              break;
            }
            if (!search.pos.makeMove(mv)) {
              sendPort.send(e.makeError(Exception('king is checked')));
              break;
            }
            search.searchMain();
            search.pos.makeMove(search.mvResult);
            sendPort.send(e.makeResult(search.mvResult));
            break;
          case 'board.reset':
            search.pos.startup();
            sendPort.send(e.makeResult(true));
            break;
          case 'board.undoMove':
            sendPort.send(e.makeError(UnimplementedError()));
            break;
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

  Future<int> resultForMove(PieceMove move) async {
    final mv = BoardUtil.calcMove(move.src, move.dst);
    final res = await invokeMethod('board.makeMove', mv);
    // PieceMove(piece, dst)
    return res as int;
  }
}
