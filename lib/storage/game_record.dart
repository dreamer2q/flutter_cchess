import 'dart:convert';

import 'package:flutter_cchess/chess/game/ai_strength.dart';

/// The local play modes supported by the offline product.
enum GamePlayMode { self, ai }

/// The absolute result of a game, independent of which side the user played.
enum GameResult { inProgress, redWin, blackWin, draw }

/// A serializable move in mailbox-square coordinates.
class GameMove {
  const GameMove({required this.from, required this.to});

  final int from;
  final int to;

  Map<String, Object> toJson() => {'from': from, 'to': to};

  factory GameMove.fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final to = json['to'];
    if (from is! int || to is! int) {
      throw const FormatException(
        'A game move must contain integer from/to values.',
      );
    }
    return GameMove(from: from, to: to);
  }

  @override
  bool operator ==(Object other) =>
      other is GameMove && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// A complete local game snapshot. It is intentionally independent of BLoC
/// types so it can be reused by replay, analysis, and future import/export UI.
class GameRecord {
  GameRecord({
    required this.id,
    required this.initialFen,
    required List<GameMove> moves,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.result = GameResult.inProgress,
    this.redElapsedMs = 0,
    this.blackElapsedMs = 0,
    this.timeControlSeconds = 900,
    this.aiStrength = AiStrength.normal,
  }) : moves = List.unmodifiable(moves);

  final String id;
  final String initialFen;
  final List<GameMove> moves;
  final GamePlayMode mode;
  final GameResult result;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int redElapsedMs;
  final int blackElapsedMs;
  final int timeControlSeconds;
  final AiStrength aiStrength;

  GameRecord copyWith({
    String? id,
    String? initialFen,
    List<GameMove>? moves,
    GamePlayMode? mode,
    GameResult? result,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? redElapsedMs,
    int? blackElapsedMs,
    int? timeControlSeconds,
    AiStrength? aiStrength,
  }) {
    return GameRecord(
      id: id ?? this.id,
      initialFen: initialFen ?? this.initialFen,
      moves: moves ?? this.moves,
      mode: mode ?? this.mode,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      redElapsedMs: redElapsedMs ?? this.redElapsedMs,
      blackElapsedMs: blackElapsedMs ?? this.blackElapsedMs,
      timeControlSeconds: timeControlSeconds ?? this.timeControlSeconds,
      aiStrength: aiStrength ?? this.aiStrength,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'initialFen': initialFen,
    'moves': moves.map((move) => move.toJson()).toList(),
    'mode': mode.name,
    'result': result.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'redElapsedMs': redElapsedMs,
    'blackElapsedMs': blackElapsedMs,
    'timeControlSeconds': timeControlSeconds,
    'aiStrength': aiStrength.name,
  };

  String encode() => jsonEncode(toJson());

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final initialFen = json['initialFen'];
    final rawMoves = json['moves'];
    final mode = _enumFromName(GamePlayMode.values, json['mode']);
    final result = _enumFromName(GameResult.values, json['result']);
    final createdAtValue = json['createdAt'];
    final updatedAtValue = json['updatedAt'];
    final timeControlSeconds = json['timeControlSeconds'] ?? 0;
    final aiStrengthValue = json['aiStrength'];

    if (id is! String ||
        id.isEmpty ||
        initialFen is! String ||
        rawMoves is! List ||
        mode == null ||
        result == null ||
        createdAtValue is! String ||
        updatedAtValue is! String ||
        timeControlSeconds is! int ||
        timeControlSeconds < 0 ||
        (aiStrengthValue != null && aiStrengthValue is! String)) {
      throw const FormatException('Invalid game record.');
    }
    final createdAt = DateTime.tryParse(createdAtValue);
    final updatedAt = DateTime.tryParse(updatedAtValue);
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('Invalid game record timestamps.');
    }

    final moves = <GameMove>[];
    for (final move in rawMoves) {
      if (move is! Map) {
        throw const FormatException('Invalid game move.');
      }
      moves.add(GameMove.fromJson(Map<String, dynamic>.from(move)));
    }

    return GameRecord(
      id: id,
      initialFen: initialFen,
      moves: moves,
      mode: mode,
      result: result,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      redElapsedMs: _intValue(json['redElapsedMs']),
      blackElapsedMs: _intValue(json['blackElapsedMs']),
      timeControlSeconds: timeControlSeconds,
      aiStrength: AiStrength.fromName(aiStrengthValue as String?),
    );
  }

  factory GameRecord.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('A game record must be a JSON object.');
    }
    return GameRecord.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  bool operator ==(Object other) =>
      other is GameRecord && encode() == other.encode();

  @override
  int get hashCode => encode().hashCode;
}

T? _enumFromName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

int _intValue(Object? value) => value is int ? value : 0;
