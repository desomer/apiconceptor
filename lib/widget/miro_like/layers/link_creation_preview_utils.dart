import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/connector_path_utils.dart'
    show axisNormalForBorderPoint;
import 'package:jsonschema/widget/miro_like/layers/link_connector_paint_utils.dart';
import 'package:jsonschema/widget/miro_like/layers/link_geometry_utils.dart'
    hide axisNormalForBorderPoint;
import 'package:jsonschema/widget/miro_like/models/block_model.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';

void paintPendingLinkPreview({
  required Canvas canvas,
  required Block linkSourceBlock,
  required Offset currentMousePosition,
  required List<Offset> pendingInflectionPoints,
  required double zoomLevel,
  required Offset canvasOffset,
  required bool showSequenceParticipantLifelines,
  required Color color,
  required Color inflectionPointColor,
  required double strokeWidth,
}) {
  final sourceRect = blockRectCanvas(
    linkSourceBlock,
    zoomLevel: zoomLevel,
    canvasOffset: canvasOffset,
  );

  final previewViaCanvas = showSequenceParticipantLifelines
      ? const <Offset>[]
      : pendingInflectionPoints
            .map(
              (point) => modelToCanvas(
                point,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
              ),
            )
            .toList();

  final linkingFromCanvas = showSequenceParticipantLifelines
      ? Offset(sourceRect.center.dx, currentMousePosition.dy)
      : pointOnRectBorderTowards(
          sourceRect,
          previewViaCanvas.isNotEmpty
              ? previewViaCanvas.first
              : currentMousePosition,
        );

  final sequenceDirection = currentMousePosition.dx >= linkingFromCanvas.dx
      ? 1.0
      : -1.0;

  paintLinkConnector(
    canvas: canvas,
    from: linkingFromCanvas,
    to: currentMousePosition,
    connectorType: showSequenceParticipantLifelines
        ? ConnectorType.orthogonal
        : ConnectorType.bezier,
    color: color,
    strokeWidth: strokeWidth,
    zoomLevel: zoomLevel,
    startTangent: showSequenceParticipantLifelines
        ? Offset(sequenceDirection, 0)
        : axisNormalForBorderPoint(sourceRect, linkingFromCanvas),
    endTangent: showSequenceParticipantLifelines
        ? Offset(sequenceDirection, 0)
        : null,
    viaPoints: previewViaCanvas,
    useFlowArrowCodification: !showSequenceParticipantLifelines,
  );

  if (showSequenceParticipantLifelines) {
    return;
  }

  for (final point in previewViaCanvas) {
    canvas.drawCircle(
      point,
      5,
      Paint()
        ..color = inflectionPointColor
        ..style = PaintingStyle.fill,
    );
  }
}
