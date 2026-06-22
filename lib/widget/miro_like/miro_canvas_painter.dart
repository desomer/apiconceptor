import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/block_model.dart';
import 'package:jsonschema/widget/miro_like/link_model.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

extension on Offset {
  Offset rotate(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(dx * cos - dy * sin, dx * sin + dy * cos);
  }
}

class MiroCanvasPainter extends CustomPainter {
  final List<Block> blocks;
  final List<BlockLink> links;
  final Offset canvasOffset;
  final double zoomLevel;
  final Block? selectedBlock;
  final BlockLink? selectedLink;
  final Offset? linkingFromPoint;
  final Offset? currentMousePosition;
  final Block? linkSourceBlock;
  final Animation<double>? flowAnimation;
  final List<Offset> pendingInflectionPoints;

  MiroCanvasPainter({
    required this.blocks,
    required this.links,
    required this.canvasOffset,
    required this.zoomLevel,
    this.selectedBlock,
    this.selectedLink,
    this.linkingFromPoint,
    this.currentMousePosition,
    this.linkSourceBlock,
    this.flowAnimation,
    this.pendingInflectionPoints = const [],
  }) : super(repaint: flowAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner les liens
    final linkPaint = Paint()
      ..color = colorLinkDefault
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var link in links) {
      final fromIndex = blocks.indexWhere((b) => b.id == link.fromBlockId);
      final toIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
      if (fromIndex == -1 || toIndex == -1) {
        continue;
      }

      final fromBlock = blocks[fromIndex];
      final toBlock = blocks[toIndex];

      final fromRect = _blockRectCanvas(fromBlock);
      final toRect = _blockRectCanvas(toBlock);

      final viaCanvas = link.inflectionPoints
          .map((point) => _modelToCanvas(point))
          .toList();

      final toBorderForSource = _pointOnRectBorderTowards(
        toRect,
        fromRect.center,
      );
      final fromBorderForTarget = _pointOnRectBorderTowards(
        fromRect,
        toRect.center,
      );
      final fromReference = viaCanvas.isNotEmpty
          ? viaCanvas.first
          : toBorderForSource;
      final toReference = viaCanvas.isNotEmpty
          ? viaCanvas.last
          : fromBorderForTarget;
      final fromEdge = link.sourceAnchorUnit != null
          ? _borderPointFromUnit(
              fromRect,
              link.sourceAnchorUnit!,
              spacingOffset: _getAnchorSpacingOffset(
                link,
                link.fromBlockId,
                link.sourceAnchorUnit!,
              ),
            )
          : _pointOnRectBorderTowards(fromRect, fromReference);
      final toEdge = link.targetAnchorUnit != null
          ? _borderPointFromUnit(
              toRect,
              link.targetAnchorUnit!,
              spacingOffset: _getAnchorSpacingOffset(
                link,
                link.toBlockId,
                link.targetAnchorUnit!,
              ),
            )
          : _pointOnRectBorderTowards(toRect, toReference);

      final startTangent = _axisNormalForBorderPoint(fromRect, fromEdge);
      final targetOutward = _axisNormalForBorderPoint(toRect, toEdge);
      final endTangent = Offset(-targetOutward.dx, -targetOutward.dy);

      _drawArrow(
        canvas,
        fromEdge,
        toEdge,
        linkPaint,
        connectorType: link.connectorType,
        viaPoints: viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
        isSelected: selectedLink == link,
      );

      _drawLinkLabel(
        canvas,
        link,
        fromEdge,
        toEdge,
        viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
      );
    }

