import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to the classic theme and system motion preference', () {
    const settings = GameSettings();

    expect(settings.themeConfigAsset, GameSettings.defaultThemeConfigAsset);
    expect(settings.soundEnabled, isTrue);
    expect(settings.musicEnabled, isFalse);
    expect(settings.hapticsEnabled, isTrue);
    expect(settings.motionPreference, MotionPreference.system);
  });

  test('uses stable JSON keys and round trips all values', () {
    const settings = GameSettings(
      themeConfigAsset: 'assets/skins/night/config.json',
      soundEnabled: false,
      musicEnabled: false,
      hapticsEnabled: false,
      motionPreference: MotionPreference.reduced,
      aiStrength: AiStrength.hard,
      aiMaxDepth: 7,
      aiMaxThinkMs: 1900,
    );

    expect(settings.toJson(), <String, Object>{
      'schemaVersion': 4,
      'themeConfigAsset': 'assets/skins/night/config.json',
      'soundEnabled': false,
      'musicEnabled': false,
      'hapticsEnabled': false,
      'motionPreference': 'reduced',
      'aiStrength': 'hard',
      'aiMaxDepth': 7,
      'aiMaxThinkMs': 1900,
    });
    expect(GameSettings.decode(settings.encode()), settings);
  });

  test('fills missing fields with defaults for compatible migrations', () {
    final settings = GameSettings.fromJson(<String, dynamic>{
      'schemaVersion': 1,
      'soundEnabled': false,
    });

    expect(settings.soundEnabled, isFalse);
    expect(settings.musicEnabled, isFalse);
    expect(settings.themeConfigAsset, GameSettings.defaultThemeConfigAsset);
    expect(settings.motionPreference, MotionPreference.system);
    expect(settings.aiStrength, AiStrength.normal);
    expect(settings.aiMaxDepth, AiStrength.normal.maxDepth);
    expect(settings.aiMaxThinkMs, AiStrength.normal.maxThinkMs);
  });

  test('migrates version 2 preferences with default AI parameters', () {
    final settings = GameSettings.fromJson(<String, dynamic>{
      'schemaVersion': 2,
      'aiStrength': 'hard',
    });

    expect(settings.aiStrength, AiStrength.hard);
    expect(settings.aiMaxDepth, AiStrength.hard.maxDepth);
    expect(settings.aiMaxThinkMs, AiStrength.hard.maxThinkMs);
  });

  test('migrates the old hard preset and bounds saved custom limits', () {
    final oldPreset = GameSettings.fromJson(<String, dynamic>{
      'schemaVersion': 3,
      'aiStrength': 'hard',
      'aiMaxDepth': 64,
      'aiMaxThinkMs': 5000,
    });
    expect(oldPreset.aiMaxDepth, AiStrength.hard.maxDepth);
    expect(oldPreset.aiMaxThinkMs, AiStrength.hard.maxThinkMs);

    final custom = GameSettings.fromJson(<String, dynamic>{
      'schemaVersion': 3,
      'aiStrength': 'normal',
      'aiMaxDepth': 64,
      'aiMaxThinkMs': 10000,
    });
    expect(custom.aiMaxDepth, AiStrength.maxConfiguredDepth);
    expect(custom.aiMaxThinkMs, AiStrength.maxConfiguredThinkMs);
  });

  test('keeps configured AI budgets within supported device limits', () {
    expect(AiStrength.hard.maxDepth, AiStrength.automaticDepth);
    expect(AiStrength.hard.maxThinkMs, 5000);
    expect(AiStrength.clampDepth(0), 0);
    expect(AiStrength.clampDepth(64), AiStrength.maxConfiguredDepth);
    expect(AiStrength.clampThinkMs(10000), AiStrength.maxConfiguredThinkMs);
  });

  test('falls back when stored theme assets have been removed', () {
    final legacy = GameSettings.fromJson(<String, dynamic>{
      'schemaVersion': 1,
      'themeConfigAsset': 'assets/skins/maple/config.json',
    });
    expect(legacy.themeConfigAsset, GameSettings.defaultThemeConfigAsset);

    final selectedMaple = GameSettings.fromJson(<String, dynamic>{
      'schemaVersion': 2,
      'themeConfigAsset': 'assets/skins/maple/config.json',
    });
    expect(
      selectedMaple.themeConfigAsset,
      GameSettings.defaultThemeConfigAsset,
    );
  });

  test('rejects malformed and unsupported settings', () {
    expect(
      () => GameSettings.fromJson(<String, dynamic>{'schemaVersion': 5}),
      throwsFormatException,
    );
    expect(
      () => GameSettings.fromJson(<String, dynamic>{'soundEnabled': 'yes'}),
      throwsFormatException,
    );
  });

  test('migrates old preset caps but preserves custom depth and time', () {
    for (final strength in AiStrength.values) {
      final migrated = GameSettings.fromJson({
        'schemaVersion': 3,
        'aiStrength': strength.name,
        'aiMaxDepth': strength.legacyDepth,
        'aiMaxThinkMs': strength == AiStrength.hard
            ? 2000
            : strength.maxThinkMs,
      });
      expect(migrated.aiMaxDepth, 0);
      expect(migrated.aiMaxThinkMs, strength.maxThinkMs);
      expect(GameSettings.decode(migrated.encode()), migrated);
    }
    final custom = GameSettings.fromJson({
      'schemaVersion': 3,
      'aiMaxDepth': 4,
      'aiMaxThinkMs': 7000,
    });
    expect(custom.aiMaxDepth, 4);
    expect(custom.aiMaxThinkMs, 7000);
    const manual = GameSettings(aiMaxDepth: 5, aiMaxThinkMs: 1500);
    expect(GameSettings.decode(manual.encode()), manual);
  });
}
