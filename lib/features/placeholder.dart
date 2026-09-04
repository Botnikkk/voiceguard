import 'package:flutter/material.dart';
import 'package:voiceguard/core/widgets/web_constraint.dart';

class Placeholder extends StatelessWidget {
  const Placeholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebConstraint(
        child: Center(
          child: Text(title),
        ),
      ),
    );
  }
}
