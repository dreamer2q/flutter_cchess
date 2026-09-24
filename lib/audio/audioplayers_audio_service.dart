import 'package:audioplayers/audioplayers.dart';

import 'audio_service.dart';
import 'game_audio_cue.dart';

/// [AudioService] backed by preloaded audioplayers pools.
///
/// This service intentionally handles sound effects only. It does not create a
/// background music player or keep audio alive while the app is backgrounded.
class AudioplayersAudioService implements AudioService {
  AudioplayersAudioService({
    bool enabled = true,
    double volume = 0.45,
    AudioCache? audioCache,
    AudioContext? audioContext,
  }) : assert(volume >= 0 && volume <= 1),
       _enabled = enabled,
       _volume = volume,
       _audioCache = audioCache ?? AudioCache.instance,
       _audioContext = audioContext ?? _defaultAudioContext;

  static final AudioContext _defaultAudioContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  final AudioCache _audioCache;
  final AudioContext _audioContext;
  final Map<GameAudioCue, AudioPool> _pools = {};
  final Set<Future<void>> _activeStarts = {};

  Future<void>? _initializing;
  Future<void>? _stopping;
  bool _enabled;
  double _volume;
  bool _disposed = false;
  int _generation = 0;

  @override
  bool get isEnabled => _enabled;

  @override
  double get volume => _volume;

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    final stopping = _stopping;
    if (stopping != null) {
      await stopping;
      _ensureNotDisposed();
    }

    if (!_enabled || _pools.length == GameAudioCue.values.length) {
      return;
    }

    final inProgress = _initializing;
    if (inProgress != null) {
      await inProgress;
      return;
    }

    final initialization = _createPools();
    _initializing = initialization;
    await initialization.whenComplete(() {
      if (identical(_initializing, initialization)) {
        _initializing = null;
      }
    });
  }

  Future<void> _createPools() async {
    final created = <GameAudioCue, AudioPool>{};
    try {
      for (final cue in GameAudioCue.values) {
        final pool = await AudioPool.create(
          source: AssetSource(cue.assetPath),
          audioCache: _audioCache,
          audioContext: _audioContext,
          minPlayers: 1,
          maxPlayers: cue == GameAudioCue.uiClick ? 3 : 2,
        );
        created[cue] = pool;
      }
    } catch (_) {
      await Future.wait(created.values.map((pool) => pool.dispose()));
      rethrow;
    }

    if (_disposed || !_enabled) {
      await Future.wait(created.values.map((pool) => pool.dispose()));
      return;
    }

    _pools.addAll(created);
  }

  @override
  Future<void> play(GameAudioCue cue) async {
    _ensureNotDisposed();
    if (!_enabled) return;

    final generation = _generation;
    final stopping = _stopping;
    if (stopping != null) {
      await stopping;
      if (generation != _generation || !_enabled || _disposed) return;
    }

    await initialize();
    if (!_enabled || _disposed || generation != _generation) return;

    final pool = _pools[cue];
    if (pool == null) {
      throw StateError('Audio pool for ${cue.name} was not initialized.');
    }

    late final Future<void> start;
    start = pool.start(volume: _volume).then<void>((_) {}).whenComplete(() {
      _activeStarts.remove(start);
    });
    _activeStarts.add(start);
    await start;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _ensureNotDisposed();
    if (_enabled == enabled) return;

    _enabled = enabled;
    if (enabled) {
      await initialize();
    } else {
      await stopAll();
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _ensureNotDisposed();
    _volume = volume.clamp(0.0, 1.0).toDouble();
  }

  @override
  Future<void> stopAll() {
    final inProgress = _stopping;
    if (inProgress != null) return inProgress;

    _generation++;
    late final Future<void> stopping;
    stopping = _stopAll().whenComplete(() {
      _generation++;
      if (identical(_stopping, stopping)) {
        _stopping = null;
      }
    });
    _stopping = stopping;
    return stopping;
  }

  Future<void> _stopAll() async {
    final initialization = _initializing;
    try {
      if (initialization != null) {
        await initialization;
      }

      if (_activeStarts.isNotEmpty) {
        await Future.wait(_activeStarts.toList());
      }
    } finally {
      final pools = _pools.values.toList();
      _pools.clear();
      await Future.wait(pools.map((pool) => pool.dispose()));
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _enabled = false;
    await stopAll();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('AudioplayersAudioService has been disposed.');
    }
  }
}
