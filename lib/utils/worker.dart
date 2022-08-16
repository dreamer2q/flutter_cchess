import 'dart:async';
import 'dart:isolate';

abstract class Worker {
  static void _isolateEntry(SendPort sendPort) {
    final recvPort = ReceivePort();

    recvPort.listen((message) {});

    sendPort.send(recvPort.sendPort);
  }

  Worker() {
    Isolate.spawn(
      _isolateEntry,
      _recvPort.sendPort,
      debugName: workName,
    ).then((isolate) {
      _isolate = isolate;
      _readyCompleter.complete();
    });
  }
  late final Isolate _isolate;
  final Completer<void> _readyCompleter = Completer();
  final ReceivePort _recvPort = ReceivePort();

  String get workName => '$runtimeType-$hashCode';
}
