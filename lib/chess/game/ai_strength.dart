enum AiStrength {
  easy(maxDepth: 3, maxThinkMs: 300),
  normal(maxDepth: 5, maxThinkMs: 1500),
  hard(maxDepth: 64, maxThinkMs: 5000);

  const AiStrength({required this.maxDepth, required this.maxThinkMs});

  final int maxDepth;
  final int maxThinkMs;

  static AiStrength fromName(String? name) => AiStrength.values.firstWhere(
    (value) => value.name == name,
    orElse: () => AiStrength.normal,
  );
}
