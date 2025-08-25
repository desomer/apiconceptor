import 'package:flutter/material.dart';

class VerticalSep extends StatelessWidget {
  const VerticalSep({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: Colors.white),
      ),
    );
  }
}
