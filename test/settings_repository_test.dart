import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const customSettings = GameSettings(
    themeConfigAsset: 'assets/skins/night/config.json',
    soundEnabled: false,
    musicEnabled: true,
    hapticsEnabled: false,
    motionPreference: MotionPreference.full,
  );

  test('in-memory repository loads defaults, saves, and clears', () async {
    final repository = InMemoryGameSettingsRepository();

    final defaults = await repository.load();
    expect(defaults, const GameSettings());
    expect(defaults.musicEnabled, isFalse);
    await repository.save(customSettings);
    expect(await repository.load(), customSettings);
    await repository.clear();
    final defaultsAfterClear = await repository.load();
    expect(defaultsAfterClear, const GameSettings());
    expect(defaultsAfterClear.musicEnabled, isFalse);
  });

  test('shared preferences repository persists settings under stable key',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesGameSettingsRepository(preferences);

    final defaults = await repository.load();
    expect(defaults, const GameSettings());
    expect(defaults.musicEnabled, isFalse);
    await repository.save(customSettings);

    expect(await repository.load(), customSettings);
    expect(
      preferences.containsKey(
        SharedPreferencesGameSettingsRepository.storageKey,
      ),
      isTrue,
    );
  });

  test('shared preferences repository falls back on corrupt data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesGameSettingsRepository.storageKey: '{bad json',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesGameSettingsRepository(preferences);

    final defaults = await repository.load();
    expect(defaults, const GameSettings());
    expect(defaults.musicEnabled, isFalse);
  });
}
