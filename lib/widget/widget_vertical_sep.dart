import 'package:flutter/material.dart';

class VerticalSep extends StatelessWidget {
  const VerticalSep({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: double.infinity,
      child: Center(
        child: Container(
          height: 100,
          width: 2,
          color: Colors.grey.shade700,
        ),
      ),
      // decoration: BoxDecoration(
      //   border: Border.all(width: 1, color: Colors.grey),
      // ),
    );
  }
}
