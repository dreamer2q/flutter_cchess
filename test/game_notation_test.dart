import 'package:flutter_cchess/chess/notation/game_notation.dart';
import 'package:flutter_cchess/storage/game_record.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final importedAt = DateTime.utc(2026, 9, 25);

  test('imports ICCS PGN mainline with comments and variations', () {
    final record = GameNotationImporter.parse(
      '[Game "Chinese Chess"]\n'
      '[Format "ICCS"]\n'
      '1. h2e2 (1. b2e2) {center cannon} h7e7 *',
      importedAt: importedAt,
    );
    expect(record.moves, hasLength(2));
    expect(record.initialFen, initialFenString);
    expect(record.mode, GamePlayMode.self);
    expect(record.timeControlSeconds, 0);
  });

  test('imports compact and hyphenated ICCS text', () {
    final record = GameNotationImporter.parse(
      '1. H2-E2, H7-E7',
      importedAt: importedAt,
    );
    expect(record.moves, hasLength(2));
  });

  test('imports native JSON as a new local study without overwriting id', () {
    final source = GameNotationImporter.parse(
      'h2e2 h7e7',
      importedAt: importedAt,
    );
    final imported = GameNotationImporter.parse(
      source.copyWith(id: 'original-id').encode(),
      importedAt: importedAt.add(const Duration(seconds: 1)),
    );
    expect(imported.id, isNot('original-id'));
    expect(imported.moves, source.moves);
  });

  test(
    'rejects unsupported notation and illegal move without side effects',
    () {
      expect(
        () => GameNotationImporter.parse('1. C2=5 H8+7'),
        throwsFormatException,
      );
      expect(
        () => GameNotationImporter.parse('h2e2 h2e2'),
        throwsFormatException,
      );
      expect(() => GameNotationImporter.parse(''), throwsFormatException);
    },
  );
}
