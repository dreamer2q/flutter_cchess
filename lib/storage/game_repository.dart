import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_record.dart';

/// Persistence boundary for local games.
abstract class GameRepository {
  Future<void> save(GameRecord record);

  Future<GameRecord?> get(String id);

  /// Returns the most recently saved game, or null when no game exists.
  Future<GameRecord?> getCurrent();

  Future<List<GameRecord>> list();

  Future<void> delete(String id);

  Future<void> clear();
}

/// A SharedPreferences-backed repository for the current offline app.
///
/// All records are stored in one versioned JSON value. This keeps the storage
/// format easy to migrate and is sufficient for the local game history size
/// expected by the first release.
class SharedPreferencesGameRepository implements GameRepository {
  SharedPreferencesGameRepository(this._preferences);

  static const storageKey = 'flutter_cchess.game_records.v1';

  final SharedPreferences _preferences;

  @override
  Future<void> save(GameRecord record) async {
    final records = await list();
    final index = records.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      records.add(record);
    } else {
      records[index] = record;
    }
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _write(records);
  }

  @override
  Future<GameRecord?> get(String id) async {
    for (final record in await list()) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<GameRecord?> getCurrent() async {
    final records = await list();
    return records.isEmpty ? null : records.first;
  }

  @override
  Future<List<GameRecord>> list() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return <GameRecord>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GameRecord>[];
      final records = <GameRecord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          records.add(GameRecord.fromJson(Map<String, dynamic>.from(item)));
        } on FormatException {
          // Ignore an individual corrupt record so other local games remain usable.
        }
      }
      records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return records;
    } on FormatException {
      return <GameRecord>[];
    }
  }

  @override
  Future<void> delete(String id) async {
    final records = await list()
      ..removeWhere((record) => record.id == id);
    await _write(records);
  }

  @override
  Future<void> clear() => _preferences.remove(storageKey);

  Future<void> _write(List<GameRecord> records) async {
    await _preferences.setString(
      storageKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}

/// An in-memory implementation useful for pure unit tests and previews.
class InMemoryGameRepository implements GameRepository {
  final Map<String, GameRecord> _records = <String, GameRecord>{};

  @override
  Future<void> save(GameRecord record) async => _records[record.id] = record;

  @override
  Future<GameRecord?> get(String id) async => _records[id];

  @override
  Future<GameRecord?> getCurrent() async {
    if (_records.isEmpty) return null;
    return (await list()).first;
  }

  @override
  Future<List<GameRecord>> list() async {
    final records = _records.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  @override
  Future<void> delete(String id) async => _records.remove(id);

  @override
  Future<void> clear() async => _records.clear();
}
