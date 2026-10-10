import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/game/chess_engine.dart';
import 'package:flutter_cchess/models/board.dart';
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

  test('engine returns bounded position score and completed depth', () async {
    final engine = ChessEngine();
    addTearDown(engine.dispose);
    final board = FenUtil.parse(initialFenString);

    final evaluation = await engine.evaluatePosition(
      squares: board.innerBoard.ucpcSquares,
      sideToMove: board.innerBoard.sdPlayer,
      maxDepth: 2,
      maxThinkMs: 500,
    );

    expect(evaluation.score, isA<int>());
    expect(evaluation.depth, inInclusiveRange(1, 2));
  });

  test('pondering caches replies without changing the live position', () async {
    final engine = ChessEngine();
    addTearDown(engine.dispose);
    await engine.setStrength(AiStrength.easy);
    await engine.restore(const []);
    final board = FenUtil.parse(initialFenString);

    engine.startPonder(
      squares: board.innerBoard.ucpcSquares,
      sideToMove: board.innerBoard.sdPlayer,
      maxDepth: 3,
      maxThinkMs: 500,
    );
    for (var i = 0; i < 100 && engine.ponderedHumanMoves.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(engine.ponderedHumanMoves, isNotEmpty);

    final humanMove = engine.ponderedHumanMoves.first;
    expect(board.isMovable(MovePos.mv(humanMove)), isTrue);
    final reply = MovePos.mv(await engine.makeMove(humanMove, maxThinkMs: 300));
    final afterHuman = board.copyWith(
      actions: board.actions.rebuild(
        (actions) => actions..add(BoardMoveAction(humanMove)),
      ),
    );
    expect(afterHuman.isMovable(reply), isTrue);
    expect(engine.ponderedHumanMoves, isEmpty);
  });
}
