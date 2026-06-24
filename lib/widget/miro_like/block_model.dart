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

const Map<String, Color> kBlockTagColorMap = {
  'red': Color(0xFFEF4444),
  'orange': Color(0xFFF97316),
  'yellow': Color(0xFFEAB308),
  'green': Color(0xFF22C55E),
  'cyan': Color(0xFF06B6D4),
  'blue': Color(0xFF3B82F6),
  'purple': Color(0xFFA855F7),
  'pink': Color(0xFFEC4899),
};

const Map<String, String> kBlockTagColorLabelMap = {
  'red': 'Red',
  'orange': 'Orange',
  'yellow': 'Yellow',
  'green': 'Green',
  'cyan': 'Cyan',
  'blue': 'Blue',
  'purple': 'Purple',
  'pink': 'Pink',
};

/// Represents a block in the Miro-like diagram
class Block {
  String id;
  String title;
  String? colorKey;
  List<String> tagColorKeys;
  String? iconBase64;
  String? propertiesJson;
  Offset position;
  Size size;

  Block({
    required this.id,
    required this.title,
    this.colorKey,
    List<String>? tagColorKeys,
    this.iconBase64,
    this.propertiesJson,
    this.position = const Offset(0, 0),
    this.size = const Size(150, 100),
  }) : tagColorKeys = List<String>.from(tagColorKeys ?? const <String>[]);
}
