import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/storage/game_record.dart';
import 'package:flutter_cchess/utils/fen.dart';

class GameNotationImporter {
  const GameNotationImporter._();

  static final _tag = RegExp(
    r'^\[([A-Za-z][A-Za-z0-9_]*)\s+"([^"]*)"\]\s*$',
    multiLine: true,
  );
  static final _move = RegExp(
    r'^([a-i])([0-9])[-:]?([a-i])([0-9])$',
    caseSensitive: false,
  );

  static GameRecord parse(String source, {DateTime? importedAt}) {
    final text = source.trim();
    if (text.isEmpty) throw const FormatException('棋谱文件为空。');
    final now = (importedAt ?? DateTime.now()).toUtc();
    final record = text.startsWith('{')
        ? GameRecord.decode(text)
        : _parseIccs(text, now);
    _validateMoves(record);
    return GameRecord(
      id: 'import-${now.microsecondsSinceEpoch}',
      initialFen: record.initialFen,
      moves: record.moves,
      mode: GamePlayMode.self,
      createdAt: now,
      updatedAt: now,
      timeControlSeconds: 0,
    );
  }

  static GameRecord _parseIccs(String source, DateTime now) {
    final tags = <String, String>{};
    for (final match in _tag.allMatches(source)) {
      tags[match.group(1)!.toLowerCase()] = match.group(2)!;
    }
    final format = tags['format'];
    if (format != null && format.toUpperCase() != 'ICCS') {
      throw const FormatException('只支持 ICCS 坐标着法的 PGN。');
    }
    final fen = tags['fen'] ?? initialFenString;
    var body = source.replaceAll(_tag, ' ');
    body = body.replaceAll(RegExp(r';[^\r\n]*'), ' ');
    body = body.replaceAll(RegExp(r'\{[^}]*\}', dotAll: true), ' ');
    body = _removeVariations(body);
    body = body.replaceAll(RegExp(r'\b\d+\.(?:\.\.)?'), ' ');
    body = body.replaceAll(',', ' ');

    final moves = <GameMove>[];
    for (final raw in body.split(RegExp(r'\s+'))) {
      if (raw.isEmpty || raw == '...' || raw.startsWith(r'$')) continue;
      final token = raw.replaceFirst(RegExp(r'[!?+#]+$'), '');
      if (const ['*', '1-0', '0-1', '1/2-1/2', '0.5-0.5'].contains(token)) {
        continue;
      }
      final match = _move.firstMatch(token);
      if (match == null) {
        throw FormatException('不支持的着法：$raw。请使用 ICCS 坐标，如 h2e2。');
      }
      final from = SquareBoard.coordXYFix(
        match.group(1)!.toLowerCase().codeUnitAt(0) - 97,
        9 - int.parse(match.group(2)!),
      );
      final to = SquareBoard.coordXYFix(
        match.group(3)!.toLowerCase().codeUnitAt(0) - 97,
        9 - int.parse(match.group(4)!),
      );
      moves.add(GameMove(from: from, to: to));
      if (moves.length > 1000) {
        throw const FormatException('棋谱超过 1000 步，暂不支持导入。');
      }
    }
    if (moves.isEmpty) throw const FormatException('棋谱没有可导入的着法。');
    return GameRecord(
      id: 'parsed',
      initialFen: fen,
      moves: moves,
      mode: GamePlayMode.self,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _removeVariations(String source) {
    final result = StringBuffer();
    var depth = 0;
    for (final unit in source.codeUnits) {
      if (unit == 40) {
        depth++;
      } else if (unit == 41) {
        if (depth == 0) throw const FormatException('棋谱变例括号不匹配。');
        depth--;
      } else if (depth == 0) {
        result.writeCharCode(unit);
      }
    }
    if (depth != 0) throw const FormatException('棋谱变例括号不匹配。');
    return result.toString();
  }

  static void _validateMoves(GameRecord record) {
    var board = FenUtil.parse(record.initialFen);
    if (record.moves.isEmpty) {
      throw const FormatException('棋谱没有可导入的着法。');
    }
    for (var index = 0; index < record.moves.length; index++) {
      final entry = record.moves[index];
      final move = MovePos(entry.from, entry.to);
      if (!board.isMovable(move)) {
        throw FormatException('第 ${index + 1} 步不是合法着法。');
      }
      board = board.copyWith(
        actions: board.actions.rebuild(
          (actions) => actions..add(BoardMoveAction(move.mv)),
        ),
      );
    }
  }
}
