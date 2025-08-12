import 'dart:ui';

import 'package:flutter/material.dart';

class DialogCard extends StatefulWidget {
  const DialogCard({super.key, required this.message});

  final Widget message;
  @override
  State<DialogCard> createState() => _DialogCardState();
}

class _DialogCardState extends State<DialogCard> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [widget.message, Spacer(), getBtn()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget getBtn() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color.fromARGB(235, 255, 123, 0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            "Continue",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
