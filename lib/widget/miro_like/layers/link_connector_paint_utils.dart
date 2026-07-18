import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/connector_path_utils.dart'
    show buildConnectorPath;
import 'package:jsonschema/widget/miro_like/layers/link_visual_effects_utils.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';

Path buildLinkConnectorPath({
  required Offset from,
  required Offset to,
  required ConnectorType connectorType,
  List<Offset> viaPoints = const [],
  Offset? startTangent,
  Offset? endTangent,
}) {
  return buildConnectorPath(
    from,
    to,
    connectorType: connectorType,
    viaPoints: viaPoints,
    startTangent: startTangent,
    endTangent: endTangent,
  );
}

void paintLinkConnectorFromPath({
  required Canvas canvas,
  required Path path,
  required Offset arrowTip,
  required Color color,
  required double strokeWidth,
  required double zoomLevel,
  BlockLink? link,
  bool dashed = false,
  bool renderStatic = true,
  bool animateParticles = true,
  bool renderParticles = true,
  double? particlePhaseSeconds,
  int maxParticleCountPerPath = 48,
  bool useFlowArrowCodification = false,
}) {
  paintLinkConnectorVisuals(
    canvas: canvas,
    path: path,
    color: color,
    strokeWidth: strokeWidth,
    zoomLevel: zoomLevel,
    arrowTip: arrowTip,
    link: link,
    dashed: dashed,
    renderStatic: renderStatic,
    animateParticles: animateParticles,
    renderParticles: renderParticles,
    particlePhaseSeconds: particlePhaseSeconds,
    maxParticleCountPerPath: maxParticleCountPerPath,
    useFlowArrowCodification: useFlowArrowCodification,
  );
}

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
  bool animateParticles = true,
  bool useFlowArrowCodification = false,
}) {
  final path = buildLinkConnectorPath(
    from: from,
    to: to,
    connectorType: connectorType,
    viaPoints: viaPoints,
    startTangent: startTangent,
    endTangent: endTangent,
  );

  paintLinkConnectorFromPath(
    canvas: canvas,
    path: path,
    arrowTip: to,
    color: color,
    strokeWidth: strokeWidth,
    zoomLevel: zoomLevel,
    link: link,
    dashed: dashed,
    animateParticles: animateParticles,
    useFlowArrowCodification: useFlowArrowCodification,
  );
}
