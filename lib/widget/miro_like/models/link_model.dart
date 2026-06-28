import 'package:flutter/material.dart';

/// Enum for connector types
enum ConnectorType { bezier, orthogonal }

const Map<String, IconData> kLinkLabelIconMap = {
  'message': Icons.message_outlined,
  'api': Icons.api,
  'file': Icons.insert_drive_file_outlined,
  'database': Icons.storage,
  'upload': Icons.cloud_upload_outlined,
  'download': Icons.cloud_download_outlined,
  'transform': Icons.compare_arrows,
  'auth': Icons.lock_outline,
  'cache': Icons.cached,
  'error': Icons.error_outline,
};

const Map<String, String> kLinkLabelIconLabelMap = {
  'message': 'Message',
  'api': 'API',
  'file': 'Fichier',
  'database': 'Database',
  'upload': 'Upload',
  'download': 'Download',
  'transform': 'Transformation',
  'auth': 'Auth',
  'cache': 'Cache',
  'error': 'Erreur',
};

const Map<String, Color> kLinkColorMap = {
  'cyan': Color(0xFF64C8FF),
  'green': Color(0xFF4CAF50),
  'amber': Color(0xFFFFB300),
  'rose': Color(0xFFE91E63),
  'violet': Color(0xFF8B5CF6),
  'slate': Color(0xFF94A3B8),
};

const Map<String, String> kLinkColorLabelMap = {
  'cyan': 'Cyan',
  'green': 'Green',
  'amber': 'Amber',
  'rose': 'Rose',
  'violet': 'Violet',
  'slate': 'Slate',
};

/// Represents a link between two blocks
class BlockLink {
  String fromBlockId;
  String toBlockId;
  String name;
  String? colorKey;
  String? labelIconKey;
  double particleDensity;
  double particleSpeed;
  double labelPosition;
  Offset labelOffset;
  ConnectorType connectorType;
  List<Offset> inflectionPoints;
  Offset? sourceAnchorUnit;
  Offset? targetAnchorUnit;
  bool isSourceAnchorLocked = false;
  bool isTargetAnchorLocked = false;
  bool autoLayoutLock = false;
  double? sourceAnchorOrderKey;
  double? targetAnchorOrderKey;

  BlockLink({
    required this.fromBlockId,
    required this.toBlockId,
    this.name = '',
    this.colorKey,
    this.labelIconKey,
    this.particleDensity = 1.0,
    this.particleSpeed = 1.0,
    this.labelPosition = 0.75,
    this.labelOffset = Offset.zero,
    this.connectorType = ConnectorType.bezier,
    List<Offset>? inflectionPoints,
    this.sourceAnchorUnit,
    this.targetAnchorUnit,
    this.autoLayoutLock = false,
  }) : inflectionPoints = inflectionPoints ?? [];
}
