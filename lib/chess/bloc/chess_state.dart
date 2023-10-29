part of 'chess_bloc.dart';

enum BoardStatus { initialized, idle, busy }

enum PlayMode { withSelf, withAI, withNetwork }

enum PlaySide { red, black }

class ChessState extends Equatable {
  const ChessState({
    this.board,
    this.selected,
    this.selectedMoves,
    this.animeMove,
    this.animeMoveInvalid,
    this.status = BoardStatus.busy,
    this.playMode = PlayMode.withAI,
    this.playSide = PlaySide.red,
  });

  /// 棋盘棋子状态
  final Board? board;

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

  final PlaySide playSide;

  @override
  List<Object?> get props => [
        board,
        selected,
        selectedMoves,
        animeMove,
        animeMoveInvalid,
        status,
        playMode,
        playSide,
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
    );
  }
}
