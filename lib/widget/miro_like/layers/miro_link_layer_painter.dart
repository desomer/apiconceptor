import 'dart:math' as math;
import 'dart:collection';
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
  final ParticleAnimationMode particleAnimationMode;
  final String? hoveredBlockId;
  final String? hoveredLinkId;
  final bool renderStatic;
  final bool renderParticles;
  final double? animationPhaseSeconds;

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
    this.particleAnimationMode = ParticleAnimationMode.always,
    this.hoveredBlockId,
    this.hoveredLinkId,
    this.renderStatic = true,
    this.renderParticles = true,
    this.animationPhaseSeconds,
  });

  static final LinkedHashMap<String, _ConnectorGeometry> _geometryCache =
      LinkedHashMap<String, _ConnectorGeometry>();
  static const int _maxGeometryCacheEntries = 3000;

  void paint(Canvas canvas, Size size) {
    if (!renderStatic && !renderParticles) {
      return;
    }

    final blockById = <String, Block>{
      for (final block in blocks) block.id: block,
    };
    final viewport = Offset.zero & size;
    final cullViewport = viewport.inflate(160.0);
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
      final fromBlock = blockById[link.fromBlockId];
      final toBlock = blockById[link.toBlockId];
      if (fromBlock == null || toBlock == null) {
        continue;
      }

      final fromRect = blockRectCanvas(
        fromBlock,
        zoomLevel: zoomLevel,
        canvasOffset: canvasOffset,
      );
      final toRect = blockRectCanvas(
        toBlock,
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

      var roughLinkBounds = Rect.fromPoints(fromEdge, toEdge);
      for (final via in viaCanvas) {
        roughLinkBounds = roughLinkBounds.expandToInclude(
          Rect.fromCircle(center: via, radius: 1),
        );
      }
      final allowOffscreen =
          detachPreviewLinkId == link.id || selectedLink == link;
      if (!allowOffscreen &&
          !cullViewport.overlaps(roughLinkBounds.inflate(48.0))) {
        continue;
      }

      if (isNoteFlow) {
        if (!renderStatic) {
          continue;
        }
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
        if (!renderStatic) {
          continue;
        }
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

      final geometry = _resolveConnectorGeometry(
        link: link,
        fromEdge: fromEdge,
        toEdge: toEdge,
        connectorType: link.connectorType,
        viaCanvas: viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
      );

      if (!allowOffscreen &&
          !cullViewport.overlaps(geometry.bounds.inflate(24.0))) {
        continue;
      }

      paintLinkConnectorFromPath(
        canvas: canvas,
        path: geometry.path,
        arrowTip: toEdge,
        color: resolvedColor,
        strokeWidth: isStrongFlowType
            ? linkPaint.strokeWidth * 4
            : (isThickType ? linkPaint.strokeWidth * 3 : linkPaint.strokeWidth),
        zoomLevel: zoomLevel,
        link: link,
        dashed: isDashedType,
        renderStatic: renderStatic,
        animateParticles: _shouldAnimateParticlesForLink(link),
        renderParticles: renderParticles,
        particlePhaseSeconds: animationPhaseSeconds,
        maxParticleCountPerPath: 40,
        useFlowArrowCodification: isFlowMode,
      );

      if (renderStatic) {
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
    }

    if (renderStatic) {
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
    }

    if (renderStatic &&
        linkingFromPoint != null &&
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

  bool _shouldAnimateParticlesForLink(BlockLink link) {
    if (!renderParticles) {
      return false;
    }
    if (detachPreviewLinkId == link.id) {
      return true;
    }

    switch (particleAnimationMode) {
      case ParticleAnimationMode.always:
        return true;
      case ParticleAnimationMode.hoverBlock:
        final hoveredId = hoveredBlockId;
        final hoveredLink = hoveredLinkId;
        if (hoveredLink != null && hoveredLink == link.id) {
          return true;
        }
        if (hoveredId == null) {
          return false;
        }
        return link.fromBlockId == hoveredId || link.toBlockId == hoveredId;
      case ParticleAnimationMode.hoverLink:
        return hoveredLinkId != null && hoveredLinkId == link.id;
    }
  }

  _ConnectorGeometry _resolveConnectorGeometry({
    required BlockLink link,
    required Offset fromEdge,
    required Offset toEdge,
    required ConnectorType connectorType,
    required List<Offset> viaCanvas,
    required Offset startTangent,
    required Offset endTangent,
  }) {
    final key = _geometryKey(
      link: link,
      fromEdge: fromEdge,
      toEdge: toEdge,
      connectorType: connectorType,
      viaCanvas: viaCanvas,
      startTangent: startTangent,
      endTangent: endTangent,
    );

    final cached = _geometryCache.remove(key);
    if (cached != null) {
      _geometryCache[key] = cached;
      return cached;
    }

    final path = buildLinkConnectorPath(
      from: fromEdge,
      to: toEdge,
      connectorType: connectorType,
      viaPoints: viaCanvas,
      startTangent: startTangent,
      endTangent: endTangent,
    );
    final bounds = path.getBounds();
    final geometry = _ConnectorGeometry(path: path, bounds: bounds);
    _geometryCache[key] = geometry;
    if (_geometryCache.length > _maxGeometryCacheEntries) {
      _geometryCache.remove(_geometryCache.keys.first);
    }
    return geometry;
  }

  String _geometryKey({
    required BlockLink link,
    required Offset fromEdge,
    required Offset toEdge,
    required ConnectorType connectorType,
    required List<Offset> viaCanvas,
    required Offset startTangent,
    required Offset endTangent,
  }) {
    final via = viaCanvas
        .map((p) => '${p.dx.toStringAsFixed(2)},${p.dy.toStringAsFixed(2)}')
        .join('|');
    return '${link.id}:${connectorType.index}:'
        '${fromEdge.dx.toStringAsFixed(2)},${fromEdge.dy.toStringAsFixed(2)}:'
        '${toEdge.dx.toStringAsFixed(2)},${toEdge.dy.toStringAsFixed(2)}:'
        '${startTangent.dx.toStringAsFixed(2)},${startTangent.dy.toStringAsFixed(2)}:'
        '${endTangent.dx.toStringAsFixed(2)},${endTangent.dy.toStringAsFixed(2)}:'
        'z${zoomLevel.toStringAsFixed(3)}:'
        'o${canvasOffset.dx.toStringAsFixed(2)},${canvasOffset.dy.toStringAsFixed(2)}:'
        '$via';
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

class _ConnectorGeometry {
  final Path path;
  final Rect bounds;

  const _ConnectorGeometry({required this.path, required this.bounds});
}
