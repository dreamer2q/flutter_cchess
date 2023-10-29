import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';

class NewChessPage extends StatelessWidget {
  const NewChessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chinses Chess"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: Text('人机对局'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return ChessPage();
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
