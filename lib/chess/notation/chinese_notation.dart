import 'package:built_collection/built_collection.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';

class ChineseNotationMove {
  const ChineseNotationMove({required this.isRed, required this.text});

  final bool isRed;
  final String text;
}

abstract class ChineseChessNotation {
  static const _numbers = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
  static const _redPieces = ['帅', '仕', '相', '马', '车', '炮', '兵'];
  static const _blackPieces = ['将', '士', '象', '马', '车', '炮', '卒'];

  /// Formats each move in traditional Chinese notation from its position
  /// before the move, including the moving side and same-file disambiguation.
  static List<ChineseNotationMove> formatHistory(Board history) {
    final setup = history.actions.whereType<BoardPutAction>();
    final cursor = Board(
      BuiltList<BoardAction>.of(setup),
      initialSideToMove: history.initialSideToMove,
    );
    final result = <ChineseNotationMove>[];

    for (final move in history.lastMoves) {
      final piece = cursor.getPiece(move.sqSrc);
      if (piece == null) continue;
      result.add(
        ChineseNotationMove(
          isRed: piece.isRedSide(),
          text: _formatMove(cursor, piece, move),
        ),
      );
      cursor.innerBoard.makeMove(move.mv);
    }
    return List.unmodifiable(result);
  }

  static String _formatMove(Board board, ChessPiece piece, MovePos move) {
    final isRed = piece.isRedSide();
    final sourceX = _fileIndex(move.sqSrc);
    final sourceY = _rankIndex(move.sqSrc);
    final destinationX = _fileIndex(move.sqDst);
    final destinationY = _rankIndex(move.sqDst);
    final destinationFile = _fileNumber(isRed, destinationX);
    final vertical = sourceX == destinationX;
    final horizontal = sourceY == destinationY;
    final forward = isRed ? destinationY < sourceY : destinationY > sourceY;
    final operation = horizontal
        ? '平'
        : forward
        ? '进'
        : '退';
    final distanceOrFile = horizontal
        ? destinationFile
        : vertical
        ? (destinationY - sourceY).abs()
        : destinationFile;
    final destination = _number(distanceOrFile);
    final pieces = isRed ? _redPieces : _blackPieces;
    final disambiguator = _sameFileDisambiguator(board, piece, move);
    final source =
        disambiguator ??
        '${pieces[piece.numTag]}${_number(_fileNumber(isRed, sourceX))}';

    return '$source$operation$destination';
  }

  static String? _sameFileDisambiguator(
    Board board,
    ChessPiece piece,
    MovePos move,
  ) {
    final sourceX = _fileIndex(move.sqSrc);
    final peers = board.pcPairs
        .where(
          (pair) =>
              pair.piece.numTag == piece.numTag &&
              pair.piece.isRedSide() == piece.isRedSide() &&
              _fileIndex(pair.sq) == sourceX,
        )
        .toList();
    if (peers.length < 2) return null;

    final isRed = piece.isRedSide();
    peers.sort((left, right) {
      final leftRank = _rankIndex(left.sq);
      final rightRank = _rankIndex(right.sq);
      return isRed
          ? leftRank.compareTo(rightRank)
          : rightRank.compareTo(leftRank);
    });
    final index = peers.indexWhere((pair) => pair.sq == move.sqSrc);
    if (index < 0) return null;

    final prefix = peers.length == 2
        ? index == 0
              ? '前'
              : '后'
        : peers.length == 3
        ? const ['前', '中', '后'][index]
        : index == 0
        ? '前'
        : index == peers.length - 1
        ? '后'
        : '中${_number(index + 1)}';
    final pieces = isRed ? _redPieces : _blackPieces;
    return '$prefix${pieces[piece.numTag]}';
  }

  static int _fileIndex(int square) =>
      SquareBoard.getFileX(square) - SquareBoard.FILE_LEFT;

  static int _rankIndex(int square) =>
      SquareBoard.getRankY(square) - SquareBoard.RANK_TOP;

  static int _fileNumber(bool isRed, int fileIndex) =>
      isRed ? 9 - fileIndex : fileIndex + 1;

  static String _number(int value) =>
      value > 0 && value <= _numbers.length ? _numbers[value - 1] : '$value';
}
