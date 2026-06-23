import 'package:flutter/material.dart';

/// Enum for connector types
enum ConnectorType { bezier, orthogonal }

const Map<String, IconData> kLinkLabelIconMap = {
  'api': Icons.api,
  'database': Icons.storage,
  'security': Icons.security,
  'cloud': Icons.cloud,
  'warning': Icons.warning_amber_rounded,
  'success': Icons.check_circle_outline,
  'code': Icons.code,
};

const Map<String, String> kLinkLabelIconLabelMap = {
  'api': 'API',
  'database': 'Database',
  'security': 'Security',
  'cloud': 'Cloud',
  'warning': 'Warning',
  'success': 'Success',
  'code': 'Code',
};

/// Represents a link between two blocks
class BlockLink {
  String fromBlockId;
  String toBlockId;
  String name;
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
  double? sourceAnchorOrderKey;
  double? targetAnchorOrderKey;

  BlockLink({
    required this.fromBlockId,
    required this.toBlockId,
    this.name = '',
    this.labelIconKey,
    this.particleDensity = 1.0,
    this.particleSpeed = 1.0,
    this.labelPosition = 0.75,
    this.labelOffset = Offset.zero,
    this.connectorType = ConnectorType.bezier,
    List<Offset>? inflectionPoints,
    this.sourceAnchorUnit,
    this.targetAnchorUnit,
  }) : inflectionPoints = inflectionPoints ?? [];
}
