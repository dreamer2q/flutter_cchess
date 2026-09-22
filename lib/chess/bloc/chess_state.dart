part of 'chess_bloc.dart';

enum BoardStatus { initialized, idle, busy }

enum PlaySide { red, black }

enum PlayMode { withSelf, withAI, withNetwork }

enum PlayEffect { eat, check, mate }

enum PlayStatus { draw, win, lose }

class ChessState extends Equatable {
  const ChessState({
    required this.board,
    this.selected,
    this.selectedMoves,
    this.animeMove,
    this.animeMoveInvalid,
    this.status = BoardStatus.busy,
    this.playMode = PlayMode.withAI,
    this.playSide = PlaySide.red,
    this.hintMoves,
    this.playEffect,
    this.playStatus,
    this.winningSide,
    this.lastMove,
  });

  /// 棋盘棋子状态
  final Board board;

  /// 当前 Player 选中的棋子
  final PiecePair? selected;

  /// 当前选择的棋子可走子的位置
  final BuiltList<MovePos>? selectedMoves;

  /// 当前正在执行走子动画
  final MovePos? animeMove;

  /// 非法走子动画
  final MovePos? animeMoveInvalid;

  /// 棋盘当前的状态
  final BoardStatus status;

  /// 当前运行模式
  final PlayMode playMode;

  /// 玩家选择的阵营(默认red)
  final PlaySide playSide;

  /// 电脑提示走法
  final BuiltList<MovePos>? hintMoves;

  /// 动画效果
  final PlayEffect? playEffect;

  /// 棋局结果
  final PlayStatus? playStatus;

  /// 本地双人模式下的胜方
  final PlaySide? winningSide;

  /// 保存上次动作, 用于提示
  final MovePos? lastMove;

  // 时间相关
  // 开始时间
  // 总时间
  // 每人时间

  @override
  List<Object?> get props => [
        board,
        selected,
        selectedMoves,
        animeMove,
        animeMoveInvalid,
        hintMoves,
        playMode,
        playSide,
        playEffect,
        playStatus,
        winningSide,
        status,
      ];

  ChessState copyWith({
    Board? board,
    PiecePair? selected,
    BuiltList<MovePos>? selectedMoves,
    MovePos? animeMove,
    MovePos? animeMoveInvalid,
    BoardStatus? status,
    PlayMode? playMode,
    PlaySide? playSide,
    BuiltList<MovePos>? hintMoves,
    PlayEffect? playEffect,
    PlayStatus? playStatus,
    PlaySide? winningSide,
    MovePos? lastMove,
  }) {
    return ChessState(
      board: board ?? this.board,
      selected: selected,
      selectedMoves: selectedMoves,
      animeMove: animeMove,
      animeMoveInvalid: animeMoveInvalid,
      status: status ?? this.status,
      playMode: playMode ?? this.playMode,
      playSide: playSide ?? this.playSide,
      hintMoves: hintMoves ?? this.hintMoves,
      playEffect: playEffect,
      playStatus: playStatus ?? this.playStatus,
      winningSide: winningSide ?? this.winningSide,
      lastMove: lastMove ?? this.lastMove,
    );
  }
}

// class ChessInitialState extends ChessState {}
