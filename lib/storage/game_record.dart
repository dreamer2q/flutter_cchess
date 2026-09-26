import 'dart:convert';

import 'package:flutter_cchess/chess/game/ai_strength.dart';

/// The local play modes supported by the offline product.
enum GamePlayMode { self, ai, aiVsAi }

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
    AiStrength aiStrength = AiStrength.normal,
    AiStrength? redAiStrength,
    AiStrength? blackAiStrength,
    int? aiMaxDepth,
    int? aiMaxThinkMs,
  }) : aiStrength = aiStrength,
       redAiStrength = redAiStrength ?? aiStrength,
       blackAiStrength = blackAiStrength ?? aiStrength,
       aiMaxDepth = aiMaxDepth ?? aiStrength.maxDepth,
       aiMaxThinkMs = aiMaxThinkMs ?? aiStrength.maxThinkMs,
       moves = List.unmodifiable(moves);

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
  final AiStrength redAiStrength;
  final AiStrength blackAiStrength;
  final int aiMaxDepth;
  final int aiMaxThinkMs;

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
    AiStrength? redAiStrength,
    AiStrength? blackAiStrength,
    int? aiMaxDepth,
    int? aiMaxThinkMs,
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
      redAiStrength: redAiStrength ?? this.redAiStrength,
      blackAiStrength: blackAiStrength ?? this.blackAiStrength,
      aiMaxDepth: aiMaxDepth ?? this.aiMaxDepth,
      aiMaxThinkMs: aiMaxThinkMs ?? this.aiMaxThinkMs,
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
    'redAiStrength': redAiStrength.name,
    'blackAiStrength': blackAiStrength.name,
    'aiMaxDepth': aiMaxDepth,
    'aiMaxThinkMs': aiMaxThinkMs,
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
    if (aiStrengthValue != null && aiStrengthValue is! String) {
      throw const FormatException('Invalid AI strength.');
    }
    final aiStrength = AiStrength.fromName(aiStrengthValue as String?);
    final redStrengthValue = json['redAiStrength'];
    final blackStrengthValue = json['blackAiStrength'];
    if ((redStrengthValue != null && redStrengthValue is! String) ||
        (blackStrengthValue != null && blackStrengthValue is! String)) {
      throw const FormatException('Invalid side AI strength.');
    }
    final redAiStrength = AiStrength.fromName(
      redStrengthValue as String? ?? aiStrength.name,
    );
    final blackAiStrength = AiStrength.fromName(
      blackStrengthValue as String? ?? aiStrength.name,
    );
    final storedAiMaxDepth = json['aiMaxDepth'] ?? aiStrength.maxDepth;
    final storedAiMaxThinkMs = json['aiMaxThinkMs'] ?? aiStrength.maxThinkMs;

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
        storedAiMaxDepth is! int ||
        storedAiMaxDepth < 1 ||
        storedAiMaxDepth > 64 ||
        storedAiMaxThinkMs is! int ||
        storedAiMaxThinkMs < 100 ||
        storedAiMaxThinkMs > 10000) {
      throw const FormatException('Invalid game record.');
    }
    final legacyHardDefault = AiStrength.isLegacyHardDefault(
      strength: aiStrength,
      maxDepth: storedAiMaxDepth,
      maxThinkMs: storedAiMaxThinkMs,
    );
    final aiMaxDepth = legacyHardDefault
        ? aiStrength.maxDepth
        : AiStrength.clampDepth(storedAiMaxDepth);
    final aiMaxThinkMs = legacyHardDefault
        ? aiStrength.maxThinkMs
        : AiStrength.clampThinkMs(storedAiMaxThinkMs);
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
      aiStrength: aiStrength,
      redAiStrength: redAiStrength,
      blackAiStrength: blackAiStrength,
      aiMaxDepth: aiMaxDepth,
      aiMaxThinkMs: aiMaxThinkMs,
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
