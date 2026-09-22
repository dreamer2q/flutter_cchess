import 'package:shared_preferences/shared_preferences.dart';

import 'game_settings.dart';

abstract class GameSettingsRepository {
  Future<GameSettings> load();

  Future<void> save(GameSettings settings);

  Future<void> clear();
}

class SharedPreferencesGameSettingsRepository
    implements GameSettingsRepository {
  SharedPreferencesGameSettingsRepository(this._preferences);

  /// Versioned so future migrations never need to reinterpret another value.
  static const String storageKey = 'flutter_cchess.game_settings.v1';

  final SharedPreferences _preferences;

  @override
  Future<GameSettings> load() async {
    final value = _preferences.getString(storageKey);
    if (value == null || value.isEmpty) return const GameSettings();

    try {
      return GameSettings.decode(value);
    } on FormatException {
      return const GameSettings();
    }
  }

  @override
  Future<void> save(GameSettings settings) async {
    await _preferences.setString(storageKey, settings.encode());
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(storageKey);
  }
}

class InMemoryGameSettingsRepository implements GameSettingsRepository {
  InMemoryGameSettingsRepository([GameSettings? initialSettings])
      : _settings = initialSettings;

  GameSettings? _settings;

  @override
  Future<GameSettings> load() async => _settings ?? const GameSettings();

  @override
  Future<void> save(GameSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> clear() async {
    _settings = null;
  }
}
