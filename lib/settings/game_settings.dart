import 'dart:convert';

import 'package:flutter_cchess/chess/game/ai_strength.dart';

/// Controls how much non-essential animation the app should use.
enum MotionPreference {
  system('system'),
  full('full'),
  reduced('reduced');

  const MotionPreference(this.storageValue);

  final String storageValue;

  static MotionPreference? fromStorageValue(Object? value) {
    for (final preference in values) {
      if (preference.storageValue == value) return preference;
    }
    return null;
  }
}

/// User-controlled settings for the offline app.
class GameSettings {
  const GameSettings({
    this.themeConfigAsset = defaultThemeConfigAsset,
    this.soundEnabled = true,
    this.musicEnabled = false,
    this.hapticsEnabled = true,
    this.motionPreference = MotionPreference.system,
    this.aiStrength = AiStrength.normal,
    this.aiMaxDepth = AiStrength.automaticDepth,
    this.aiMaxThinkMs = 1500,
  });

  static const int schemaVersion = 4;
  static const String defaultThemeConfigAsset =
      'assets/skins/woods/config.json';

  final String themeConfigAsset;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final MotionPreference motionPreference;
  final AiStrength aiStrength;
  final int aiMaxDepth;
  final int aiMaxThinkMs;

  GameSettings copyWith({
    String? themeConfigAsset,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    MotionPreference? motionPreference,
    AiStrength? aiStrength,
    int? aiMaxDepth,
    int? aiMaxThinkMs,
  }) {
    return GameSettings(
      themeConfigAsset: themeConfigAsset ?? this.themeConfigAsset,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      motionPreference: motionPreference ?? this.motionPreference,
      aiStrength: aiStrength ?? this.aiStrength,
      aiMaxDepth: aiMaxDepth ?? this.aiMaxDepth,
      aiMaxThinkMs: aiMaxThinkMs ?? this.aiMaxThinkMs,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': schemaVersion,
    'themeConfigAsset': themeConfigAsset,
    'soundEnabled': soundEnabled,
    'musicEnabled': musicEnabled,
    'hapticsEnabled': hapticsEnabled,
    'motionPreference': motionPreference.storageValue,
    'aiStrength': aiStrength.name,
    'aiMaxDepth': aiMaxDepth,
    'aiMaxThinkMs': aiMaxThinkMs,
  };

  String encode() => jsonEncode(toJson());

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != null &&
        version != 1 &&
        version != 2 &&
        version != 3 &&
        version != schemaVersion) {
      throw FormatException('Unsupported settings schema version: $version');
    }

    const defaults = GameSettings();
    final storedThemeConfigAsset =
        json['themeConfigAsset'] ?? defaults.themeConfigAsset;
    final themeConfigAsset =
        storedThemeConfigAsset == 'assets/skins/maple/config.json'
        ? defaultThemeConfigAsset
        : storedThemeConfigAsset;
    final soundEnabled = json['soundEnabled'] ?? defaults.soundEnabled;
    final musicEnabled = json['musicEnabled'] ?? defaults.musicEnabled;
    final hapticsEnabled = json['hapticsEnabled'] ?? defaults.hapticsEnabled;
    final motionValue =
        json['motionPreference'] ?? defaults.motionPreference.storageValue;
    final motionPreference = MotionPreference.fromStorageValue(motionValue);
    final strengthValue = json['aiStrength'];
    if (strengthValue != null && strengthValue is! String) {
      throw const FormatException('Invalid AI strength.');
    }
    final aiStrength = AiStrength.fromName(strengthValue as String?);
    final storedAiMaxDepth = json['aiMaxDepth'] ?? aiStrength.maxDepth;
    final storedAiMaxThinkMs = json['aiMaxThinkMs'] ?? aiStrength.maxThinkMs;

    if (themeConfigAsset is! String ||
        themeConfigAsset.isEmpty ||
        soundEnabled is! bool ||
        musicEnabled is! bool ||
        hapticsEnabled is! bool ||
        motionPreference == null) {
      throw const FormatException('Invalid game settings.');
    }
    if (storedAiMaxDepth is! int ||
        storedAiMaxDepth < 0 ||
        storedAiMaxDepth > 64 ||
        storedAiMaxThinkMs is! int ||
        storedAiMaxThinkMs < 100 ||
        storedAiMaxThinkMs > 10000) {
      throw const FormatException('Invalid AI settings.');
    }
    final legacyPreset =
        version != schemaVersion &&
        aiStrength.isLegacyPreset(storedAiMaxDepth, storedAiMaxThinkMs);
    final aiMaxDepth = legacyPreset
        ? aiStrength.maxDepth
        : AiStrength.clampDepth(storedAiMaxDepth);
    final aiMaxThinkMs = legacyPreset
        ? aiStrength.maxThinkMs
        : AiStrength.clampThinkMs(storedAiMaxThinkMs);

    return GameSettings(
      themeConfigAsset: themeConfigAsset,
      soundEnabled: soundEnabled,
      musicEnabled: musicEnabled,
      hapticsEnabled: hapticsEnabled,
      motionPreference: motionPreference,
      aiStrength: aiStrength,
      aiMaxDepth: aiMaxDepth,
      aiMaxThinkMs: aiMaxThinkMs,
    );
  }

  factory GameSettings.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Game settings must be a JSON object.');
    }
    return GameSettings.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  bool operator ==(Object other) {
    return other is GameSettings &&
        other.themeConfigAsset == themeConfigAsset &&
        other.soundEnabled == soundEnabled &&
        other.musicEnabled == musicEnabled &&
        other.hapticsEnabled == hapticsEnabled &&
        other.motionPreference == motionPreference &&
        other.aiStrength == aiStrength &&
        other.aiMaxDepth == aiMaxDepth &&
        other.aiMaxThinkMs == aiMaxThinkMs;
  }

  @override
  int get hashCode => Object.hash(
    themeConfigAsset,
    soundEnabled,
    musicEnabled,
    hapticsEnabled,
    motionPreference,
    aiStrength,
    aiMaxDepth,
    aiMaxThinkMs,
  );
}
