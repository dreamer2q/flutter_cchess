enum AiStrength {
  easy(maxDepth: 3, maxThinkMs: 300),
  normal(maxDepth: 5, maxThinkMs: 1500),
  hard(maxDepth: 6, maxThinkMs: 1500);

  static const int maxConfiguredDepth = 8;
  static const int maxConfiguredThinkMs = 2000;

  const AiStrength({required this.maxDepth, required this.maxThinkMs});

  final int maxDepth;
  final int maxThinkMs;

  static int clampDepth(int depth) =>
      depth.clamp(1, maxConfiguredDepth).toInt();

  static int clampThinkMs(int milliseconds) =>
      milliseconds.clamp(100, maxConfiguredThinkMs).toInt();

  static bool isLegacyHardDefault({
    required AiStrength strength,
    required int maxDepth,
    required int maxThinkMs,
  }) => strength == AiStrength.hard && maxDepth == 64 && maxThinkMs == 5000;

  static AiStrength fromName(String? name) => AiStrength.values.firstWhere(
    (value) => value.name == name,
    orElse: () => AiStrength.normal,
  );
}
