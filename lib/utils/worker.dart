import 'dart:async';
import 'dart:isolate';

// main(List<String> args) async {
//   var worker = Worker();
//   worker.reuqest('发送消息1').then((data) {
//     print('子线程处理后的消息:$data');
//   });

//   Future.delayed(Duration(seconds: 2), () {
//     worker.reuqest('发送消息2').then((data) {
//       print('子线程处理后的消息:$data');
//     });
//   });
// }

typedef WorkerHandler = FutureOr Function(dynamic);

class Worker {
  late SendPort _sendPort;
  late Isolate _isolate;
  final _isolateReady = Completer<void>();
  final Map<Capability, Completer> _completers = {};
  final WorkerHandler handler;

  Worker({
    required this.handler,
  }) {
    _init();
  }

  Future<void> _init() async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    errorPort.listen(print);
    receivePort.listen(_handleMessage);
    _isolate = await Isolate.spawn(
      _isolateEntry,
      receivePort.sendPort,
      onError: errorPort.sendPort,
    );
  }

  void dispose() {
    _isolate.kill();
  }

  Future reuqest(dynamic message) async {
    await _isolateReady.future;
    final completer = Completer();
    final requestId = Capability();
    _completers[requestId] = completer;
    _sendPort.send(_Request(requestId, message));
    return completer.future;
  }

  void _handleMessage(message) {
    if (message is SendPort) {
      _sendPort = message;
      _sendPort.send(handler);
      _isolateReady.complete();
      return;
    }

    if (message is _Response) {
      final completer = _completers[message.requestId];
      if (completer == null) {
        print("Invalid request ID received.");
      } else if (message.success) {
        completer.complete(message.message);
      } else {
        completer.completeError(message.message);
      }
      return;
    }
    throw UnimplementedError("Undefined behavior for message: $message");
  }

  static void _isolateEntry(dynamic message) {
    final receivePort = ReceivePort();
    late SendPort sendPort;
    late WorkerHandler handler;

    receivePort.listen((dynamic message) async {
      if (message is _Request) {
        print('子线程收到：${message.message}');
        try {
          final response = await handler.call(message);
          sendPort.send(_Response.ok(message.requestId, response));
        } catch (e) {
          sendPort.send(_Response.error(message.requestId, e));
        }
        return;
      }
    });

    if (message is SendPort) {
      sendPort = message;
      sendPort.send(receivePort.sendPort);
      return;
    }
    if (message is WorkerHandler) {
      handler = message;
      return;
    }
  }
}

class _Request {
  /// The ID of the request so the response may be associated to the request's future completer.
  final Capability requestId;

  /// The actual message of the request.
  final dynamic message;

  const _Request(this.requestId, this.message);
}

class _Response {
  /// The ID of the request this response is meant to.
  final Capability requestId;

  /// Indicates if the request succeeded.
  final bool success;

  /// If [success] is true, holds the response message.
  /// Otherwise, holds the error that occured.
  final dynamic message;

  const _Response.ok(this.requestId, this.message) : success = true;

  const _Response.error(this.requestId, this.message) : success = false;
}
