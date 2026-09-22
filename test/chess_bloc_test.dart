import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/fen.dart';

void main() {
  test('initializes local two-player mode and persists a game snapshot',
      () async {
    final repository = InMemoryGameRepository();
    final bloc = ChessBloc(ticker: Ticker(), repository: repository);

    bloc.add(ChessEventInitialized(
      initialBoard: FenUtil.parse(initialFenString),
      playMode: PlayMode.withSelf,
    ));

    final state = await bloc.stream.firstWhere(
      (value) => value.status == BoardStatus.idle,
    );
    expect(state.playMode, PlayMode.withSelf);

    await Future<void>.delayed(Duration.zero);
    final record = await repository.getCurrent();
    expect(record, isNotNull);
    expect(record!.mode, GamePlayMode.self);
    expect(record.moves, isEmpty);

    await bloc.close();
  });
}
