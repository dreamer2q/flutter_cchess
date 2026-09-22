import 'dart:async';

import 'package:flutter_cchess/bloc/timer_bloc.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_test/flutter_test.dart';

class _ManualTicker extends Ticker {
  _ManualTicker();

  final List<StreamController<int>> controllers = [];

  @override
  Stream<int> tick({required int ticks}) {
    final controller = StreamController<int>();
    controllers.add(controller);
    return controller.stream;
  }

  Future<void> dispose() async {
    for (final controller in controllers) {
      await controller.close();
    }
  }
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

void main() {
  group('TimerBloc', () {
    late _ManualTicker ticker;
    late TimerBloc bloc;

    setUp(() {
      ticker = _ManualTicker();
      bloc = TimerBloc(ticker: ticker, initialDuration: 5);
    });

    tearDown(() async {
      await bloc.close();
      await ticker.dispose();
    });

    test('starts with the configured duration', () {
      expect(bloc.state, const TimerInitial(5));
      expect(bloc.state.status, TimerStatus.initial);
      expect(bloc.state.initialDuration, 5);
    });

    test('starts, ticks, and completes', () async {
      bloc.add(const TimerStarted(duration: 3));
      await _flushEvents();

      expect(bloc.state, const TimerRunInProgress(3));
      expect(ticker.controllers, hasLength(1));

      ticker.controllers.single.add(2);
      await _flushEvents();
      expect(
        bloc.state,
        const TimerRunInProgress(2, initialDuration: 3),
      );

      ticker.controllers.single.add(0);
      await _flushEvents();
      expect(bloc.state, const TimerRunComplete(initialDuration: 3));
      expect(bloc.state.isComplete, isTrue);
    });

    test('pauses and resumes without losing the remaining duration', () async {
      bloc.add(const TimerStarted(duration: 5));
      await _flushEvents();
      ticker.controllers.single.add(4);
      await _flushEvents();

      bloc.add(const TimerPaused());
      await _flushEvents();
      expect(
        bloc.state,
        const TimerRunPause(4, initialDuration: 5),
      );
      expect(bloc.state.isPaused, isTrue);

      bloc.add(const TimerResumed());
      await _flushEvents();
      expect(
        bloc.state,
        const TimerRunInProgress(4, initialDuration: 5),
      );

      ticker.controllers.single.add(2);
      await _flushEvents();
      expect(
        bloc.state,
        const TimerRunInProgress(2, initialDuration: 5),
      );
    });

    test('resets to the configured duration after a custom run', () async {
      bloc.add(const TimerStarted(duration: 2));
      await _flushEvents();
      bloc.add(const TimerReset());
      await _flushEvents();

      expect(bloc.state, const TimerInitial(5));
    });

    test('completes immediately when started with zero duration', () async {
      bloc.add(const TimerStarted(duration: 0));
      await _flushEvents();

      expect(bloc.state, const TimerRunComplete());
      expect(ticker.controllers, isEmpty);
    });

    test('ignores ticks from an earlier run', () async {
      bloc.add(const TimerStarted(duration: 2));
      await _flushEvents();
      bloc.add(const TimerReset());
      await _flushEvents();

      bloc.add(const TimerTicked(duration: 0, runId: 2));
      await _flushEvents();

      expect(bloc.state, const TimerInitial(5));
    });
  });
}
