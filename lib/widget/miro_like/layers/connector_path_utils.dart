import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/link_model.dart';

/// Shared path-building utilities used by both the canvas painter and the
/// widget state (for hit-testing label positions).
///
/// All functions work in canvas/screen coordinates.

Offset unitOrFallback(Offset value, Offset fallback) {
  final length = value.distance;
  if (length == 0) return fallback;
  return value / length;
}

/// Returns the outward axis-aligned normal for a point on a rect's border.
Offset axisNormalForBorderPoint(Rect rect, Offset edgePoint) {
  final vector = edgePoint - rect.center;
  if (vector.distanceSquared == 0) return const Offset(1, 0);
  if (vector.dx.abs() >= vector.dy.abs()) {
    return Offset(vector.dx >= 0 ? 1 : -1, 0);
  }
  return Offset(0, vector.dy >= 0 ? 1 : -1);
}

/// Builds the complete connector path between [from] and [to] using the same
/// routing logic as the canvas painter.
Path buildConnectorPath(
  Offset from,
  Offset to, {
  required ConnectorType connectorType,
  List<Offset> viaPoints = const [],
  Offset? startTangent,
  Offset? endTangent,
}) {
  final allPoints = <Offset>[from, ...viaPoints, to];
  if (allPoints.length < 2) return Path();

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
    final dir = unitOrFallback(startTangent, const Offset(1, 0));
    final lead = (next - start).distance;
    final leadLen = lead <= 0 ? 24.0 : (lead * 0.45).clamp(12.0, 52.0);
    routed.insert(1, start + dir * leadLen);
  }

  if (routed.length >= 2 && endTangent != null) {
    final end = routed.last;
    final prev = routed[routed.length - 2];
    final dir = unitOrFallback(endTangent, const Offset(-1, 0));
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
      if ((to - from).distanceSquared > eps * eps) manhattan.add(to);
      continue;
    }

    final horizontalFirst = dx.abs() >= dy.abs();
    final elbow = horizontalFirst
        ? Offset(to.dx, from.dy)
        : Offset(from.dx, to.dy);

    if ((elbow - from).distanceSquared > eps * eps) manhattan.add(elbow);
    if ((to - manhattan.last).distanceSquared > eps * eps) manhattan.add(to);
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

Path _buildSmoothBezierPath(
  List<Offset> points, {
  Offset? startTangent,
  Offset? endTangent,
}) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);

  if (points.length == 2) {
    final cp = _bezierControlPoints(
      points[0],
      points[1],
      startTangent: startTangent,
      endTangent: endTangent,
    );
    path.cubicTo(
      cp.$1.dx,
      cp.$1.dy,
      cp.$2.dx,
      cp.$2.dy,
      points[1].dx,
      points[1].dy,
    );
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
      final dir = unitOrFallback(startTangent, const Offset(1, 0));
      c1 = p1 + dir * handleLength;
    }
    if (i == points.length - 2 && endTangent != null) {
      final dir = unitOrFallback(endTangent, const Offset(-1, 0));
      c2 = p2 - dir * handleLength;
    }

    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }

  return path;
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
    final startDir = unitOrFallback(startTangent ?? delta, const Offset(1, 0));
    final endDir = unitOrFallback(endTangent ?? delta, const Offset(1, 0));
    return (from + startDir * curvature, to - endDir * curvature);
  }

  if (delta.dx.abs() >= delta.dy.abs()) {
    final dir = delta.dx >= 0 ? 1.0 : -1.0;
    return (from + Offset(curvature * dir, 0), to - Offset(curvature * dir, 0));
  }

  final dir = delta.dy >= 0 ? 1.0 : -1.0;
  return (from + Offset(0, curvature * dir), to - Offset(0, curvature * dir));
}
