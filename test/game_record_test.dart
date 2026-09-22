import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1, 12);
  final updatedAt = DateTime.utc(2026, 1, 1, 12, 5);
  final record = GameRecord(
    id: 'game-1',
    initialFen: 'initial fen',
    moves: const [GameMove(from: 1, to: 2), GameMove(from: 3, to: 4)],
    mode: GamePlayMode.ai,
    result: GameResult.inProgress,
    createdAt: createdAt,
    updatedAt: updatedAt,
    redElapsedMs: 1200,
    blackElapsedMs: 800,
  );

  test('round trips a game record through JSON', () {
    expect(GameRecord.decode(record.encode()), equals(record));
  });

  test('rejects malformed game records', () {
    expect(
      () => GameRecord.fromJson(<String, dynamic>{'id': 'broken'}),
      throwsFormatException,
    );
  });

  test('in-memory repository saves, lists, and deletes records', () async {
    final repository = InMemoryGameRepository();
    await repository.save(record);
    expect(await repository.get(record.id), equals(record));
    expect(await repository.getCurrent(), equals(record));

    await repository.delete(record.id);
    expect(await repository.get(record.id), isNull);
    expect(await repository.getCurrent(), isNull);
  });

  test('shared preferences repository persists the current game', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesGameRepository(preferences);

    await repository.save(record);
    expect(await repository.getCurrent(), equals(record));
    expect((await repository.list()).single.moves, hasLength(2));

    await repository.clear();
    expect(await repository.getCurrent(), isNull);
  });
}
