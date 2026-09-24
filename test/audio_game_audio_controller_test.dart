import 'package:flutter_cchess/audio/audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioService implements AudioService {
  final List<GameAudioCue> played = [];
  bool initialized = false;
  bool stopped = false;
  bool disposed = false;
  bool _enabled = true;
  double _volume = 0.8;

  @override
  bool get isEnabled => _enabled;

  @override
  double get volume => _volume;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> play(GameAudioCue cue) async {
    if (_enabled) played.add(cue);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> stopAll() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameAudioCue', () {
    test('maps every cue to a bundled sound asset', () async {
      for (final cue in GameAudioCue.values) {
        expect(cue.assetPath, startsWith('sounds/'));
        expect(cue.assetPath, endsWith('.wav'));
        final asset = await rootBundle.load('assets/${cue.assetPath}');
        expect(asset.lengthInBytes, greaterThan(0));
      }
    });

    test('chooses the highest-priority cue for one move', () {
      expect(
        GameAudioCue.highestPriority(const [
          GameAudioCue.move,
          GameAudioCue.capture,
          GameAudioCue.check,
        ]),
        GameAudioCue.check,
      );
    });
  });

  group('AudioplayersAudioService', () {
    test(
      'disabled service is inert, clamps volume, and disposes safely',
      () async {
        final service = AudioplayersAudioService(enabled: false);

        await service.initialize();
        await service.play(GameAudioCue.move);
        await service.setVolume(2);
        expect(service.volume, 1);

        await service.setVolume(-1);
        expect(service.volume, 0);

        await service.dispose();
        expect(service.isEnabled, isFalse);
        await expectLater(
          service.play(GameAudioCue.move),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('GameAudioController', () {
    late _FakeAudioService service;
    late DateTime now;
    late GameAudioController controller;

    setUp(() {
      service = _FakeAudioService();
      now = DateTime.utc(2026, 1, 1);
      controller = GameAudioController(service: service, clock: () => now);
    });

    tearDown(() => controller.dispose());

    test('plays only the highest-priority cue for the same step', () async {
      final selected = await controller.playForStep(
        stepId: 'game-1:move-12',
        candidates: const [
          GameAudioCue.move,
          GameAudioCue.capture,
          GameAudioCue.check,
        ],
      );

      expect(selected, GameAudioCue.check);
      expect(service.played, [GameAudioCue.check]);

      await controller.playForStep(
        stepId: 'game-1:move-12',
        candidates: const [GameAudioCue.win],
      );
      expect(service.played, [GameAudioCue.check]);
    });

    test('de-duplicates the same cue for 80 milliseconds', () async {
      await controller.play(GameAudioCue.uiClick);

      now = now.add(const Duration(milliseconds: 79));
      expect(await controller.play(GameAudioCue.uiClick), isNull);

      now = now.add(const Duration(milliseconds: 1));
      expect(await controller.play(GameAudioCue.uiClick), GameAudioCue.uiClick);
      expect(service.played, [GameAudioCue.uiClick, GameAudioCue.uiClick]);
    });

    test('does not de-duplicate different cues', () async {
      await controller.play(GameAudioCue.move);
      await controller.play(GameAudioCue.capture);

      expect(service.played, [GameAudioCue.move, GameAudioCue.capture]);
    });

    test('stopAll preserves step history across lifecycle pauses', () async {
      await controller.playForStep(
        stepId: 'game-1:move-1',
        candidates: const [GameAudioCue.move],
      );
      await controller.stopAll();
      await controller.playForStep(
        stepId: 'game-1:move-1',
        candidates: const [GameAudioCue.move],
      );

      expect(service.stopped, isTrue);
      expect(service.played, [GameAudioCue.move]);
    });

    test('resetForNewGame clears semantic history', () async {
      await controller.playForStep(
        stepId: 'move-1',
        candidates: const [GameAudioCue.move],
      );
      await controller.resetForNewGame();
      now = now.add(const Duration(milliseconds: 80));
      await controller.playForStep(
        stepId: 'move-1',
        candidates: const [GameAudioCue.move],
      );

      expect(service.played, [GameAudioCue.move, GameAudioCue.move]);
    });
  });
}
