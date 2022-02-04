import 'package:flutter/material.dart';
import 'package:flutter_cchess/cchess/cc_piece.dart';
import 'package:flutter_cchess/cchess/manager.dart';

class AnimatedSelectedPiece extends StatefulWidget {
  const AnimatedSelectedPiece({Key? key}) : super(key: key);

  @override
  _AnimatedSelectedPieceState createState() => _AnimatedSelectedPieceState();
}

class _AnimatedSelectedPieceState extends State<AnimatedSelectedPiece> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class AnimatedPieceMove extends StatefulWidget {
  const AnimatedPieceMove({
    Key? key,
    required this.child,
    this.onEnd,
    this.begin = Alignment.topLeft,
    this.end = Alignment.center,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  final Widget child;
  final Alignment begin;
  final Alignment end;
  final Duration duration;
  final VoidCallback? onEnd;

  @override
  State<AnimatedPieceMove> createState() => _AnimatedPieceMoveState();
}

class _AnimatedPieceMoveState extends State<AnimatedPieceMove>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 0,
  );

  late final Animation<Alignment> animation;

  @override
  void initState() {
    super.initState();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onEnd?.call();
      }
    });

    animation = AlignmentTween(
      begin: widget.begin,
      end: widget.end,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        return Align(
          alignment: animation.value,
          child: child,
        );
      },
    );
  }
}

class ChessPiece extends StatelessWidget {
  const ChessPiece({
    Key? key,
    required this.piece,
    this.alignment = Alignment.center,
    this.selected = false,
  }) : super(key: key);

  final CcPiece piece;
  final Alignment alignment;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final skin = GameManager.instance.skin;

    return Align(
      alignment: alignment,
      child: Container(
        decoration: selected ? skin.hoverDecoration : skin.decoration,
        child: skin.buildPiece(piece),
      ),
    );
  }
}
