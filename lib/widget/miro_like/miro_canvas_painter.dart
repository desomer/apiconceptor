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

class _LabelLayout {
  final bool isSelected;
  final TextPainter textPainter;
  final TextPainter? iconPainter;
  final EdgeInsets padding;
  final double iconSpacing;
  final double contentHeight;
  final Offset preferredCenter;
  Rect rect;

  _LabelLayout({
    required this.isSelected,
    required this.textPainter,
    required this.iconPainter,
    required this.padding,
    required this.iconSpacing,
    required this.contentHeight,
    required this.preferredCenter,
    required this.rect,
  });
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
    _drawDottedGrid(canvas, size);

    // Dessiner les liens
    final linkPaint = Paint()
      ..color = colorLinkDefault
      ..strokeWidth = 3
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

      final linkBaseColor = kLinkColorMap[link.colorKey] ?? colorLinkDefault;

      _drawArrow(
        canvas,
        fromEdge,
        toEdge,
        linkPaint,
        tubeColor: linkBaseColor,
        link: link,
        connectorType: link.connectorType,
        viaPoints: viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
        isSelected: selectedLink == link,
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

    final labelLayouts = <_LabelLayout>[];
    for (final entry in labelEntries) {
      final layout = _buildLinkLabelLayout(
        entry.link,
        entry.fromEdge,
        entry.toEdge,
        entry.viaCanvas,
        startTangent: entry.startTangent,
        endTangent: entry.endTangent,
        isSelected: entry.isSelected,
      );
      if (layout != null) {
        labelLayouts.add(layout);
      }
    }

    _resolveLabelOverlaps(labelLayouts);
    for (final layout in labelLayouts) {
      _paintLinkLabelLayout(canvas, layout);
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
        tubeColor: colorLinkCreation,
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

  void _drawDottedGrid(Canvas canvas, Size size) {
    const gridSpacingModel = 24.0;
    final gridSpacingCanvas = gridSpacingModel * zoomLevel;
    if (gridSpacingCanvas < 8.0) {
      return;
    }

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final startX = canvasOffset.dx % gridSpacingCanvas;
    final startY = canvasOffset.dy % gridSpacingCanvas;

    for (double x = startX; x < size.width; x += gridSpacingCanvas) {
      for (double y = startY; y < size.height; y += gridSpacingCanvas) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
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
    required Color tubeColor,
    BlockLink? link,
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

    // Use per-link color, but keep selection highlight color for clarity.
    final effectiveTubeColor = isSelected ? colorLinkSelected : tubeColor;

    // Dessiner le tube néon avec effet de glow
    _drawNeonTube(canvas, path, effectiveTubeColor);

    // Dessiner les particules qui circulent dans le tube
    _drawFlowParticles(canvas, path, effectiveTubeColor, link: link);

    final endAngle = _pathEndAngle(path);
    if (endAngle == null) {
      return;
    }

    _drawArrowHead(canvas, to, endAngle, paint, effectiveTubeColor);
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

  void _drawArrowHead(
    Canvas canvas,
    Offset to,
    double angle,
    Paint paint,
    Color color,
  ) {
    const arrowSize = 15.0;
    final arrowPaint = Paint()
      ..color = color
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

  void _drawFlowParticles(
    Canvas canvas,
    Path path,
    Color color, {
    BlockLink? link,
  }) {
    final metrics = path.computeMetrics();
    final iterator = metrics.iterator;
    if (!iterator.moveNext()) {
      return;
    }

    final density = (link?.particleDensity ?? 1.0).clamp(0.2, 3.0);
    final speed = (link?.particleSpeed ?? 1.0).clamp(0.2, 3.0);
    final spacing = (34.0 / density).clamp(12.0, 90.0);
    final speedPx = 170.0 * speed;
    // Use a continuous time source so particle motion does not jump when
    // the repeating animation cycles back from 1.0 to 0.0.
    final elapsedSeconds =
        DateTime.now().microsecondsSinceEpoch / Duration.microsecondsPerSecond;
    final travel = elapsedSeconds * speedPx;

    do {
      final metric = iterator.current;
      final length = metric.length;
      if (length <= 0) {
        continue;
      }

      final particleCount = math.max(1, (length / spacing).floor());
      final effectiveSpacing = length / particleCount;
      final phase = travel % effectiveSpacing;
      for (int i = 0; i < particleCount; i++) {
        final d = i * effectiveSpacing + phase;
        final offsetOnPath = d % length;
        final tangent = metric.getTangentForOffset(offsetOnPath);
        if (tangent == null) {
          continue;
        }
        final progress = offsetOnPath / length;
        final radius = 2.0 + (0.25 * progress);

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
          ..color = color.withValues(alpha: 0.75 + (0.20 * progress))
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

  _LabelLayout? _buildLinkLabelLayout(
    BlockLink link,
    Offset from,
    Offset to,
    List<Offset> viaPoints, {
    Offset? startTangent,
    Offset? endTangent,
    bool isSelected = false,
  }) {
    final label = link.name.trim();
    if (label.isEmpty) {
      return null;
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
      return null;
    }

    final metric = iterator.current;
    if (metric.length <= 0) {
      return null;
    }

    final offsetOnPath = (metric.length * link.labelPosition).clamp(
      0.0,
      metric.length,
    );
    final midpoint = metric.getTangentForOffset(offsetOnPath);
    if (midpoint == null) {
      return null;
    }

    final normal = Offset(-math.sin(midpoint.angle), math.cos(midpoint.angle));
    final labelCenter =
        midpoint.position + normal * 18 + link.labelOffset * zoomLevel;

    final iconData = kLinkLabelIconMap[link.labelIconKey];

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isSelected ? colorLinkSelected : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);

    TextPainter? iconPainter;
    if (iconData != null) {
      iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? colorLinkSelected : Colors.white,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final iconSpacing = iconPainter == null ? 0.0 : 6.0;
    final iconWidth = iconPainter?.width ?? 0.0;
    final iconHeight = iconPainter?.height ?? 0.0;
    final contentWidth = iconWidth + iconSpacing + painter.width;
    final contentHeight = math.max(painter.height, iconHeight);
    final rect = Rect.fromCenter(
      center: labelCenter,
      width: contentWidth + padding.horizontal,
      height: contentHeight + padding.vertical,
    );

    return _LabelLayout(
      isSelected: isSelected,
      textPainter: painter,
      iconPainter: iconPainter,
      padding: padding,
      iconSpacing: iconSpacing,
      contentHeight: contentHeight,
      preferredCenter: labelCenter,
      rect: rect,
    );
  }

  void _paintLinkLabelLayout(Canvas canvas, _LabelLayout layout) {
    final rect = layout.rect;

    final background = Paint()
      ..color = layout.isSelected
          ? colorLinkSelected.withValues(alpha: 0.16)
          : const Color.fromARGB(190, 18, 18, 24)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      background,
    );

    var paintX = rect.left + layout.padding.left;
    final contentTop = rect.top + layout.padding.top;
    if (layout.iconPainter != null) {
      layout.iconPainter!.paint(
        canvas,
        Offset(
          paintX,
          contentTop + (layout.contentHeight - layout.iconPainter!.height) / 2,
        ),
      );
      paintX += layout.iconPainter!.width + layout.iconSpacing;
    }

    layout.textPainter.paint(
      canvas,
      Offset(
        paintX,
        contentTop + (layout.contentHeight - layout.textPainter.height) / 2,
      ),
    );
  }

  void _resolveLabelOverlaps(List<_LabelLayout> layouts) {
    if (layouts.length < 2) {
      return;
    }

    const spacing = 6.0;
    const maxIterations = 10;
    const maxOffsetFromPreferred = 72.0;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      var changed = false;

      for (int i = 0; i < layouts.length - 1; i++) {
        for (int j = i + 1; j < layouts.length; j++) {
          final a = layouts[i];
          final b = layouts[j];

          final dx = b.rect.center.dx - a.rect.center.dx;
          final dy = b.rect.center.dy - a.rect.center.dy;
          final overlapX =
              (a.rect.width + b.rect.width) / 2 + spacing - dx.abs();
          final overlapY =
              (a.rect.height + b.rect.height) / 2 + spacing - dy.abs();

          if (overlapX <= 0 || overlapY <= 0) {
            continue;
          }

          changed = true;
          if (overlapX < overlapY) {
            final sign = dx >= 0 ? 1.0 : -1.0;
            final shift = (overlapX / 2) + 0.5;
            a.rect = a.rect.shift(Offset(-sign * shift, 0));
            b.rect = b.rect.shift(Offset(sign * shift, 0));
          } else {
            final sign = dy >= 0 ? 1.0 : -1.0;
            final shift = (overlapY / 2) + 0.5;
            a.rect = a.rect.shift(Offset(0, -sign * shift));
            b.rect = b.rect.shift(Offset(0, sign * shift));
          }

          a.rect = _clampRectAroundPreferred(
            a.rect,
            a.preferredCenter,
            maxOffsetFromPreferred,
          );
          b.rect = _clampRectAroundPreferred(
            b.rect,
            b.preferredCenter,
            maxOffsetFromPreferred,
          );
        }
      }

      if (!changed) {
        break;
      }
    }
  }

  Rect _clampRectAroundPreferred(
    Rect rect,
    Offset preferredCenter,
    double maxDistance,
  ) {
    var dx = rect.center.dx - preferredCenter.dx;
    var dy = rect.center.dy - preferredCenter.dy;
    final distance = math.sqrt((dx * dx) + (dy * dy));
    if (distance <= maxDistance || distance == 0) {
      return rect;
    }

    final ratio = maxDistance / distance;
    dx *= ratio;
    dy *= ratio;
    final clampedCenter = Offset(
      preferredCenter.dx + dx,
      preferredCenter.dy + dy,
    );
    return Rect.fromCenter(
      center: clampedCenter,
      width: rect.width,
      height: rect.height,
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
    final spacingDistance = anchorSpacingDistance * zoomLevel;

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

    if (side.dx != 0) {
      return Offset(0, centerOffset);
    } else if (side.dy != 0) {
      return Offset(centerOffset, 0);
    }
    return Offset.zero;
  }

  @override
  bool shouldRepaint(MiroCanvasPainter oldDelegate) => true;
}
