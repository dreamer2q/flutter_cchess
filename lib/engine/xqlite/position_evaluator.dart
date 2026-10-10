import 'dart:math' as math;

/// Board-dependent terms kept incrementally by the search position.
/// Positive values favor Red; the same calculation is used by the UI.
class PositionEvaluator {
  static bool isDefender(int piece) {
    final type = piece < 16 ? piece - 8 : piece - 16;
    return type == 1 || type == 2;
  }

  static int attackWeight(int piece, int square) {
    final side = piece < 16 ? 0 : 1;
    final type = piece - (side == 0 ? 8 : 16);
    final rank = square >> 4;
    final acrossRiver = side == 0 ? rank <= 7 : rank >= 8;
    return switch (type) {
      3 => acrossRiver ? 4 : 2, // Knight
      4 => acrossRiver ? 5 : 3, // Rook
      5 => acrossRiver ? 4 : 2, // Cannon
      6 => acrossRiver ? 1 : 0, // Pawn
      _ => 0,
    };
  }

  static int fromCounts(
    int redDefenders,
    int blackDefenders,
    int redAttack,
    int blackAttack,
  ) {
    int sideScore(int defenders, int opponentAttack) {
      final pressure = math.min(opponentAttack, 8);
      // Defensive pieces lose value as attacking material disappears.
      final defenseAdjustment = defenders * (pressure * 2 - 16);
      final kingExposure = math.max(0, pressure - 4) * (4 - defenders) * 2;
      return defenseAdjustment - kingExposure;
    }

    return sideScore(redDefenders, blackAttack) -
        sideScore(blackDefenders, redAttack);
  }

  static int evaluateSquares(List<int> squares) {
    var redDefenders = 0;
    var blackDefenders = 0;
    var redAttack = 0;
    var blackAttack = 0;
    for (var rank = 3; rank <= 12; rank++) {
      for (var file = 3; file <= 11; file++) {
        final square = (rank << 4) + file;
        final piece = squares[square];
        if (piece == 0) continue;
        if (piece < 16) {
          if (isDefender(piece)) redDefenders++;
          redAttack += attackWeight(piece, square);
        } else {
          if (isDefender(piece)) blackDefenders++;
          blackAttack += attackWeight(piece, square);
        }
      }
    }
    return fromCounts(redDefenders, blackDefenders, redAttack, blackAttack);
  }
}
