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
  bool dashed = false,
}) {
  _drawNeonTube(canvas, path, color, strokeWidth, dashed: dashed);
  _drawFlowParticles(canvas, path, color, link: link);

  final endAngle = _pathEndAngle(path);
  if (endAngle != null) {
    final arrowType = (link?.sequenceArrowType ?? '').trim();
    final hasSequenceArrowType = arrowType.isNotEmpty;
    final isNoHeadArrow = hasSequenceArrowType && arrowType == '->';
    final isCrossArrow =
        hasSequenceArrowType &&
        (arrowType.endsWith('x') || arrowType.endsWith('X'));
    final isOpenArrow = hasSequenceArrowType && arrowType.endsWith(')');

    if (isNoHeadArrow) {
      // Mermaid '->' ends without arrowhead and starts with a circular marker.
      final startPoint = _pathStartPoint(path);
      if (startPoint != null) {
        _drawStartCircleMarker(
          canvas,
          startPoint,
          color: color,
          strokeWidth: strokeWidth,
          markerSize: _arrowHeadSize(zoomLevel) * 2,
        );
      }
    } else if (isCrossArrow) {
      _drawCrossMarker(
        canvas,
        arrowTip,
        endAngle,
        color: color,
        strokeWidth: strokeWidth,
        markerSize: _arrowHeadSize(zoomLevel),
      );
    } else if (isOpenArrow) {
      _drawOpenArrowHead(
        canvas,
        arrowTip,
        endAngle,
        color: color,
        strokeWidth: strokeWidth,
        arrowHeadSize: _arrowHeadSize(zoomLevel),
      );
    } else {
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
}

void _drawStartCircleMarker(
  Canvas canvas,
  Offset center, {
  required Color color,
  required double strokeWidth,
  required double markerSize,
}) {
  final radius = (markerSize * 0.22).clamp(2.6, 8.0);

  final fillPaint = Paint()
    ..color = color.withValues(alpha: 0.95)
    ..style = PaintingStyle.fill;
  final strokePaint = Paint()
    ..color = color.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = (strokeWidth * 0.55).clamp(0.7, 2.0);

  canvas.drawCircle(center, radius, fillPaint);
  canvas.drawCircle(center, radius, strokePaint);
}

double _arrowHeadSize(double zoomLevel) {
  return (15.0 * zoomLevel).clamp(4.0, 34.0);
}

void _drawNeonTube(
  Canvas canvas,
  Path path,
  Color tubeColor,
  double strokeWidth, {
  bool dashed = false,
}) {
  final tubePaint = Paint()
    ..color = tubeColor.withValues(alpha: 0.4)
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  if (!dashed) {
    canvas.drawPath(path, tubePaint);
  } else {
    final dashLength = (14.0 * (strokeWidth / 3.0)).clamp(8.0, 22.0);
    final gapLength = (16.0 * (strokeWidth / 3.0)).clamp(8.0, 26.0);
    final glowPaint = Paint()
      ..color = tubeColor.withValues(alpha: 0.58)
      ..strokeWidth = strokeWidth * 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    // final corePaint = Paint()
    //   ..color = tubeColor.withValues(alpha: 0.95)
    //   ..strokeWidth = (strokeWidth * 0.3).clamp(0.3, strokeWidth)
    //   ..strokeCap = StrokeCap.round
    //   ..strokeJoin = StrokeJoin.round
    //   ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        final segment = metric.extractPath(distance, next);
        canvas.drawPath(segment, glowPaint);
        //canvas.drawPath(segment, corePaint);
        distance = next + gapLength;
      }
    }
  }
}

void _drawOpenArrowHead(
  Canvas canvas,
  Offset to,
  double angle, {
  required Color color,
  required double strokeWidth,
  required double arrowHeadSize,
}) {
  final arrowPaint = Paint()
    ..color = color
    ..strokeWidth = (strokeWidth * 0.85).clamp(0.8, 5.0)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final p1 =
      to + Offset(-arrowHeadSize * 0.866, arrowHeadSize * 0.5).rotate(angle);
  final p2 =
      to + Offset(-arrowHeadSize * 0.866, -arrowHeadSize * 0.5).rotate(angle);

  canvas.drawLine(to, p1, arrowPaint);
  canvas.drawLine(to, p2, arrowPaint);
}

void _drawCrossMarker(
  Canvas canvas,
  Offset to,
  double angle, {
  required Color color,
  required double strokeWidth,
  required double markerSize,
}) {
  final markerPaint = Paint()
    ..color = color
    ..strokeWidth = (strokeWidth * 0.95).clamp(1.0, 5.5)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final center = to + Offset(-markerSize * 0.45, 0).rotate(angle);
  final half = markerSize * 0.30;

  final a = center + Offset(-half, -half).rotate(angle);
  final b = center + Offset(half, half).rotate(angle);
  final c = center + Offset(-half, half).rotate(angle);
  final d = center + Offset(half, -half).rotate(angle);

  canvas.drawLine(a, b, markerPaint);
  canvas.drawLine(c, d, markerPaint);
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

Offset? _pathStartPoint(Path path) {
  final iterator = path.computeMetrics().iterator;
  if (!iterator.moveNext()) {
    return null;
  }

  final metric = iterator.current;
  if (metric.length <= 0) {
    return null;
  }

  final startTangent = metric.getTangentForOffset(0.0);
  return startTangent?.position;
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
