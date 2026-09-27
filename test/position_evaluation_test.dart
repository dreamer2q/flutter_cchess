import 'package:flutter_cchess/utils/fen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('position score is always measured from Red perspective', () {
    const redRookFen = '4k4/9/9/9/9/9/9/9/9/3K4R w - - 0 1';
    const blackRookFen = '4k3r/9/9/9/9/9/9/9/9/3K5 w - - 0 1';

    final redAdvantage = FenUtil.parse(redRookFen).staticEvaluationForRed;
    final blackAdvantage = FenUtil.parse(blackRookFen).staticEvaluationForRed;
    final samePositionBlackToMove = FenUtil.parse(
      redRookFen.replaceFirst(' w ', ' b '),
    ).staticEvaluationForRed;

    expect(redAdvantage, greaterThan(0));
    expect(blackAdvantage, lessThan(0));
    expect(samePositionBlackToMove, redAdvantage);
  });
}
