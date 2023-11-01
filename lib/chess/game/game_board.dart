/// xiangqi Witch Light
///
/// 局面结构
class SquareBoard {
  /// 棋盘范围
  static const int RANK_TOP = 3;
  static const int RANK_BOTTOM = 12;
  static const int FILE_LEFT = 3;
  static const int FILE_RIGHT = 11;

  /// 棋子编号
  static const int PIECE_KING = 0;
  static const int PIECE_ADVISOR = 1;
  static const int PIECE_BISHOP = 2;
  static const int PIECE_KNIGHT = 3;
  static const int PIECE_ROOK = 4;
  static const int PIECE_CANNON = 5;
  static const int PIECE_PAWN = 6;

  /// 其他常数
  static const int MAX_GEN_MOVES = 128; // 最大的生成走法数
  static const int MATE_VALUE = 10000; // 最高分值，即将死的分值
  // 搜索出胜负的分值界限，超出此值就说明已经搜索出杀棋了
  static const int MAX_MOVES = 256; // 最大的历史走法数
  static const int LIMIT_DEPTH = 64; // 最大的搜索深度
  static const int BAN_VALUE = MATE_VALUE - 100; // 长将判负的分值，低于该值将不写入置换表
  static const int WIN_VALUE = MATE_VALUE - 200; // 搜索出胜负的分值界限，超出此值就说明已经搜索出杀棋了
  static const int DRAW_VALUE = 20; // 和棋时返回的分数(取负值)
  static const int ADVANCED_VALUE = 3; // 先行权分值
  static const int RANDOM_MASK = 7; // 随机性分值
  static const int NULL_MARGIN = 400; // 空步裁剪的子力边界
  static const int NULL_DEPTH = 2; // 空步裁剪的裁剪深度
  static const int HASH_SIZE = 1 << 20; // 置换表大小
  static const int HASH_ALPHA = 1; // ALPHA节点的置换表项
  static const int HASH_BETA = 2; // BETA节点的置换表项
  static const int HASH_PV = 3; // PV节点的置换表项
  static const int BOOK_SIZE = 16384; // 开局库大小

