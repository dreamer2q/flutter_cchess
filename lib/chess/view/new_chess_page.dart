import 'package:flutter/material.dart';

class NewChessPage extends StatelessWidget {
  const NewChessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chinses Chess"),
      ),
      body: Column(
        children: [
          ElevatedButton(
            child: Text('人机对局'),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
