part of 'chess_bloc.dart';

class ChessState extends Equatable {
  const ChessState({
    required this.board,
  });

  final Board board;

  @override
  List<Object?> get props => [board];

  ChessState copyWith({Board? board}) {
    return ChessState(
      board: board ?? this.board,
    );
  }
}

// /// 初始化中...不可操作
// class ChessInitial extends ChessState {
//   const ChessInitial({
//     required List<Piece> pieces,
//   }) : super(pieces: pieces);
// }

/// 空闲状态, 可操作
class ChessIdle extends ChessState {
  const ChessIdle({
    required super.board,
    this.selected,
    this.selectedMoves,
  });

  final Piece? selected;
  final List<PiecePosition>? selectedMoves;

  @override
  List<Object?> get props => [board, selected, selectedMoves];

  @override
  ChessIdle copyWith({
    Board? board,
    Piece? selected,
    List<PiecePosition>? selectedMoves,
  }) {
    return ChessIdle(
      board: board ?? this.board,
      selected: selected ?? this.selected,
      selectedMoves: selectedMoves ?? this.selectedMoves,
    );
  }
}

/// 棋盘繁忙(走子中), 执行动画, 不可操作
class ChessBusyMoving extends ChessState {
  const ChessBusyMoving({
    required super.board,
    required this.move,
  });

  // 动画进行中, Board 状态尚未更新
  final PieceMove move;

  @override
  List<Object?> get props => [board, move];
}

// /// 棋局结束
// class ChessOver extends ChessState {}
