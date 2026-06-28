import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/connector_path_utils.dart'
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
  required Color color,
  required Color inflectionPointColor,
  required double strokeWidth,
}) {
  final sourceRect = blockRectCanvas(
    linkSourceBlock,
    zoomLevel: zoomLevel,
    canvasOffset: canvasOffset,
  );

  final previewViaCanvas = pendingInflectionPoints
      .map(
        (point) => modelToCanvas(
          point,
          zoomLevel: zoomLevel,
          canvasOffset: canvasOffset,
        ),
      )
      .toList();

  final sourceReference = previewViaCanvas.isNotEmpty
      ? previewViaCanvas.first
      : currentMousePosition;
  final linkingFromCanvas = pointOnRectBorderTowards(
    sourceRect,
    sourceReference,
  );

  paintLinkConnector(
    canvas: canvas,
    from: linkingFromCanvas,
    to: currentMousePosition,
    connectorType: ConnectorType.bezier,
    color: color,
    strokeWidth: strokeWidth,
    zoomLevel: zoomLevel,
    startTangent: axisNormalForBorderPoint(sourceRect, linkingFromCanvas),
    viaPoints: previewViaCanvas,
  );

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
