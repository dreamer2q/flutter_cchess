import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';

class NewChessPage extends StatelessWidget {
  const NewChessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('中国象棋'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('人机对局'),
              onPressed: () => _openGame(context, PlayMode.withAI),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.people_outline),
              label: const Text('本地双人'),
              onPressed: () => _openGame(context, PlayMode.withSelf),
            ),
          ],
        ),
      ),
    );
  }

  void _openGame(BuildContext context, PlayMode playMode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChessPage(playMode: playMode)),
    );
  }
}
