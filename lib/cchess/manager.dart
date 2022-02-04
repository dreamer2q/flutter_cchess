import 'cc_board.dart';
import 'cc_skin.dart';

class GameManager {
  static final instance = GameManager._internal();
  static const defaultDuration = Duration(milliseconds: 300);

  final skin = CcSkin();
  final board = CcBoard();

  late final Future<bool> ready;

  GameManager._internal() {
    ready = Future(_init);
  }

  Future<bool> _init() async {
    await skin.init();
    return true;
  }

  factory GameManager() {
    return instance;
  }
}
