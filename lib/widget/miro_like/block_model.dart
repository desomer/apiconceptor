import 'package:flutter/material.dart';

const Map<String, Color> kBlockColorMap = {
  'slate': Color(0xFF3A3F4B),
  'blue': Color(0xFF1E3A8A),
  'teal': Color(0xFF0F766E),
  'green': Color(0xFF166534),
  'amber': Color(0xFF92400E),
  'rose': Color(0xFF9F1239),
};

const Map<String, String> kBlockColorLabelMap = {
  'slate': 'Slate',
  'blue': 'Blue',
  'teal': 'Teal',
  'green': 'Green',
  'amber': 'Amber',
  'rose': 'Rose',
};

/// Represents a block in the Miro-like diagram
class Block {
  String id;
  String title;
  String? colorKey;
  Offset position;
  Size size;

  Block({
    required this.id,
    required this.title,
    this.colorKey,
    this.position = const Offset(0, 0),
    this.size = const Size(150, 100),
  });
}
