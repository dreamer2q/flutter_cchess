part of 'chess_bloc.dart';

abstract class ChessEvent extends Equatable {
  const ChessEvent();

  @override
  List<Object> get props => [];
}

class ChessInitialized extends ChessEvent {
  const ChessInitialized({
    this.initialBoard,
    this.playMode = PlayMode.withAI,
  });

  final Board2? initialBoard;
  final PlayMode playMode;
}

class ChessBoardTapped extends ChessEvent {
  const ChessBoardTapped(this.position);

  final PiecePosition position;
}

class PieceBeginMovingEvent extends ChessEvent {
  const PieceBeginMovingEvent(this.piece, this.destination);

  final Piece piece;
  final PiecePosition destination;
}

class PieceEndMovingEvent extends ChessEvent {
  const PieceEndMovingEvent();
}

class PieceInvalidMoveBegin extends ChessEvent {
  const PieceInvalidMoveBegin(this.piece, this.destination);

  final Piece piece;
  final PiecePosition destination;
}

class PieceInvalidMoveEnd extends ChessEvent {
  const PieceInvalidMoveEnd();
}
