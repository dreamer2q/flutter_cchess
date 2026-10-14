import 'dart:ui';

import 'package:flutter/material.dart';

/// The application shell stays legible across all board skins.
abstract class AppPalette {
  static const canvas = Color(0xFFF2EFE8);
  static const surface = Color(0xFFFAF9F6);
  static const border = Color(0x26717F7B);
  static const ink = Color(0xFF202625);
  static const muted = Color(0xFF68716E);
  static const accent = Color(0xFF176B50);
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, this.asset, required this.child});

  final String? asset;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8F6F0), AppPalette.canvas, Color(0xFFE8EEE8)],
      ),
    ),
    child: Stack(
      children: [
        if (asset != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: .12,
                child: Image.asset(asset!, fit: BoxFit.cover),
              ),
            ),
          ),
        child,
      ],
    ),
  );
}

class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Material(
        color: AppPalette.surface.withValues(alpha: .88),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: const BorderSide(color: AppPalette.border),
        ),
        child: child,
      ),
    ),
  );
}
