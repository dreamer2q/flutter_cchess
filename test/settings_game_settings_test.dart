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
    );

    expect(settings.toJson(), <String, Object>{
      'schemaVersion': 2,
      'themeConfigAsset': 'assets/skins/night/config.json',
      'soundEnabled': false,
      'musicEnabled': false,
      'hapticsEnabled': false,
      'motionPreference': 'reduced',
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
      () => GameSettings.fromJson(<String, dynamic>{'schemaVersion': 3}),
      throwsFormatException,
    );
    expect(
      () => GameSettings.fromJson(<String, dynamic>{'soundEnabled': 'yes'}),
      throwsFormatException,
    );
  });
}
