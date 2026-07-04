import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/connector_path_utils.dart'
    show buildConnectorPath;
import 'package:jsonschema/widget/miro_like/layers/link_visual_effects_utils.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';

void paintLinkConnector({
  required Canvas canvas,
  required Offset from,
  required Offset to,
  required ConnectorType connectorType,
  required Color color,
  required double strokeWidth,
  required double zoomLevel,
  List<Offset> viaPoints = const [],
  Offset? startTangent,
  Offset? endTangent,
  BlockLink? link,
  bool dashed = false,
  bool useFlowArrowCodification = false,
}) {
  final path = buildConnectorPath(
    from,
    to,
    connectorType: connectorType,
    viaPoints: viaPoints,
    startTangent: startTangent,
    endTangent: endTangent,
  );

  paintLinkConnectorVisuals(
    canvas: canvas,
    path: path,
    color: color,
    strokeWidth: strokeWidth,
    zoomLevel: zoomLevel,
    arrowTip: to,
    link: link,
    dashed: dashed,
    useFlowArrowCodification: useFlowArrowCodification,
  );
}
