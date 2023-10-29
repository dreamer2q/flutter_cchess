import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';

class ChessBoardMenu extends StatelessWidget {
  const ChessBoardMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MenuItem(
            label: '菜单',
            icon: Icons.menu,
            onPressed: () {},
          ),
          _MenuItem(
            label: '分析',
            icon: Icons.analytics,
            onPressed: () {},
          ),
          _MenuItem(
            label: '提示',
            icon: Icons.info_outline,
            onPressed: () {
              context.read<ChessBloc>().add(ChessEventGetHint());
            },
          ),
          BlocBuilder<ChessBloc, ChessState>(
            builder: (context, state) => _MenuItem(
              label: '悔棋',
              icon: Icons.undo,
              onPressed: state.board.lastMoves.length > 1
                  ? () => context.read<ChessBloc>().add(ChessEventUndo())
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    Key? key,
    this.label = '',
    this.onPressed,
    required this.icon,
  }) : super(key: key);

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final double size = down ? 32 : 38;
    final Color? color = widget.onPressed == null ? Colors.grey : null;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: GestureDetector(
        onTapDown: (details) {
          setState(() {
            down = true;
          });
        },
        onTapUp: (details) {
          setState(() {
            down = false;
          });
        },
        onTap: widget.onPressed,
        child: AnimatedContainer(
          width: size,
          height: size,
          duration: const Duration(milliseconds: 50),
          child: FittedBox(
            child: Column(
              children: [
                Icon(widget.icon, color: color),
                Text(
                  widget.label,
                  style: TextStyle(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
