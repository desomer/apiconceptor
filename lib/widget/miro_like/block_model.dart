import 'package:flutter/material.dart';

/// Represents a block in the Miro-like diagram
class Block {
  String id;
  String title;
  Offset position;
  Size size;

  Block({
    required this.id,
    required this.title,
    this.position = const Offset(0, 0),
    this.size = const Size(150, 100),
  });
}
