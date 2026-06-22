import 'package:flutter/material.dart';

/// Enum for connector types
enum ConnectorType { bezier, orthogonal }

/// Represents a link between two blocks
class BlockLink {
  String fromBlockId;
  String toBlockId;
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
    this.connectorType = ConnectorType.bezier,
    List<Offset>? inflectionPoints,
    this.sourceAnchorUnit,
    this.targetAnchorUnit,
  }) : inflectionPoints = inflectionPoints ?? [];
}