  /// 判断棋子是否在棋盘中的数组
  static const ccInBoard /* [256] */ = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  ];

  /// 判断棋子是否在九宫的数组
  static const ccInFort /*[256]*/ = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  ];

  /// 判断步长是否符合特定走法的数组，1=帅(将)，2=仕(士)，3=相(象)
  static const ccLegalSpan /*[512]*/ = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 2, 1, 2, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 2, 1, 2, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0
  ];

  /// 根据步长判断马是否蹩腿的数组
  static const ccKnightPin /*[512]*/ = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, -16, 0, -16, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 16, 0, 16, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0
  ];

  /// 帅(将)的步长
  static const ccKingDelta = [-16, -1, 1, 16];

  /// 仕(士)的步长
  static const ccAdvisorDelta = [-17, -15, 15, 17];

  /// 马的步长，以帅(将)的步长作为马腿
  static const ccKnightDelta = [
    [-33, -31],
    [-18, 14],
    [-14, 18],
    [31, 33]
  ];

  /// 马被将军的步长，以仕(士)的步长作为马腿
  static const ccKnightCheckDelta = [
    [-33, -18],
    [-31, -14],
    [14, 31],
    [18, 33]
  ];

  /// 棋盘初始设置
  static const cucpcStartup /*[256]*/ = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 20, 19, 18, 17, 16, 17, 18, 19, 20, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0,
    0, 0, 0, 22, 0, 22, 0, 22, 0, 22, 0, 22, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 14, 0, 14, 0, 14, 0, 14, 0, 14, 0, 0, 0, 0,
    0, 0, 0, 0, 13, 0, 0, 0, 0, 0, 13, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 12, 11, 10, 9, 8, 9, 10, 11, 12, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  ];

  /// 子力位置价值表
  static const cucvlPiecePos /*[7][256]*/ = [
    [
      // 帅(将)
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 11, 15, 11, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ],
    [
      // 仕(士)
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 20, 0, 20, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 20, 0, 20, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ],
    [
      // 相(象)
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 20, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 18, 0, 0, 0, 23, 0, 0, 0, 18, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 20, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ],
    [
      // 马
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 90, 90, 90, 96, 90, 96, 90, 90, 90, 0, 0, 0, 0,
      0, 0, 0, 90, 96, 103, 97, 94, 97, 103, 96, 90, 0, 0, 0, 0,
      0, 0, 0, 92, 98, 99, 103, 99, 103, 99, 98, 92, 0, 0, 0, 0,
      0, 0, 0, 93, 108, 100, 107, 100, 107, 100, 108, 93, 0, 0, 0, 0,
      0, 0, 0, 90, 100, 99, 103, 104, 103, 99, 100, 90, 0, 0, 0, 0,
      0, 0, 0, 90, 98, 101, 102, 103, 102, 101, 98, 90, 0, 0, 0, 0,
      0, 0, 0, 92, 94, 98, 95, 98, 95, 98, 94, 92, 0, 0, 0, 0,
      0, 0, 0, 93, 92, 94, 95, 92, 95, 94, 92, 93, 0, 0, 0, 0,
      0, 0, 0, 85, 90, 92, 93, 78, 93, 92, 90, 85, 0, 0, 0, 0,
      0, 0, 0, 88, 85, 90, 88, 90, 88, 90, 85, 88, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ],
    [
      // 车
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 206, 208, 207, 213, 214, 213, 207, 208, 206, 0, 0, 0, 0,
      0, 0, 0, 206, 212, 209, 216, 233, 216, 209, 212, 206, 0, 0, 0, 0,
      0, 0, 0, 206, 208, 207, 214, 216, 214, 207, 208, 206, 0, 0, 0, 0,
      0, 0, 0, 206, 213, 213, 216, 216, 216, 213, 213, 206, 0, 0, 0, 0,
      0, 0, 0, 208, 211, 211, 214, 215, 214, 211, 211, 208, 0, 0, 0, 0,
      0, 0, 0, 208, 212, 212, 214, 215, 214, 212, 212, 208, 0, 0, 0, 0,
      0, 0, 0, 204, 209, 204, 212, 214, 212, 204, 209, 204, 0, 0, 0, 0,
      0, 0, 0, 198, 208, 204, 212, 212, 212, 204, 208, 198, 0, 0, 0, 0,
      0, 0, 0, 200, 208, 206, 212, 200, 212, 206, 208, 200, 0, 0, 0, 0,
      0, 0, 0, 194, 206, 204, 212, 200, 212, 204, 206, 194, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ],
    [
      // 炮
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 100, 100, 96, 91, 90, 91, 96, 100, 100, 0, 0, 0, 0,
      0, 0, 0, 98, 98, 96, 92, 89, 92, 96, 98, 98, 0, 0, 0, 0,
      0, 0, 0, 97, 97, 96, 91, 92, 91, 96, 97, 97, 0, 0, 0, 0,
      0, 0, 0, 96, 99, 99, 98, 100, 98, 99, 99, 96, 0, 0, 0, 0,
      0, 0, 0, 96, 96, 96, 96, 100, 96, 96, 96, 96, 0, 0, 0, 0,
      0, 0, 0, 95, 96, 99, 96, 100, 96, 99, 96, 95, 0, 0, 0, 0,
      0, 0, 0, 96, 96, 96, 96, 96, 96, 96, 96, 96, 0, 0, 0, 0,
      0, 0, 0, 97, 96, 100, 99, 101, 99, 100, 96, 97, 0, 0, 0, 0,
      0, 0, 0, 96, 97, 98, 98, 98, 98, 98, 97, 96, 0, 0, 0, 0,
      0, 0, 0, 96, 96, 97, 99, 99, 99, 97, 96, 96, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ],
    [
      // 兵(卒)
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 9, 9, 9, 11, 13, 11, 9, 9, 9, 0, 0, 0, 0,
      0, 0, 0, 19, 24, 34, 42, 44, 42, 34, 24, 19, 0, 0, 0, 0,
      0, 0, 0, 19, 24, 32, 37, 37, 37, 32, 24, 19, 0, 0, 0, 0,
      0, 0, 0, 19, 23, 27, 29, 30, 29, 27, 23, 19, 0, 0, 0, 0,
      0, 0, 0, 14, 18, 20, 27, 29, 27, 20, 18, 14, 0, 0, 0, 0,
      0, 0, 0, 7, 0, 13, 0, 16, 0, 13, 0, 7, 0, 0, 0, 0,
      0, 0, 0, 7, 0, 7, 0, 15, 0, 7, 0, 7, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ]
  ];

  /// 判断棋子是否在棋盘中
  static bool isInBoard(int sq) {
    return ccInBoard[sq] != 0;
  }

  /// 判断棋子是否在九宫中
  static bool isInFort(int sq) {
    return ccInFort[sq] != 0;
  }

  /// 获得格子的横坐标
  static int getRankY(int sq) {
    return sq >> 4;
  }

  /// 获得格子的纵坐标
  static int getFileX(int sq) {
    return sq & 15;
  }

  /// 根据纵坐标和横坐标获得格子
  static int coordXY(int x, int y) {
    return x + (y << 4);
  }

  static int coordXYFix(int x, int y) {
    return coordXY(x + FILE_LEFT, y + RANK_TOP);
  }

  /// 翻转格子
  static int getSquareFlip(int sq) {
    return 254 - sq;
  }

  /// 纵坐标水平镜像
  static int getFileFlip(int x) {
    return 14 - x;
  }

  /// 横坐标垂直镜像
  static int getRankFlip(int y) {
    return 15 - y;
  }

  /// 格子水平镜像
  static int getMirrorSquare(int sq) {
    return coordXY(getFileFlip(getFileX(sq)), getRankY(sq));
  }

  /// 格子水平镜像
  static int getSquareForward(int sq, int sd) {
    return sq - 16 + (sd << 5);
  }

  /// 走法是否符合帅(将)的步长
  static bool isKingSpan(int sqSrc, int sqDst) {
    return ccLegalSpan[sqDst - sqSrc + 256] == 1;
  }

  /// 走法是否符合仕(士)的步长
  static bool isAdvisorSpan(int sqSrc, int sqDst) {
    return ccLegalSpan[sqDst - sqSrc + 256] == 2;
  }

  /// 走法是否符合相(象)的步长
  static bool isBishopSpan(int sqSrc, int sqDst) {
    return ccLegalSpan[sqDst - sqSrc + 256] == 3;
  }

  /// 相(象)眼的位置
  static int isBishopPin(int sqSrc, int sqDst) {
    return (sqSrc + sqDst) >> 1;
  }

  /// 马腿的位置
  static int isKnightPin(int sqSrc, int sqDst) {
    return sqSrc + ccKnightPin[sqDst - sqSrc + 256];
  }

  /// 是否未过河
  static bool isHomeHalf(int sq, int sd) {
    return (sq & 0x80) != (sd << 7);
  }

  /// 是否已过河
  static bool isAwayHalf(int sq, int sd) {
    return (sq & 0x80) == (sd << 7);
  }

  /// 是否在河的同一边
  static bool isSameHalf(int sqSrc, int sqDst) {
    return ((sqSrc ^ sqDst) & 0x80) == 0;
  }

  /// 是否在同一行
  static bool isSameRank(int sqSrc, int sqDst) {
    return ((sqSrc ^ sqDst) & 0xf0) == 0;
  }

  /// 是否在同一列
  static bool isSameFile(int sqSrc, int sqDst) {
    return ((sqSrc ^ sqDst) & 0x0f) == 0;
  }

  /// 获取棋子红黑标记
  /// 1 红色, 0 黑色
  static int getSideTag(int pc) {
    return (pc >> 3) & 0x01;
  }

  /// 是否同一阵营
  static bool isSameTag(int pc1, int pc2) {
    return getSideTag(pc1) == getSideTag(pc2);
  }

  /// 获得红黑标记(红子是8，黑子是16)
  static int isSideTag(int sd) {
    return 8 + (sd << 3);
  }

  /// 获得对方红黑标记
  static int getOppSideTag(int sd) {
    return 16 - (sd << 3);
  }

  /// 获得走法的起点
  static int getSrc(int mv) {
    return mv & 255;
  }

  /// 获得走法的终点
  static int getDst(int mv) {
    return mv >> 8;
  }

  /// 根据起点和终点获得走法
  static int getMove(int sqSrc, int sqDst) {
    return sqSrc + sqDst * 256;
  }

  /// 走法水平镜像
  static int getMirrorMove(int mv) {
    return getMove(getMirrorSquare(getSrc(mv)), getMirrorSquare(getDst(mv)));
  }

  //////////////////////////////////////////////////////////////////////////////

  int sdPlayer = 0; // 轮到谁走，0=红方，1=黑方
  List<int> ucpcSquares = List.filled(256, 0); // 棋盘上的棋子
  int vlWhite = 0;
  int vlBlack = 0; // 红、黑双方的子力价值
  int nDistance = 0; // 距离根节点的步数

  SquareBoard() {
    reset();
  }

  /// 重置空棋盘
  void reset() {
    // int sq, pc;
    sdPlayer = vlWhite = vlBlack = nDistance = 0;
    ucpcSquares.fillRange(0, ucpcSquares.length, 0);
    // for (sq = 0; sq < 256; sq++) {
    //   pc = cucpcStartup[sq];
    //   if (pc != 0) {
    //     addPiece(sq, pc);
    //   }
    // }
  }

  /// 交换走子方
  void changeSide() {
    sdPlayer = 1 - sdPlayer;
  }

  /// 在棋盘上放一枚棋子
  void addPiece(int sq, int pc) {
    ucpcSquares[sq] = pc;
    // 红方加分，黑方(注意"cucvlPiecePos"取值要颠倒)减分
    if (pc < 16) {
      vlWhite += cucvlPiecePos[pc - 8][sq];
    } else {
      vlBlack += cucvlPiecePos[pc - 16][getSquareFlip(sq)];
    }
  }

  /// 从棋盘上拿走一枚棋子
  void delPiece(int sq, int pc) {
    ucpcSquares[sq] = 0;
    // 红方减分，黑方(注意"cucvlPiecePos"取值要颠倒)加分
    if (pc < 16) {
      vlWhite -= cucvlPiecePos[pc - 8][sq];
    } else {
      vlBlack -= cucvlPiecePos[pc - 16][getSquareFlip(sq)];
    }
  }

  /// 局面评价函数
  int evaluate() {
    return (sdPlayer == 0 ? vlWhite - vlBlack : vlBlack - vlWhite) +
        ADVANCED_VALUE;
  }

  // 搬一步棋的棋子
  int movePiece(int mv) {
    int sqSrc, sqDst, pc, pcCaptured;
    sqSrc = getSrc(mv);
    sqDst = getDst(mv);
    pcCaptured = ucpcSquares[sqDst];
    if (pcCaptured != 0) {
      delPiece(sqDst, pcCaptured);
    }
    pc = ucpcSquares[sqSrc];
    delPiece(sqSrc, pc);
    addPiece(sqDst, pc);
    return pcCaptured;
  }

  // 撤消搬一步棋的棋子
  void undoMovePiece(int mv, int pcCaptured) {
    int sqSrc, sqDst, pc;
    sqSrc = getSrc(mv);
    sqDst = getDst(mv);
    pc = ucpcSquares[sqDst];
    delPiece(sqDst, pc);
    addPiece(sqSrc, pc);
    if (pcCaptured != 0) {
      addPiece(sqDst, pcCaptured);
    }
  }

  int moveCaptured(int mv) {
    int dst = getDst(mv);
    return ucpcSquares[dst];
  }

  /// 走一步棋
  bool makeMove(int mv) {
    int pcCaptured = movePiece(mv);
    if (checked()) {
      undoMovePiece(mv, pcCaptured);
      return false;
    }
    changeSide();
    nDistance++;
    return true;
  }

  /// 撤消走一步棋
  void undoMakeMove(int mv, int pcCaptured) {
    nDistance--;
    changeSide();
    undoMovePiece(mv, pcCaptured);
  }

  /// 生成所有走法
  int generateMoves(List<int> mvs) {
    /// *移除最大生成步数, 方便后续排序
    mvs.clear();
    void addMove(int src, int dst) {
      final mv = getMove(src, dst);
      mvs.add(mv);
    }

    int i, j, nDelta, sqSrc, sqDst;
    int pcSelfSide, pcOppSide, pcSrc, pcDst;
    // 生成所有走法，需要经过以下几个步骤：

    pcSelfSide = isSideTag(sdPlayer);
    pcOppSide = getOppSideTag(sdPlayer);
    for (sqSrc = 0; sqSrc < 256; sqSrc++) {
      // 1. 找到一个本方棋子，再做以下判断：
      pcSrc = ucpcSquares[sqSrc];
      if ((pcSrc & pcSelfSide) == 0) {
        continue;
      }

      // 2. 根据棋子确定走法
      switch (pcSrc - pcSelfSide) {
        case PIECE_KING:
          for (i = 0; i < 4; i++) {
            sqDst = sqSrc + ccKingDelta[i];
            if (!isInFort(sqDst)) {
              continue;
            }
            pcDst = ucpcSquares[sqDst];
            if ((pcDst & pcSelfSide) == 0) {
              addMove(sqSrc, sqDst);
            }
          }
          break;
        case PIECE_ADVISOR:
          for (i = 0; i < 4; i++) {
            sqDst = sqSrc + ccAdvisorDelta[i];
            if (!isInFort(sqDst)) {
              continue;
            }
            pcDst = ucpcSquares[sqDst];
            if ((pcDst & pcSelfSide) == 0) {
              addMove(sqSrc, sqDst);
            }
          }
          break;
        case PIECE_BISHOP:
          for (i = 0; i < 4; i++) {
            sqDst = sqSrc + ccAdvisorDelta[i];
            if (!(isInBoard(sqDst) &&
                isHomeHalf(sqDst, sdPlayer) &&
                ucpcSquares[sqDst] == 0)) {
              continue;
            }
            sqDst += ccAdvisorDelta[i];
            pcDst = ucpcSquares[sqDst];
            if ((pcDst & pcSelfSide) == 0) {
              addMove(sqSrc, sqDst);
            }
          }
          break;
        case PIECE_KNIGHT:
          for (i = 0; i < 4; i++) {
            sqDst = sqSrc + ccKingDelta[i];
            if (ucpcSquares[sqDst] != 0) {
              continue;
            }
            for (j = 0; j < 2; j++) {
              sqDst = sqSrc + ccKnightDelta[i][j];
              if (!isInBoard(sqDst)) {
                continue;
              }
              pcDst = ucpcSquares[sqDst];
              if ((pcDst & pcSelfSide) == 0) {
                addMove(sqSrc, sqDst);
              }
            }
          }
          break;
        case PIECE_ROOK:
          for (i = 0; i < 4; i++) {
            nDelta = ccKingDelta[i];
            sqDst = sqSrc + nDelta;
            while (isInBoard(sqDst)) {
              pcDst = ucpcSquares[sqDst];
              if (pcDst == 0) {
                addMove(sqSrc, sqDst);
              } else {
                if ((pcDst & pcOppSide) != 0) {
                  addMove(sqSrc, sqDst);
                }
                break;
              }
              sqDst += nDelta;
            }
          }
          break;
        case PIECE_CANNON:
          for (i = 0; i < 4; i++) {
            nDelta = ccKingDelta[i];
            sqDst = sqSrc + nDelta;
            while (isInBoard(sqDst)) {
              pcDst = ucpcSquares[sqDst];
              if (pcDst == 0) {
                addMove(sqSrc, sqDst);
              } else {
                break;
              }
              sqDst += nDelta;
            }
            sqDst += nDelta;
            while (isInBoard(sqDst)) {
              pcDst = ucpcSquares[sqDst];
              if (pcDst != 0) {
                if ((pcDst & pcOppSide) != 0) {
                  addMove(sqSrc, sqDst);
                }
                break;
              }
              sqDst += nDelta;
            }
          }
          break;
        case PIECE_PAWN:
          sqDst = getSquareForward(sqSrc, sdPlayer);
          if (isInBoard(sqDst)) {
            pcDst = ucpcSquares[sqDst];
            if ((pcDst & pcSelfSide) == 0) {
              addMove(sqSrc, sqDst);
            }
          }
          if (isAwayHalf(sqSrc, sdPlayer)) {
            for (nDelta = -1; nDelta <= 1; nDelta += 2) {
              sqDst = sqSrc + nDelta;
              if (isInBoard(sqDst)) {
                pcDst = ucpcSquares[sqDst];
                if ((pcDst & pcSelfSide) == 0) {
                  addMove(sqSrc, sqDst);
                }
              }
            }
          }
          break;
      }
    }
    return mvs.length;
  }

  /// 判断走法是否合理
  bool legalMove(int mv) {
    int sqSrc, sqDst, sqPin;
    int pcSelfSide, pcSrc, pcDst, nDelta;
    // 判断走法是否合法，需要经过以下的判断过程：

    // 1. 判断起始格是否有自己的棋子
    sqSrc = getSrc(mv);
    pcSrc = ucpcSquares[sqSrc];
    pcSelfSide = isSideTag(sdPlayer);
    if ((pcSrc & pcSelfSide) == 0) {
      return false;
    }

    // 2. 判断目标格是否有自己的棋子
    sqDst = getDst(mv);
    pcDst = ucpcSquares[sqDst];
    if ((pcDst & pcSelfSide) != 0) {
      return false;
    }

    // 3. 根据棋子的类型检查走法是否合理
    switch (pcSrc - pcSelfSide) {
      case PIECE_KING:
        return isInFort(sqDst) && isKingSpan(sqSrc, sqDst);
      case PIECE_ADVISOR:
        return isInFort(sqDst) && isAdvisorSpan(sqSrc, sqDst);
      case PIECE_BISHOP:
        return isSameHalf(sqSrc, sqDst) &&
            isBishopSpan(sqSrc, sqDst) &&
            ucpcSquares[isBishopPin(sqSrc, sqDst)] == 0;
      case PIECE_KNIGHT:
        sqPin = isKnightPin(sqSrc, sqDst);
        return sqPin != sqSrc && ucpcSquares[sqPin] == 0;
      case PIECE_ROOK:
      case PIECE_CANNON:
        if (isSameRank(sqSrc, sqDst)) {
          nDelta = (sqDst < sqSrc ? -1 : 1);
        } else if (isSameFile(sqSrc, sqDst)) {
          nDelta = (sqDst < sqSrc ? -16 : 16);
        } else {
          return false;
        }
        sqPin = sqSrc + nDelta;
        while (sqPin != sqDst && ucpcSquares[sqPin] == 0) {
          sqPin += nDelta;
        }
        if (sqPin == sqDst) {
          return pcDst == 0 || pcSrc - pcSelfSide == PIECE_ROOK;
        } else if (pcDst != 0 && pcSrc - pcSelfSide == PIECE_CANNON) {
          sqPin += nDelta;
          while (sqPin != sqDst && ucpcSquares[sqPin] == 0) {
            sqPin += nDelta;
          }
          return sqPin == sqDst;
        } else {
          return false;
        }
      case PIECE_PAWN:
        if (isAwayHalf(sqDst, sdPlayer) &&
            (sqDst == sqSrc - 1 || sqDst == sqSrc + 1)) {
          return true;
        }
        return sqDst == getSquareForward(sqSrc, sdPlayer);
      default:
        return false;
    }
  }

  /// 判断是否被将军
  bool checked() {
    int i, j, sqSrc, sqDst;
    int pcSelfSide, pcOppSide, pcDst, nDelta;
    pcSelfSide = isSideTag(sdPlayer);
    pcOppSide = getOppSideTag(sdPlayer);
    // 找到棋盘上的帅(将)，再做以下判断：

    for (sqSrc = 0; sqSrc < 256; sqSrc++) {
      if (ucpcSquares[sqSrc] != pcSelfSide + PIECE_KING) {
        continue;
      }

      // 1. 判断是否被对方的兵(卒)将军
      if (ucpcSquares[getSquareForward(sqSrc, sdPlayer)] ==
          pcOppSide + PIECE_PAWN) {
        return true;
      }
      for (nDelta = -1; nDelta <= 1; nDelta += 2) {
        if (ucpcSquares[sqSrc + nDelta] == pcOppSide + PIECE_PAWN) {
          return true;
        }
      }

      // 2. 判断是否被对方的马将军(以仕(士)的步长当作马腿)
      for (i = 0; i < 4; i++) {
        if (ucpcSquares[sqSrc + ccAdvisorDelta[i]] != 0) {
          continue;
        }
        for (j = 0; j < 2; j++) {
          pcDst = ucpcSquares[sqSrc + ccKnightCheckDelta[i][j]];
          if (pcDst == pcOppSide + PIECE_KNIGHT) {
            return true;
          }
        }
      }

      // 3. 判断是否被对方的车或炮将军(包括将帅对脸)
      for (i = 0; i < 4; i++) {
        nDelta = ccKingDelta[i];
        sqDst = sqSrc + nDelta;
        while (isInBoard(sqDst)) {
          pcDst = ucpcSquares[sqDst];
          if (pcDst != 0) {
            if (pcDst == pcOppSide + PIECE_ROOK ||
                pcDst == pcOppSide + PIECE_KING) {
              return true;
            }
            break;
          }
          sqDst += nDelta;
        }
        sqDst += nDelta;
        while (isInBoard(sqDst)) {
          int pcDst = ucpcSquares[sqDst];
          if (pcDst != 0) {
            if (pcDst == pcOppSide + PIECE_CANNON) {
              return true;
            }
            break;
          }
          sqDst += nDelta;
        }
      }
      return false;
    }
    return false;
  }

  /// 判断是否被杀
  bool isMate() {
    int i, nGenMoveNum, pcCaptured;
    List<int> mvs = [];

    nGenMoveNum = generateMoves(mvs);
    for (i = 0; i < nGenMoveNum; i++) {
      pcCaptured = movePiece(mvs[i]);
      if (!checked()) {
        undoMovePiece(mvs[i], pcCaptured);
        return false;
      } else {
        undoMovePiece(mvs[i], pcCaptured);
      }
    }
    return true;
  }
}
