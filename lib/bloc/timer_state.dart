part of 'timer_bloc.dart';

@immutable
abstract class TimerState extends Equatable {
  const TimerState(this.duration, {int? initialDuration})
      : initialDuration = initialDuration ?? duration;

  final int duration;
  final int initialDuration;

  TimerStatus get status;

  bool get isRunning => status == TimerStatus.running;

  bool get isPaused => status == TimerStatus.paused;

  bool get isComplete => status == TimerStatus.complete;

  @override
  List<Object?> get props => [duration, initialDuration];
}

class TimerInitial extends TimerState {
  const TimerInitial(int duration, {int? initialDuration})
      : super(duration, initialDuration: initialDuration);

  @override
  TimerStatus get status => TimerStatus.initial;

  @override
  String toString() => 'TimerInitial(duration: $duration)';
}

class TimerRunPause extends TimerState {
  const TimerRunPause(int duration, {int? initialDuration})
      : super(duration, initialDuration: initialDuration);

  @override
  TimerStatus get status => TimerStatus.paused;

  @override
  String toString() => 'TimerRunPause(duration: $duration)';
}

class TimerRunInProgress extends TimerState {
  const TimerRunInProgress(int duration, {int? initialDuration})
      : super(duration, initialDuration: initialDuration);

  @override
  TimerStatus get status => TimerStatus.running;

  @override
  String toString() => 'TimerRunInProgress(duration: $duration)';
}

class TimerRunComplete extends TimerState {
  const TimerRunComplete({int initialDuration = 0})
      : super(0, initialDuration: initialDuration);

  @override
  TimerStatus get status => TimerStatus.complete;

  @override
  String toString() => 'TimerRunComplete(initialDuration: $initialDuration)';
}

enum TimerStatus {
  initial,
  running,
  paused,
  complete,
}
