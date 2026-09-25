import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/game/chess_engine.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/utils/fen.dart';

void main() {
  test('engine searches a legal move with selected strength', () async {
    final engine = ChessEngine();
    addTearDown(engine.dispose);

    await engine.setStrength(AiStrength.easy);
    await engine.restore(const []);
    final move = MovePos.mv(await engine.requestMove());

    expect(FenUtil.parse(initialFenString).isMovable(move), isTrue);
  });
}
