import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/models/link_model.dart';

extension _OffsetRotation on Offset {
  Offset rotate(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(dx * cos - dy * sin, dx * sin + dy * cos);
  }
}

void paintLinkConnectorVisuals({
  required Canvas canvas,
  required Path path,
  required Color color,
  required double strokeWidth,
  required double zoomLevel,
  required Offset arrowTip,
  BlockLink? link,
}) {
  _drawNeonTube(canvas, path, color, strokeWidth);
  _drawFlowParticles(canvas, path, color, link: link);

  final endAngle = _pathEndAngle(path);
  if (endAngle != null) {
    _drawArrowHead(
      canvas,
      arrowTip,
      endAngle,
      color: color,
      strokeWidth: strokeWidth,
      arrowHeadSize: _arrowHeadSize(zoomLevel),
    );
  }
}

double _arrowHeadSize(double zoomLevel) {
  return (15.0 * zoomLevel).clamp(4.0, 34.0);
}

void _drawNeonTube(
  Canvas canvas,
  Path path,
  Color tubeColor,
  double strokeWidth,
) {
  final tubePaint = Paint()
    ..color = tubeColor.withValues(alpha: 0.4)
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  canvas.drawPath(path, tubePaint);
}

void _drawArrowHead(
  Canvas canvas,
  Offset to,
  double angle, {
  required Color color,
  required double strokeWidth,
  required double arrowHeadSize,
}) {
  final arrowPaint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.fill;

  final p1 =
      to + Offset(-arrowHeadSize * 0.866, arrowHeadSize * 0.5).rotate(angle);
  final p2 =
      to + Offset(-arrowHeadSize * 0.866, -arrowHeadSize * 0.5).rotate(angle);

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

      final neonColor = color.withValues(alpha: 0.15);
      canvas.drawCircle(
        tangent.position,
        radius * 1.8,
        Paint()
          ..color = neonColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        tangent.position,
        radius * 1.3,
        Paint()
          ..color = neonColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        tangent.position,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.75 + (0.20 * progress))
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        tangent.position,
        radius * 0.4,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill,
      );
    }
  } while (iterator.moveNext());
}
