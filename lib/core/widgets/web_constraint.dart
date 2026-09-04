import 'package:flutter/material.dart';

class WebConstraint extends StatelessWidget {
  final Widget child;
  final double width;
  const WebConstraint({super.key, required this.child, this.width = 1000.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}
