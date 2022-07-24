import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/bloc/timer_bloc.dart';
import 'package:flutter_cchess/timer/ticker.dart';

class TimerPage extends StatelessWidget {
  const TimerPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TimerBloc(ticker: Ticker()),
      child: const TimerView(),
    );
  }
}

class TimerView extends StatelessWidget {
  const TimerView({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter Timer"),
      ),
      body: Stack(
        children: [
          const Background(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 100,
                ),
                child: Center(
                  child: TimerText(),
                ),
              ),
              Actions(),
            ],
          ),
        ],
      ),
    );
  }
}

class TimerText extends StatelessWidget {
  const TimerText({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final duration = context.select((TimerBloc bloc) => bloc.state.duration);
    final min = ((duration / 60) % 60).floor().toString().padLeft(2, '0');
    final sec = (duration % 60).floor().toString().padLeft(2, '0');

    return Text(
      '$min:$sec',
      style: Theme.of(context).textTheme.headline1,
    );
  }
}

class Actions extends StatelessWidget {
  const Actions({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimerBloc, TimerState>(
      buildWhen: (prev, state) => prev.runtimeType != state.runtimeType,
      builder: (_, state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (state is TimerInitial) ...[
              FloatingActionButton(
                onPressed: () => context
                    .read<TimerBloc>()
                    .add(TimerStarted(duration: state.duration)),
                child: Icon(Icons.play_arrow),
              ),
            ],
            if (state is TimerRunInProgress) ...[
              FloatingActionButton(
                onPressed: () => context.read<TimerBloc>().add(TimerPaused()),
                child: Icon(Icons.pause),
              ),
              FloatingActionButton(
                onPressed: () => context.read<TimerBloc>().add(TimerReset()),
                child: Icon(Icons.replay),
              ),
            ],
            if (state is TimerRunPause) ...[
              FloatingActionButton(
                onPressed: () => context.read<TimerBloc>().add(TimerResumed()),
                child: Icon(Icons.play_arrow),
              ),
              FloatingActionButton(
                onPressed: () => context.read<TimerBloc>().add(TimerReset()),
                child: Icon(Icons.replay),
              )
            ],
            if (state is TimerRunComplete) ...[
              FloatingActionButton(
                onPressed: () => context.read<TimerBloc>().add(TimerReset()),
                child: Icon(Icons.replay),
              )
            ],
          ],
        );
      },
    );
  }
}

class Background extends StatelessWidget {
  const Background({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue.shade50,
          Colors.blue.shade500,
        ],
      )),
    );
  }
}
