enum AiStrength {
  easy(maxDepth: 0, maxThinkMs: 300),
  normal(maxDepth: 0, maxThinkMs: 1500),
  hard(maxDepth: 0, maxThinkMs: 5000);

  /// Zero means iterative deepening until the time budget expires.
  static const int automaticDepth = 0;
  static const int maxConfiguredDepth = 32;
  static const int maxConfiguredThinkMs = 10000;

  const AiStrength({required this.maxDepth, required this.maxThinkMs});

  final int maxDepth;
  final int maxThinkMs;

  static int clampDepth(int depth) =>
      depth.clamp(automaticDepth, maxConfiguredDepth).toInt();

  static int clampThinkMs(int milliseconds) =>
      milliseconds.clamp(100, maxConfiguredThinkMs).toInt();

  static bool isLegacyHardDefault({
    required AiStrength strength,
    required int maxDepth,
    required int maxThinkMs,
  }) => strength == AiStrength.hard && maxDepth == 64 && maxThinkMs == 5000;

  int get legacyDepth => switch (this) {
    easy => 3,
    normal => 5,
    hard => 8,
  };

  bool isLegacyPreset(int depth, int milliseconds) =>
      (depth == legacyDepth &&
          milliseconds == (this == hard ? 2000 : maxThinkMs)) ||
      isLegacyHardDefault(
        strength: this,
        maxDepth: depth,
        maxThinkMs: milliseconds,
      );

  static AiStrength fromName(String? name) => AiStrength.values.firstWhere(
    (value) => value.name == name,
    orElse: () => AiStrength.normal,
  );
}