    // Dessiner le lien en cours de création
    if (linkingFromPoint != null &&
        linkSourceBlock != null &&
        currentMousePosition != null) {
      final tempPaint = Paint()
        ..color = colorLinkCreation
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final sourceRect = _blockRectCanvas(linkSourceBlock!);
      final previewViaCanvas = pendingInflectionPoints
          .map((point) => _modelToCanvas(point))
          .toList();
      final sourceReference = previewViaCanvas.isNotEmpty
          ? previewViaCanvas.first
          : currentMousePosition!;
      final linkingFromCanvas = _pointOnRectBorderTowards(
        sourceRect,
        sourceReference,
      );
      final startTangent = _axisNormalForBorderPoint(
        sourceRect,
        linkingFromCanvas,
      );

      // Dessiner une petite flèche de prévisualisation
      _drawArrow(
        canvas,
        linkingFromCanvas,
        currentMousePosition!,
        tempPaint,
        connectorType: ConnectorType.bezier,
        viaPoints: previewViaCanvas,
        startTangent: startTangent,
      );

      for (final point in previewViaCanvas) {
        canvas.drawCircle(
          point,
          5,
          Paint()
            ..color = colorInflectionPoint
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  Offset _modelToCanvas(Offset modelPoint) {
    return Offset(
      modelPoint.dx * zoomLevel + canvasOffset.dx,
      modelPoint.dy * zoomLevel + canvasOffset.dy,
    );
  }

  Rect _blockRectCanvas(Block block) {
    return Rect.fromLTWH(
      block.position.dx * zoomLevel + canvasOffset.dx,
      block.position.dy * zoomLevel + canvasOffset.dy,
      block.size.width * zoomLevel,
      block.size.height * zoomLevel,
    );
  }

  Offset _pointOnRectBorderTowards(Rect rect, Offset target) {
    final center = rect.center;
    final vector = target - center;
    if (vector.distanceSquared == 0) {
      return center;
    }

    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final scale =
        1 / math.max(vector.dx.abs() / halfW, vector.dy.abs() / halfH);
    return center + vector * scale;
  }

  Offset _borderPointFromUnit(
    Rect rect,
    Offset unit, {
    Offset spacingOffset = Offset.zero,
  }) {
    final normalized = _normalizeAnchorUnit(unit);
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final center = rect.center;
    return Offset(
      center.dx + normalized.dx * halfW + spacingOffset.dx,
      center.dy + normalized.dy * halfH + spacingOffset.dy,
    );
  }

  Offset _normalizeAnchorUnit(Offset unit) {
    if (unit.distanceSquared == 0) {
      return const Offset(1, 0);
    }

    final maxAbs = math.max(unit.dx.abs(), unit.dy.abs());
    if (maxAbs == 0) {
      return const Offset(1, 0);
    }
    return unit / maxAbs;
  }

  Offset _axisNormalForBorderPoint(Rect rect, Offset edgePoint) {
    final vector = edgePoint - rect.center;
    if (vector.distanceSquared == 0) {
      return const Offset(1, 0);
    }
    if (vector.dx.abs() >= vector.dy.abs()) {
      return Offset(vector.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, vector.dy >= 0 ? 1 : -1);
  }

  Offset _unitOrFallback(Offset value, Offset fallback) {
    final length = value.distance;
    if (length == 0) {
      return fallback;
    }
    return value / length;
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    required ConnectorType connectorType,
    List<Offset> viaPoints = const [],
    Offset? startTangent,
    Offset? endTangent,
    bool isSelected = false,
  }) {
    final path = _connectorPath(
      from,
      to,
      connectorType: connectorType,
      viaPoints: viaPoints,
      startTangent: startTangent,
      endTangent: endTangent,
    );

    // Déterminer la couleur du tube (bleu par défaut, orange si sélectionné)
    final tubeColor = isSelected ? colorLinkSelected : colorLinkDefault;

    // Dessiner le tube néon avec effet de glow
    _drawNeonTube(canvas, path, tubeColor);

    // Dessiner les particules qui circulent dans le tube
    _drawFlowParticles(canvas, path, tubeColor);

    final endAngle = _pathEndAngle(path);
    if (endAngle == null) {
      return;
    }

    _drawArrowHead(canvas, to, endAngle, paint);
  }

  void _drawNeonTube(
    Canvas canvas,
    Path path, [
    Color tubeColor = colorLinkDefault,
  ]) {
    // Tube avec couleur dynamique (bleu par défaut, orange si sélectionné)
    final tubePaint = Paint()
      ..color = tubeColor.withValues(alpha: 0.4)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, tubePaint);
  }

  Path _connectorPath(
    Offset from,
    Offset to, {
    required ConnectorType connectorType,
    List<Offset> viaPoints = const [],
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final allPoints = <Offset>[from, ...viaPoints, to];
    if (allPoints.length < 2) {
      return Path();
    }

    if (connectorType == ConnectorType.bezier) {
      return _buildSmoothBezierPath(
        allPoints,
        startTangent: startTangent,
        endTangent: endTangent,
      );
    }

    return _buildOrthogonalPath(
      allPoints,
      startTangent: startTangent,
      endTangent: endTangent,
    );
  }

  Path _buildOrthogonalPath(
    List<Offset> points, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final routed = <Offset>[...points];

    if (routed.length >= 2 && startTangent != null) {
      final start = routed.first;
      final next = routed[1];
      final dir = _unitOrFallback(startTangent, const Offset(1, 0));
      final lead = (next - start).distance;
      final leadLen = lead <= 0 ? 24.0 : (lead * 0.45).clamp(12.0, 52.0);
      routed.insert(1, start + dir * leadLen);
    }

    if (routed.length >= 2 && endTangent != null) {
      final end = routed.last;
      final prev = routed[routed.length - 2];
      final dir = _unitOrFallback(endTangent, const Offset(-1, 0));
      final lead = (end - prev).distance;
      final leadLen = lead <= 0 ? 24.0 : (lead * 0.45).clamp(12.0, 52.0);
      routed.insert(routed.length - 1, end - dir * leadLen);
    }

    const eps = 0.001;
    final manhattan = <Offset>[routed.first];

    for (var i = 1; i < routed.length; i++) {
      final from = manhattan.last;
      final to = routed[i];
      final dx = to.dx - from.dx;
      final dy = to.dy - from.dy;

      if (dx.abs() <= eps || dy.abs() <= eps) {
        if ((to - from).distanceSquared > eps * eps) {
          manhattan.add(to);
        }
        continue;
      }

      final horizontalFirst = dx.abs() >= dy.abs();
      final elbow = horizontalFirst
          ? Offset(to.dx, from.dy)
          : Offset(from.dx, to.dy);

      if ((elbow - from).distanceSquared > eps * eps) {
        manhattan.add(elbow);
      }
      if ((to - manhattan.last).distanceSquared > eps * eps) {
        manhattan.add(to);
      }
    }

    if (manhattan.length <= 1) {
      return Path()..moveTo(routed.first.dx, routed.first.dy);
    }

    final path = Path()..moveTo(manhattan.first.dx, manhattan.first.dy);
    if (manhattan.length == 2) {
      path.lineTo(manhattan.last.dx, manhattan.last.dy);
      return path;
    }

    const radius = 18.0;
    for (var i = 1; i < manhattan.length - 1; i++) {
      _lineOrArcTo(
        path,
        manhattan[i - 1],
        manhattan[i],
        manhattan[i + 1],
        radius,
      );
    }

    path.lineTo(manhattan.last.dx, manhattan.last.dy);
    return path;
  }

  Path _buildSmoothBezierPath(
    List<Offset> points, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      final controlPoints = _bezierControlPoints(
        points[0],
        points[1],
        startTangent: startTangent,
        endTangent: endTangent,
      );
      final c1 = controlPoints.$1;
      final c2 = controlPoints.$2;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, points[1].dx, points[1].dy);
      return path;
    }

    const tension = 1.0;
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      var c1 = p1 + ((p2 - p0) * (tension / 6));
      var c2 = p2 - ((p3 - p1) * (tension / 6));

      final segmentLength = (p2 - p1).distance;
      final handleLength = math.max(24.0, segmentLength * 0.45);

      if (i == 0 && startTangent != null) {
        final dir = _unitOrFallback(startTangent, const Offset(1, 0));
        c1 = p1 + dir * handleLength;
      }
      if (i == points.length - 2 && endTangent != null) {
        final dir = _unitOrFallback(endTangent, const Offset(-1, 0));
        c2 = p2 - dir * handleLength;
      }

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  void _drawArrowHead(Canvas canvas, Offset to, double angle, Paint paint) {
    const arrowSize = 15.0;
    final arrowPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.fill;

    final p1 = to + Offset(-arrowSize * 0.866, arrowSize * 0.5).rotate(angle);
    final p2 = to + Offset(-arrowSize * 0.866, -arrowSize * 0.5).rotate(angle);

    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      arrowPaint,
    );
  }

  double? _pathEndAngle(Path path) {
    final iterator = path.computeMetrics().iterator;
    if (!iterator.moveNext()) {
      return null;
    }

    var metric = iterator.current;
    while (iterator.moveNext()) {
      metric = iterator.current;
    }
    if (metric.length <= 0) {
      return null;
    }

    final endTangent = metric.getTangentForOffset(metric.length);
    if (endTangent == null) {
      return null;
    }

    final sampleOffset = math.max(0.0, metric.length - 8.0);
    final sampleTangent = metric.getTangentForOffset(sampleOffset);
    if (sampleTangent == null) {
      return endTangent.angle;
    }

    final direction = endTangent.position - sampleTangent.position;
    if (direction.distanceSquared == 0) {
      return endTangent.angle;
    }

    return direction.direction;
  }

  void _drawFlowParticles(Canvas canvas, Path path, Color color) {
    final metrics = path.computeMetrics();
    final iterator = metrics.iterator;
    if (!iterator.moveNext()) {
      return;
    }

    const spacing = 34.0;
    const speedPx = 170.0;
    final travel = (flowAnimation?.value ?? 0.0) * speedPx;

    do {
      final metric = iterator.current;
      final length = metric.length;
      if (length <= 0) {
        continue;
      }

      final phase = travel % spacing;
      for (double d = phase; d < length + spacing; d += spacing) {
        final offsetOnPath = d % length;
        final tangent = metric.getTangentForOffset(offsetOnPath);
        if (tangent == null) {
          continue;
        }
        final progress = offsetOnPath / length;
        final radius = 1.8 + (0.8 * progress);

        // Effet de lueur néon - couches multiples pour l'effet glow
        final neonColor = color.withValues(alpha: 0.15);

        // Première couche de glow (la plus large)
        final glow1Paint = Paint()
          ..color = neonColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius * 1.8, glow1Paint);

        // Deuxième couche de glow (moyenne)
        final glow2Paint = Paint()
          ..color = neonColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius * 1.3, glow2Paint);

        // Couche principale avec lueur plus intense
        final flowPaint = Paint()
          ..color = color.withValues(alpha: 0.65 + (0.35 * progress))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius, flowPaint);

        // Cœur brillant central
        final corePaint = Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius * 0.4, corePaint);
      }
    } while (iterator.moveNext());
  }

  void _drawLinkLabel(
    Canvas canvas,
    BlockLink link,
    Offset from,
    Offset to,
    List<Offset> viaPoints, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final label = link.name.trim();
    if (label.isEmpty) {
      return;
    }

    final path = _connectorPath(
      from,
      to,
      connectorType: link.connectorType,
      viaPoints: viaPoints,
      startTangent: startTangent,
      endTangent: endTangent,
    );

    final iterator = path.computeMetrics().iterator;
    if (!iterator.moveNext()) {
      return;
    }

    final metric = iterator.current;
    if (metric.length <= 0) {
      return;
    }

    final midpoint = metric.getTangentForOffset(metric.length / 2);
    if (midpoint == null) {
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);

    final padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final rect = Rect.fromCenter(
      center: midpoint.position + const Offset(0, -18),
      width: painter.width + padding.horizontal,
      height: painter.height + padding.vertical,
    );

    final background = Paint()
      ..color = const Color.fromARGB(190, 18, 18, 24)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      background,
    );

    painter.paint(
      canvas,
      rect.topLeft + Offset(padding.left / 2, padding.top / 2),
    );
  }

  void _lineOrArcTo(
    Path path,
    Offset prev,
    Offset corner,
    Offset next,
    double radius,
  ) {
    final vIn = corner - prev;
    final vOut = next - corner;
    if (vIn.distanceSquared == 0 || vOut.distanceSquared == 0) {
      path.lineTo(corner.dx, corner.dy);
      return;
    }

    final inDir = vIn / vIn.distance;
    final outDir = vOut / vOut.distance;
    final r = math.min(radius, math.min(vIn.distance, vOut.distance) / 2);

    final arcStart = corner - inDir * r;
    final arcEnd = corner + outDir * r;

    path.lineTo(arcStart.dx, arcStart.dy);
    path.quadraticBezierTo(corner.dx, corner.dy, arcEnd.dx, arcEnd.dy);
  }

  (Offset, Offset) _bezierControlPoints(
    Offset from,
    Offset to, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final delta = to - from;
    final distance = delta.distance;
    final curvature = math.max(40.0, distance * 0.35);

    if (startTangent != null || endTangent != null) {
      final startDir = _unitOrFallback(
        startTangent ?? delta,
        const Offset(1, 0),
      );
      final endDir = _unitOrFallback(endTangent ?? delta, const Offset(1, 0));
      return (from + startDir * curvature, to - endDir * curvature);
    }

    if (delta.dx.abs() >= delta.dy.abs()) {
      final dir = delta.dx >= 0 ? 1.0 : -1.0;
      return (
        from + Offset(curvature * dir, 0),
        to - Offset(curvature * dir, 0),
      );
    }

    final dir = delta.dy >= 0 ? 1.0 : -1.0;
    return (from + Offset(0, curvature * dir), to - Offset(0, curvature * dir));
  }

  double _anchorOrderKeyForLinkSide(
    BlockLink link,
    String blockId,
    Offset anchorUnit,
    int linkIndex,
  ) {
    final side = _anchorSideUnit(anchorUnit);
    if (link.fromBlockId == blockId && link.sourceAnchorUnit != null) {
      if (_anchorSideUnit(link.sourceAnchorUnit!) == side) {
        return link.sourceAnchorOrderKey ?? linkIndex.toDouble();
      }
    }
    if (link.toBlockId == blockId && link.targetAnchorUnit != null) {
      if (_anchorSideUnit(link.targetAnchorUnit!) == side) {
        return link.targetAnchorOrderKey ?? linkIndex.toDouble();
      }
    }
    return linkIndex.toDouble();
  }

  Offset _anchorSideUnit(Offset unit) {
    final normalized = _normalizeAnchorUnit(unit);
    if (normalized.dx.abs() >= normalized.dy.abs()) {
      return Offset(normalized.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, normalized.dy >= 0 ? 1 : -1);
  }

  Offset _getAnchorSpacingOffset(
    BlockLink currentLink,
    String blockId,
    Offset anchorUnit,
  ) {
    final side = _anchorSideUnit(anchorUnit);
    final spacingDistance = 15.0; // Distance between anchors

    final currentLinkIndex = links.indexOf(currentLink);
    if (currentLinkIndex == -1) {
      return Offset.zero;
    }

    final grouped = <(int, double)>[];
    for (int i = 0; i < links.length; i++) {
      final link = links[i];
      final isSameSide =
          (link.fromBlockId == blockId &&
              link.sourceAnchorUnit != null &&
              _anchorSideUnit(link.sourceAnchorUnit!) == side) ||
          (link.toBlockId == blockId &&
              link.targetAnchorUnit != null &&
              _anchorSideUnit(link.targetAnchorUnit!) == side);
      if (!isSameSide) {
        continue;
      }
      grouped.add((i, _anchorOrderKeyForLinkSide(link, blockId, side, i)));
    }

    if (grouped.isEmpty) {
      return Offset.zero;
    }

    grouped.sort((a, b) {
      final byKey = a.$2.compareTo(b.$2);
      if (byKey != 0) {
        return byKey;
      }
      return a.$1.compareTo(b.$1);
    });

    final anchorIndex = grouped.indexWhere(
      (entry) => entry.$1 == currentLinkIndex,
    );
    if (anchorIndex == -1) {
      return Offset.zero;
    }

    final centerOffset =
        (anchorIndex - (grouped.length - 1) / 2) * spacingDistance;

    // Apply spacing parallel to the anchor side
    if (side.dx != 0) {
      // Horizontal side (left/right) - space vertically
      return Offset(0, centerOffset);
    } else if (side.dy != 0) {
      // Vertical side (top/bottom) - space horizontally
      return Offset(centerOffset, 0);
    }
    return Offset.zero;
  }

  @override
  bool shouldRepaint(MiroCanvasPainter oldDelegate) => true;
}
