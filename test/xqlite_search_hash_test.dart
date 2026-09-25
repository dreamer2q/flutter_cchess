import 'package:flutter_cchess/engine/xqlite/position.dart';
import 'package:flutter_cchess/engine/xqlite/search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transposition table respects depth and alpha-beta bounds', () {
    final search = XqwlSearch();
    final moves = <int>[];
    search.pos.generateMoves(moves);
    final move = moves.first;

    search.recordHash(XqwlPosition.HASH_BETA, 80, 4, move);

    expect(search.probeHash(0, 50, 4, [0]), 80);
    expect(search.probeHash(0, 100, 4, [0]), isNull);
    expect(search.probeHash(0, 50, 5, [0]), isNull);
    expect(search.probeHash(0, 50, 4, [0]), 80);
  });

  test('alpha bounds only cut off when the cached score is below alpha', () {
    final search = XqwlSearch();
    search.recordHash(XqwlPosition.HASH_ALPHA, -80, 4, 0);

    expect(search.probeHash(-50, 0, 4, [0]), -80);
    expect(search.probeHash(-100, -90, 4, [0]), isNull);
  });

  test('mate scores are normalized without mutating the cached entry', () {
    final search = XqwlSearch();
    search.pos.nDistance = 3;
    search.recordHash(XqwlPosition.HASH_PV, XqwlPosition.MATE_VALUE - 3, 4, 0);
    final entry =
        search.hashTable[search.pos.zobr.dwKey & (XqwlPosition.HASH_SIZE - 1)];

    search.pos.nDistance = 5;
    expect(
      search.probeHash(-XqwlPosition.MATE_VALUE, XqwlPosition.MATE_VALUE, 4, [
        0,
      ]),
      XqwlPosition.MATE_VALUE - 5,
    );
    expect(entry.svl, XqwlPosition.MATE_VALUE);
  });

  test(
    'a shallower collision does not replace a deeper entry for the same position',
    () {
      final search = XqwlSearch();
      search.recordHash(XqwlPosition.HASH_PV, 42, 10, 0);

      search.recordHash(XqwlPosition.HASH_PV, 17, 3, 0);

      final entry = search
          .hashTable[search.pos.zobr.dwKey & (XqwlPosition.HASH_SIZE - 1)];
      expect(entry.ucDepth, 10);
      expect(entry.svl, 42);
    },
  );

  test('a time-limited search keeps a legal fallback move', () {
    final search = XqwlSearch()..searchMain(maxDepth: 10, maxThinkMs: 1);

    expect(search.mvResult, isNot(0));
    expect(search.pos.legalMove(search.mvResult), isTrue);
  });
}
