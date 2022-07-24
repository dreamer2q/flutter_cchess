import 'package:flutter_cchess/cchess/cc_fen.dart';
import 'package:flutter_cchess/cchess/cc_piece.dart';

/// Player 抽象类
abstract class CcPlayer {
  CcPlayer({
    this.name = 'player',
    this.playerSide = CcPlayerSide.red,
    this.leftTime = const Duration(minutes: 15),
  });

  // player 昵称
  String name;

  CcPlayerSide playerSide;

  // player 剩余时间
  Duration leftTime;

  // receive action
  Future<bool> onMove(CcPieceMov mov);

  // 执棋走子
  Future<CcPieceMov> nextMove(Duration limit);

  /// 请求和棋
  Future<bool> requestDraw();

  /// 投降认输
  Future<bool> requestDefeat();
}
