import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/link_connector_paint_utils.dart';
import 'package:jsonschema/widget/miro_like/layers/link_creation_preview_utils.dart';
import 'package:jsonschema/widget/miro_like/layers/link_geometry_utils.dart';
import 'package:jsonschema/widget/miro_like/layers/link_label_layout_utils.dart';
import 'package:jsonschema/widget/miro_like/models/block_model.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

class MiroLinkLayerPainter {
  final List<Block> blocks;
  final List<BlockLink> links;
  final Offset canvasOffset;
  final double zoomLevel;
  final BlockLink? selectedLink;
  final Offset? linkingFromPoint;
  final Offset? currentMousePosition;
  final Block? linkSourceBlock;
  final List<Offset> pendingInflectionPoints;
  final bool showSequenceParticipantLifelines;

  const MiroLinkLayerPainter({
    required this.blocks,
    required this.links,
    required this.canvasOffset,
    required this.zoomLevel,
    required this.selectedLink,
    required this.linkingFromPoint,
    required this.currentMousePosition,
    required this.linkSourceBlock,
    required this.pendingInflectionPoints,
    required this.showSequenceParticipantLifelines,
  });

  void paint(Canvas canvas, Size size) {
    final linkPaint = Paint()
      ..color = colorLinkDefault
      ..strokeWidth = _linkStrokeWidth()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final labelEntries =
        <
          ({
            BlockLink link,
            Offset fromEdge,
            Offset toEdge,
            List<Offset> viaCanvas,
            Offset startTangent,
            Offset endTangent,
            bool isSelected,
          })
        >[];

    for (final link in links) {
      final fromIndex = blocks.indexWhere((b) => b.id == link.fromBlockId);
      final toIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
      if (fromIndex == -1 || toIndex == -1) {
        continue;
      }

      final fromRect = blockRectCanvas(
        blocks[fromIndex],
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
      );
      final toRect = blockRectCanvas(
        blocks[toIndex],
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
      );

      final viaCanvas = link.inflectionPoints
          .map(
            (point) => modelToCanvas(
              point,
              zoomLevel: zoomLevel,
              canvasOffset: canvasOffset,
            ),
          )
          .toList();

      final fromReference = viaCanvas.isNotEmpty
          ? viaCanvas.first
          : pointOnRectBorderTowards(toRect, fromRect.center);
      final toReference = viaCanvas.isNotEmpty
          ? viaCanvas.last
          : pointOnRectBorderTowards(fromRect, toRect.center);
      final sequenceLaneYCanvas =
          link.sourceAnchorOrderKey != null || link.targetAnchorOrderKey != null
          ? ((link.sourceAnchorOrderKey ?? link.targetAnchorOrderKey!) *
                    zoomLevel) +
                canvasOffset.dy
          : null;

      final fromEdge = showSequenceParticipantLifelines
          ? Offset(
              fromRect.center.dx,
              math.max(
                fromRect.bottom + (8.0 * zoomLevel),
                viaCanvas.isNotEmpty
                    ? viaCanvas.first.dy
                    : (sequenceLaneYCanvas ??
                          math.max(fromRect.bottom, toRect.bottom) +
                              (40.0 * zoomLevel)),
              ),
            )
          : link.sourceAnchorUnit != null
          ? borderPointFromUnit(
              fromRect,
              link.sourceAnchorUnit!,
              spacingOffset: getAnchorSpacingOffset(
                currentLink: link,
                blockId: link.fromBlockId,
                anchorUnit: link.sourceAnchorUnit!,
                blocks: blocks,
                links: links,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
              ),
            )
          : pointOnRectBorderTowards(fromRect, fromReference);

      final toEdge = showSequenceParticipantLifelines
          ? Offset(
              toRect.center.dx,
              math.max(
                toRect.bottom + (8.0 * zoomLevel),
                viaCanvas.isNotEmpty
                    ? viaCanvas.last.dy
                    : (sequenceLaneYCanvas ??
                          math.max(fromRect.bottom, toRect.bottom) +
                              (40.0 * zoomLevel)),
              ),
            )
          : link.targetAnchorUnit != null
          ? borderPointFromUnit(
              toRect,
              link.targetAnchorUnit!,
              spacingOffset: getAnchorSpacingOffset(
                currentLink: link,
                blockId: link.toBlockId,
                anchorUnit: link.targetAnchorUnit!,
                blocks: blocks,
                links: links,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
              ),
            )
          : pointOnRectBorderTowards(toRect, toReference);

      final startTangent = outwardTangentForLinkEndpoint(
        link: link,
        isSource: true,
        rect: fromRect,
        edgePoint: fromEdge,
        showSequenceParticipantLifelines: showSequenceParticipantLifelines,
        blocks: blocks,
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
      );
      final targetOutward = outwardTangentForLinkEndpoint(
        link: link,
        isSource: false,
        rect: toRect,
        edgePoint: toEdge,
        showSequenceParticipantLifelines: showSequenceParticipantLifelines,
        blocks: blocks,
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
      );
      final endTangent = Offset(-targetOutward.dx, -targetOutward.dy);

      final arrowType = (link.sequenceArrowType ?? '').trim();
      final isTypedArrow = arrowType.isNotEmpty;
      final isDashedType = isTypedArrow && arrowType.startsWith('--');
      final isDestroyType =
          isTypedArrow && (arrowType.endsWith('x') || arrowType.endsWith('X'));
      final isOpenType = isTypedArrow && arrowType.endsWith(')');

      final resolvedColor = selectedLink == link
          ? colorLinkSelected
          : isDestroyType
          ? const Color(0xFFE57373)
          : isOpenType
          ? const Color(0xFFFFC107)
          : (kLinkColorMap[link.colorKey] ?? colorLinkDefault);

      paintLinkConnector(
        canvas: canvas,
        from: fromEdge,
        to: toEdge,
        connectorType: link.connectorType,
        color: resolvedColor,
        strokeWidth: linkPaint.strokeWidth,
        zoomLevel: zoomLevel,
        link: link,
        viaPoints: viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
        dashed: isDashedType,
      );

      labelEntries.add((
        link: link,
        fromEdge: fromEdge,
        toEdge: toEdge,
        viaCanvas: viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
        isSelected: selectedLink == link,
      ));
    }

    final labelLayouts = <LinkLabelLayout>[];
    for (final entry in labelEntries) {
      final layout = buildLinkLabelLayout(
        link: entry.link,
        from: entry.fromEdge,
        to: entry.toEdge,
        viaPoints: entry.viaCanvas,
        zoomLevel: zoomLevel,
        isSelected: entry.isSelected,
        startTangent: entry.startTangent,
        endTangent: entry.endTangent,
      );
      if (layout != null) {
        labelLayouts.add(layout);
      }
    }

    resolveLinkLabelOverlaps(labelLayouts);
    for (final layout in labelLayouts) {
      paintLinkLabelLayout(canvas, layout, zoomLevel: zoomLevel);
    }

    if (linkingFromPoint != null &&
        linkSourceBlock != null &&
        currentMousePosition != null) {
      paintPendingLinkPreview(
        canvas: canvas,
        linkSourceBlock: linkSourceBlock!,
        currentMousePosition: currentMousePosition!,
        pendingInflectionPoints: pendingInflectionPoints,
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
        showSequenceParticipantLifelines: showSequenceParticipantLifelines,
        color: colorLinkCreation,
        inflectionPointColor: colorInflectionPoint,
        strokeWidth: _linkStrokeWidth(),
      );
    }
  }

  double _linkStrokeWidth() {
    return (3.0 * zoomLevel).clamp(0.8, 9.0);
  }
}
