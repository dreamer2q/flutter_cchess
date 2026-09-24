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
      aiMaxDepth: 12,
      aiMaxThinkMs: 3200,
    );

    expect(settings.toJson(), <String, Object>{
      'schemaVersion': 3,
      'themeConfigAsset': 'assets/skins/night/config.json',
      'soundEnabled': false,
      'musicEnabled': false,
      'hapticsEnabled': false,
      'motionPreference': 'reduced',
      'aiStrength': 'hard',
      'aiMaxDepth': 12,
      'aiMaxThinkMs': 3200,
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
      () => GameSettings.fromJson(<String, dynamic>{'schemaVersion': 4}),
      throwsFormatException,
    );
    expect(
      () => GameSettings.fromJson(<String, dynamic>{'soundEnabled': 'yes'}),
      throwsFormatException,
    );
  });
}
