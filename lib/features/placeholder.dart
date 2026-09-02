import 'package:flutter/material.dart';

class Placeholder extends StatelessWidget {
  const Placeholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(title),
      ),
    );
  }
}
