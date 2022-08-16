import 'dart:async';
import 'dart:isolate';

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

class ChessEngine {
  static void _engineHandler(SendPort sendPort) {
    final XqwlSearch search = XqwlSearch();
    final ReceivePort recvPort = ReceivePort();

    recvPort.listen((message) {
      if (message is _RequestEvent) {
        final _RequestEvent e = message;
        switch (e.type) {
          case _RequestType.requestMove:
            search.searchMain();
            e.completer.complete(search.mvResult);
            break;
          case _RequestType.makeMove:
            final int mv = e.argument;
            if (!search.pos.legalMove(mv)) {
              return e.completer.completeError(
                Exception('illegal move: $mv'),
              );
            }
            if (!search.pos.makeMove(mv)) {
              return e.completer.completeError(
                Exception('king is checked'),
              );
            }
            search.searchMain();
            final srcSq = GameBoard.getSrc(search.mvResult);
            final dstSq = GameBoard.getDst(search.mvResult);
            final move = PieceMove(
              BoardUtil.makePiece(srcSq, search.pos.ucpcSquares[srcSq]),
              BoardUtil.makePosition(dstSq),
            );
            e.completer.complete(move);
            break;
          case _RequestType.resetBoard:
            search.pos.startup();
            e.completer.complete(true);
            break;
          case _RequestType.undoMove:
            e.completer.completeError(UnimplementedError());
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
  late Isolate _isolate;
  late SendPort _sendPort;
  bool _initialized = false;

  void _onMessage(message) {
    if (message is Completer) {
      ///
    } else if (message is SendPort) {
      _sendPort = message;
      _initialized = true;
    }
  }

  void dispose() {
    _isolate.kill();
  }

  Future<PieceMove> resultForMove(PieceMove move) {
    final completer = Completer<PieceMove>();
    final mv = BoardUtil.calcMove(move.src, move.dst);
    _sendPort.send(_RequestEvent(_RequestType.makeMove, mv, completer));
    return completer.future;
  }
}
