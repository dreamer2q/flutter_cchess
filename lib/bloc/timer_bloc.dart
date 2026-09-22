import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:meta/meta.dart';

part 'timer_event.dart';
part 'timer_state.dart';

class TimerBloc extends Bloc<TimerEvent, TimerState> {
  static const int defaultDuration = 60;

  final Ticker _ticker;
  final int _initialDuration;
  StreamSubscription<int>? _tickerSubscription;
  int _runId = 0;

  TimerBloc({required Ticker ticker, int initialDuration = defaultDuration})
      : assert(initialDuration >= 0),
        _ticker = ticker,
        _initialDuration = initialDuration,
        super(TimerInitial(initialDuration)) {
    on<TimerStarted>(_onStarted);
    on<TimerPaused>(_onPaused);
    on<TimerResumed>(_onResumed);
    on<TimerReset>(_onReset);
    on<TimerTicked>(_onTicked);
  }

  FutureOr<void> _onStarted(TimerStarted event, Emitter<TimerState> emit) {
    final duration = event.duration < 0 ? 0 : event.duration;
    _cancelTicker();
    final runId = ++_runId;

    if (duration == 0) {
      emit(TimerRunComplete(initialDuration: duration));
    } else {
      emit(TimerRunInProgress(duration, initialDuration: duration));
      _tickerSubscription =
          _ticker.tick(ticks: duration).listen((remaining) => add(TimerTicked(
                duration: remaining,
                runId: runId,
              )));
    }
  }

  @override
  Future<void> close() {
    _cancelTicker();
    return super.close();
  }

  FutureOr<void> _onTicked(TimerTicked event, Emitter<TimerState> emit) {
    if (event.runId == null || event.runId == _runId) {
      final duration = event.duration < 0 ? 0 : event.duration;
      emit(
        duration > 0
            ? TimerRunInProgress(
                duration,
                initialDuration: state.initialDuration,
              )
            : TimerRunComplete(initialDuration: state.initialDuration),
      );

      if (duration == 0) {
        _cancelTicker();
      }
    }
  }

  FutureOr<void> _onPaused(TimerPaused event, Emitter<TimerState> emit) {
    if (state.isRunning && _tickerSubscription != null) {
      _tickerSubscription?.pause();
      emit(TimerRunPause(
        state.duration,
        initialDuration: state.initialDuration,
      ));
    }
  }

  FutureOr<void> _onResumed(TimerResumed event, Emitter<TimerState> emit) {
    if (state.isPaused && _tickerSubscription != null) {
      _tickerSubscription?.resume();
      emit(TimerRunInProgress(
        state.duration,
        initialDuration: state.initialDuration,
      ));
    }
  }

  FutureOr<void> _onReset(TimerReset event, Emitter<TimerState> emit) {
    _cancelTicker();
    emit(TimerInitial(_initialDuration));
  }

  void _cancelTicker() {
    _runId++;
    _tickerSubscription?.cancel();
    _tickerSubscription = null;
  }
}
