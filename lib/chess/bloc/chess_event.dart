part of 'chess_bloc.dart';

abstract class ChessEvent extends Equatable {
  const ChessEvent();

  @override
  List<Object> get props => [];
}

class ChessEventInitialized extends ChessEvent {
  const ChessEventInitialized({
    required this.initialBoard,
    this.playMode = PlayMode.withAI,
  });

  final Board initialBoard;
  final PlayMode playMode;

  @override
  List<Object> get props => [initialBoard, playMode];
}

class ChessEventBoardTap extends ChessEvent {
  const ChessEventBoardTap(this.pos);

  final PiecePos pos;

  @override
  List<Object> get props => [pos];
}

class ChessEventMoveBegin extends ChessEvent {
  const ChessEventMoveBegin(this.move);

  final MovePos move;

  @override
  List<Object> get props => [move];
}

class ChessEventMoveEnd extends ChessEvent {
  const ChessEventMoveEnd();
}

class ChessEventUndo extends ChessEvent {
  const ChessEventUndo();
}

class ChessEventGetHint extends ChessEvent {
  const ChessEventGetHint();
}
