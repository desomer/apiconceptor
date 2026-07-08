import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/layers/connector_path_utils.dart'
    show unitOrFallback;
import 'package:jsonschema/widget/miro_like/layers/link_connector_paint_utils.dart';
import 'package:jsonschema/widget/miro_like/layers/link_creation_preview_utils.dart';
import 'package:jsonschema/widget/miro_like/layers/link_geometry_utils.dart';
import 'package:jsonschema/widget/miro_like/layers/link_label_layout_utils.dart';
import 'package:jsonschema/widget/miro_like/mermaid_sequence_codec.dart';
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
  final String? detachPreviewLinkId;
  final Offset? detachPreviewCanvasPosition;
  final bool detachPreviewIsSource;

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
    this.detachPreviewLinkId,
    this.detachPreviewCanvasPosition,
    this.detachPreviewIsSource = false,
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

      var fromEdge = showSequenceParticipantLifelines
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

      var toEdge = showSequenceParticipantLifelines
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

      if (detachPreviewLinkId == link.id &&
          detachPreviewCanvasPosition != null) {
        if (detachPreviewIsSource) {
          fromEdge = detachPreviewCanvasPosition!;
        } else {
          toEdge = detachPreviewCanvasPosition!;
        }
      }

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
      final isFlowMode = !showSequenceParticipantLifelines;
      final isDashedType =
          isTypedArrow &&
          (isFlowMode ? arrowType.contains('.') : arrowType.startsWith('--'));
      final isThickType =
          isTypedArrow &&
          isFlowMode &&
          (arrowType.contains('==') || arrowType.startsWith('=>'));
      final isStrongFlowType =
          isTypedArrow && isFlowMode && arrowType.contains('==');
      final isDestroyType =
          isTypedArrow &&
          !isFlowMode &&
          (arrowType.endsWith('x') || arrowType.endsWith('X'));
      final isOpenType = isTypedArrow && !isFlowMode && arrowType.endsWith(')');

      final resolvedColor = detachPreviewLinkId == link.id
          ? colorLinkCreation
          : selectedLink == link
          ? colorLinkSelected
          : isDestroyType
          ? const Color(0xFFE57373)
          : isOpenType
          ? const Color(0xFFFFC107)
          : (kLinkColorMap[link.colorKey] ?? colorLinkDefault);

      final isNoteOver = MermaidSequenceCodec.isNoteOverType(arrowType);
      final isNoteFlow = MermaidSequenceCodec.isNoteFlowType(arrowType);

      if (isNoteFlow) {
        _paintDirectionalNoteArrow(
          canvas: canvas,
          link: link,
          from: fromEdge,
          to: toEdge,
          viaPoints: viaCanvas,
          startTangent: startTangent,
          endTangent: endTangent,
          color: resolvedColor,
          isSelected: selectedLink == link,
        );
        continue;
      }

      if (isNoteOver) {
        _paintNoteOverRect(
          canvas: canvas,
          link: link,
          from: fromEdge,
          to: toEdge,
          color: resolvedColor,
          isSelected: selectedLink == link,
        );
        continue;
      }

      paintLinkConnector(
        canvas: canvas,
        from: fromEdge,
        to: toEdge,
        connectorType: link.connectorType,
        color: resolvedColor,
        strokeWidth: isStrongFlowType
            ? linkPaint.strokeWidth * 4
            : (isThickType ? linkPaint.strokeWidth * 3 : linkPaint.strokeWidth),
        zoomLevel: zoomLevel,
        link: link,
        viaPoints: viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
        dashed: isDashedType,
        useFlowArrowCodification: isFlowMode,
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

  void _paintDirectionalNoteArrow({
    required Canvas canvas,
    required BlockLink link,
    required Offset from,
    required Offset to,
    required List<Offset> viaPoints,
    required Offset startTangent,
    required Offset endTangent,
    required Color color,
    required bool isSelected,
  }) {
    final direction = unitOrFallback(to - from, const Offset(1, 0));
    final totalLength = (to - from).distance;
    if (totalLength <= 1.0) {
      return;
    }

    final normal = Offset(-direction.dy, direction.dx);

    final thickness = (30.0 * zoomLevel).clamp(12.0, 56.0);
    final headLength = (28.0 * zoomLevel).clamp(12.0, 52.0);

    final effectiveHeadLength = math.min(
      headLength,
      math.max(8.0, totalLength * 0.45),
    );
    final bodyStart = from;
    final headBase = to - (direction * effectiveHeadLength);
    final bodyLength = (headBase - bodyStart).distance;
    if (bodyLength <= 4.0) {
      return;
    }

    final topStart = bodyStart + (normal * (thickness / 2));
    final topEnd = headBase + (normal * (thickness / 2));
    final bottomEnd = headBase - (normal * (thickness / 2));
    final bottomStart = bodyStart - (normal * (thickness / 2));

    final shapePath = Path()
      ..moveTo(topStart.dx, topStart.dy)
      ..lineTo(topEnd.dx, topEnd.dy)
      ..lineTo(to.dx, to.dy)
      ..lineTo(bottomEnd.dx, bottomEnd.dy)
      ..lineTo(bottomStart.dx, bottomStart.dy)
      ..close();

    final bodyFill = Paint()
      ..color = color.withValues(alpha: isSelected ? 0.55 : 0.42)
      ..style = PaintingStyle.fill;
    final bodyStroke = Paint()
      ..color = color.withValues(alpha: isSelected ? 0.98 : 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.6 * zoomLevel).clamp(1.1, 4.2);
    canvas.drawPath(shapePath, bodyFill);
    canvas.drawPath(shapePath, bodyStroke);

    final label = link.name.trim().isEmpty ? 'note' : link.name.trim();
    final iconData = kLinkLabelIconMap[link.labelIconKey];
    final tagGrid = buildLinkTagGridLayout(link, zoomLevel);
    final iconSpacing = iconData == null
        ? 0.0
        : (6.0 * zoomLevel).clamp(3.0, 16.0);
    TextPainter? iconPainter;
    if (iconData != null) {
      iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: (14.0 * zoomLevel).clamp(10.0, 28.0),
            color: Colors.white,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final maxTextWidth = math.max(
      12.0,
      bodyLength -
          (16.0 * zoomLevel) -
          (tagGrid?.width ?? 0.0) -
          (tagGrid == null ? 0.0 : (6.0 * zoomLevel).clamp(3.0, 14.0)) -
          (iconPainter?.width ?? 0.0) -
          iconSpacing,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: miroCanvasSecondaryLabelSize(zoomLevel).clamp(9.0, 24.0),
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);

    final textCenter = Offset(
      bodyStart.dx + (headBase.dx - bodyStart.dx) * 0.5,
      bodyStart.dy + (headBase.dy - bodyStart.dy) * 0.5,
    );

    final contentWidth =
        (tagGrid?.width ?? 0.0) +
        (tagGrid == null ? 0.0 : (6.0 * zoomLevel).clamp(3.0, 14.0)) +
        (iconPainter?.width ?? 0.0) +
        iconSpacing +
        textPainter.width;
    final contentHeight = math.max(
      math.max(textPainter.height, iconPainter?.height ?? 0.0),
      tagGrid?.height ?? 0.0,
    );
    var contentLeft = textCenter.dx - (contentWidth / 2);

    if (tagGrid != null) {
      final tagTop =
          textCenter.dy -
          (contentHeight / 2) +
          ((contentHeight - tagGrid.height) / 2);
      paintLinkTagGrid(
        canvas,
        tagGrid,
        Offset(contentLeft, tagTop),
        isSelected: isSelected,
      );
      contentLeft += tagGrid.width + (6.0 * zoomLevel).clamp(3.0, 14.0);
    }

    if (iconPainter != null) {
      final iconOffset = Offset(
        contentLeft,
        textCenter.dy -
            (contentHeight / 2) +
            ((contentHeight - iconPainter.height) / 2),
      );
      iconPainter.paint(canvas, iconOffset);
      contentLeft += iconPainter.width + iconSpacing;
    }

    final textOffset = Offset(
      contentLeft,
      textCenter.dy - (textPainter.height / 2),
    );
    textPainter.paint(canvas, textOffset);
  }

  void _paintNoteOverRect({
    required Canvas canvas,
    required BlockLink link,
    required Offset from,
    required Offset to,
    required Color color,
    required bool isSelected,
  }) {
    final left = math.min(from.dx, to.dx);
    final right = math.max(from.dx, to.dx);
    final width = (right - left).clamp(16.0, double.infinity);
    final y = (from.dy + to.dy) * 0.5;
    final height = (30.0 * zoomLevel).clamp(12.0, 56.0);

    final rect = Rect.fromCenter(
      center: Offset((left + right) * 0.5, y),
      width: width,
      height: height,
    );

    final radius = Radius.circular((height * 0.2).clamp(3.0, 14.0));
    final rrect = RRect.fromRectAndRadius(rect, radius);

    final fill = Paint()
      ..color = color.withValues(alpha: isSelected ? 0.55 : 0.42)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withValues(alpha: isSelected ? 0.98 : 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.4 * zoomLevel).clamp(1.0, 4.0);

    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, stroke);

    final label = link.name.trim().isEmpty ? 'note' : link.name.trim();
    final iconData = kLinkLabelIconMap[link.labelIconKey];
    final tagGrid = buildLinkTagGridLayout(link, zoomLevel);
    final iconSpacing = iconData == null
        ? 0.0
        : (6.0 * zoomLevel).clamp(3.0, 16.0);
    TextPainter? iconPainter;
    if (iconData != null) {
      iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: (14.0 * zoomLevel).clamp(10.0, 28.0),
            color: Colors.white,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final textPainter =
        TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.white,
              fontSize: miroCanvasSecondaryLabelSize(
                zoomLevel,
              ).clamp(9.0, 24.0),
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(
          maxWidth: math.max(
            12.0,
            width -
                (16.0 * zoomLevel) -
                (tagGrid?.width ?? 0.0) -
                (tagGrid == null ? 0.0 : (6.0 * zoomLevel).clamp(3.0, 14.0)) -
                (iconPainter?.width ?? 0.0) -
                iconSpacing,
          ),
        );

    final contentWidth =
        (tagGrid?.width ?? 0.0) +
        (tagGrid == null ? 0.0 : (6.0 * zoomLevel).clamp(3.0, 14.0)) +
        (iconPainter?.width ?? 0.0) +
        iconSpacing +
        textPainter.width;
    final contentHeight = math.max(
      math.max(textPainter.height, iconPainter?.height ?? 0.0),
      tagGrid?.height ?? 0.0,
    );
    final labelShiftX = tagGrid == null
        ? 0.0
        : -((tagGrid.width + (6.0 * zoomLevel).clamp(3.0, 14.0)) * 0.5);
    var contentLeft = rect.center.dx - (contentWidth / 2) + labelShiftX;

    if (tagGrid != null) {
      paintLinkTagGrid(
        canvas,
        tagGrid,
        Offset(
          contentLeft,
          rect.center.dy -
              (contentHeight / 2) +
              ((contentHeight - tagGrid.height) / 2),
        ),
        isSelected: isSelected,
      );
      contentLeft += tagGrid.width + (6.0 * zoomLevel).clamp(3.0, 14.0);
    }

    if (iconPainter != null) {
      final iconOffset = Offset(
        contentLeft,
        rect.center.dy -
            (contentHeight / 2) +
            ((contentHeight - iconPainter.height) / 2),
      );
      iconPainter.paint(canvas, iconOffset);
      contentLeft += iconPainter.width + iconSpacing;
    }

    final textOffset = Offset(
      contentLeft,
      rect.center.dy - (textPainter.height / 2),
    );
    textPainter.paint(canvas, textOffset);
  }
}
