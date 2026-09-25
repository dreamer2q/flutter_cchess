import 'package:flutter/material.dart';

class BoardCornerMarker extends StatelessWidget {
  const BoardCornerMarker({super.key, required this.dimension, this.child});

  final double dimension;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final cornerSize = (dimension * .13).clamp(6.0, 10.0);
    final inset = dimension * .04;
    Widget corner() => Container(
      width: cornerSize,
      height: cornerSize,
      decoration: BoxDecoration(
        color: const Color(0xFF168A65),
        border: Border.all(color: Colors.white, width: 1),
      ),
    );

    return SizedBox.square(
      dimension: dimension,
      child: Stack(
        children: [
          if (child != null) Positioned.fill(child: child!),
          Positioned(top: inset, left: inset, child: corner()),
          Positioned(top: inset, right: inset, child: corner()),
          Positioned(bottom: inset, left: inset, child: corner()),
          Positioned(bottom: inset, right: inset, child: corner()),
        ],
      ),
    );
  }
}
