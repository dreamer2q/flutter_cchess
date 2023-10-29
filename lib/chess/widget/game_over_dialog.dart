import 'package:flutter/material.dart';

class GameOverDialog extends StatefulWidget {
  const GameOverDialog({super.key});

  @override
  State<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<GameOverDialog> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Text('Game over'),
        ],
      ),
    );
  }
}
