import 'package:flutter_cchess/chess/view/game_layout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses stacked layout for narrow or short windows', () {
    expect(GameLayoutPolicy.useDesktop(800, 900), isFalse);
    expect(GameLayoutPolicy.useDesktop(1024, 600), isFalse);
    expect(GameLayoutPolicy.useDesktop(1024, 768), isTrue);
  });

  test('desktop inspector shrinks before the board', () {
    expect(GameLayoutPolicy.inspectorWidth(900), 280);
    expect(GameLayoutPolicy.inspectorWidth(1200), 360);
    expect(GameLayoutPolicy.inspectorWidth(2000), 360);
  });
}
