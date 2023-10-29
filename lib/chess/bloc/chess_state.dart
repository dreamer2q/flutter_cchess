part of 'chess_bloc.dart';

enum BoardStatus { initialized, idle, busy }

enum PlayMode { withSelf, withAI, withNetwork }

class ChessState extends Equatable {
  const ChessState({
    this.board,
    this.selected,
    this.selectedMoves,
    this.animeMove,
    this.animeMoveInvalid,
    this.status = BoardStatus.busy,
    this.playMode = PlayMode.withAI,
  });

  /// 棋盘棋子状态
  final Board2? board;

  /// 当前 Player 选中的棋子
  final Piece? selected;

  /// 当前选择的棋子可走子的位置
  final List<PiecePosition>? selectedMoves;

  /// 当前正在执行走子动画
  final PieceMove? animeMove;

  /// 非法走子动画
  final PieceMove? animeMoveInvalid;

  /// 棋盘当前的状态
  final BoardStatus status;

  /// 当前运行模式
  final PlayMode playMode;

  @override
  List<Object?> get props => [
        board,
        selected,
        selectedMoves,
        animeMove,
        animeMoveInvalid,
        status,
        playMode,
      ];

  ChessState copyWith({
    Board2? board,
    Piece? selected,
    List<PiecePosition>? selectedMoves,
    PieceMove? animeMove,
    PieceMove? animeMoveInvalid,
    BoardStatus? status,
    PlayMode? playMode,
  }) {
    return ChessState(
      board: board ?? this.board,
      selected: selected,
      selectedMoves: selectedMoves,
      animeMove: animeMove,
      animeMoveInvalid: animeMoveInvalid,
      status: status ?? this.status,
      playMode: playMode ?? this.playMode,
    );
  }
}
