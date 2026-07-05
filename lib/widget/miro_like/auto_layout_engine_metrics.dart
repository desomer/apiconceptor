part of 'auto_layout_engine.dart';

class AutoLayoutDebugMetrics {
  final int crossings;
  final int edgeOverNodeHits;
  final int nodeOverlapPairs;
  final int subgraphViolations;
  final int hardViolation;
  final double totalEdgeLength;
  final double alignmentScore;
  final double objective;

  const AutoLayoutDebugMetrics({
    required this.crossings,
    required this.edgeOverNodeHits,
    required this.nodeOverlapPairs,
    required this.subgraphViolations,
    required this.hardViolation,
    required this.totalEdgeLength,
    required this.alignmentScore,
    required this.objective,
  });

  Map<String, Object> toJson() {
    return {
      'crossings': crossings,
      'edgeOverNodeHits': edgeOverNodeHits,
      'nodeOverlapPairs': nodeOverlapPairs,
      'subgraphViolations': subgraphViolations,
      'hardViolation': hardViolation,
      'totalEdgeLength': totalEdgeLength,
      'alignmentScore': alignmentScore,
      'objective': objective,
    };
  }
}

AutoLayoutDebugMetrics _collectDebugMetricsImpl({
  required List<String> nodeOrder,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<(String, String)> allEdges,
  required List<List<String>> subgraphNodeGroups,
  required double minGap,
}) {
  // Centralized metric aggregation used by diagnostics and tests.
  final metrics = _collectMetricsImpl(
    nodeOrder: nodeOrder,
    positions: positions,
    sizeByNode: sizeByNode,
    allEdges: allEdges,
    subgraphNodeGroups: subgraphNodeGroups,
    minGap: minGap,
  );

  return AutoLayoutDebugMetrics(
    crossings: metrics.crossings,
    edgeOverNodeHits: metrics.edgeOverNodeHits,
    nodeOverlapPairs: metrics.nodeOverlapPairs,
    subgraphViolations: metrics.subgraphViolations,
    hardViolation: metrics.hardViolation,
    totalEdgeLength: metrics.totalEdgeLength,
    alignmentScore: metrics.alignmentScore,
    objective: metrics.objective,
  );
}

_LayoutMetrics _collectMetricsImpl({
  required List<String> nodeOrder,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<(String, String)> allEdges,
  required List<List<String>> subgraphNodeGroups,
  required double minGap,
}) {
  final crossings = _countEdgeCrossings(
    positions: positions,
    sizeByNode: sizeByNode,
    allEdges: allEdges,
  );
  final edgeOverNodeHits = _countEdgeOverNodeHits(
    nodeOrder: nodeOrder,
    positions: positions,
    sizeByNode: sizeByNode,
    allEdges: allEdges,
    minGap: minGap,
  );
  final nodeOverlapPairs = _countNodeOverlapPairs(
    nodeOrder: nodeOrder,
    positions: positions,
    sizeByNode: sizeByNode,
    minGap: minGap,
  );
  final subgraphViolations = _countSubgraphMembershipViolations(
    nodeOrder: nodeOrder,
    positions: positions,
    sizeByNode: sizeByNode,
    subgraphNodeGroups: subgraphNodeGroups,
    minGap: minGap,
  );
  final hardViolation = nodeOverlapPairs + subgraphViolations;
  final totalEdgeLength = _totalEdgeLength(
    positions: positions,
    sizeByNode: sizeByNode,
    allEdges: allEdges,
  );
  final alignmentScore = _alignmentScore(positions);

  // Weighted objective kept consistent with historical debug expectations.
  final objective =
      crossings * 1000000.0 +
      edgeOverNodeHits * 220000.0 +
      nodeOverlapPairs * 120000.0 +
      subgraphViolations * 180000.0 +
      totalEdgeLength * 0.04 -
      alignmentScore * 2.0;

  return _LayoutMetrics(
    crossings: crossings,
    edgeOverNodeHits: edgeOverNodeHits,
    nodeOverlapPairs: nodeOverlapPairs,
    subgraphViolations: subgraphViolations,
    hardViolation: hardViolation,
    totalEdgeLength: totalEdgeLength,
    alignmentScore: alignmentScore,
    objective: objective,
  );
}

int _countEdgeCrossings({
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<(String, String)> allEdges,
}) {
  var crossings = 0;

  for (int i = 0; i < allEdges.length - 1; i++) {
    final e1 = allEdges[i];
    final shared = <String>{e1.$1, e1.$2};
    final s1 = _edgeAnchors(
      fromId: e1.$1,
      toId: e1.$2,
      positions: positions,
      sizeByNode: sizeByNode,
    );
    if (s1 == null) {
      continue;
    }

    for (int j = i + 1; j < allEdges.length; j++) {
      final e2 = allEdges[j];
      if (shared.contains(e2.$1) || shared.contains(e2.$2)) {
        continue;
      }

      final s2 = _edgeAnchors(
        fromId: e2.$1,
        toId: e2.$2,
        positions: positions,
        sizeByNode: sizeByNode,
      );
      if (s2 == null) {
        continue;
      }

      if (_segmentsIntersect(s1.$1, s1.$2, s2.$1, s2.$2)) {
        crossings++;
      }
    }
  }

  return crossings;
}

int _countEdgeOverNodeHits({
  required List<String> nodeOrder,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<(String, String)> allEdges,
  required double minGap,
}) {
  var hits = 0;

  for (final edge in allEdges) {
    final segment = _edgeAnchors(
      fromId: edge.$1,
      toId: edge.$2,
      positions: positions,
      sizeByNode: sizeByNode,
    );
    if (segment == null) {
      continue;
    }

    // Coarse segment sampling is enough for this lightweight evaluator.
    final samples = _sampleSegment(segment.$1, segment.$2, 8);

    for (final id in nodeOrder) {
      if (id == edge.$1 || id == edge.$2) {
        continue;
      }

      final rect = _nodeRect(id, positions, sizeByNode).inflate(minGap * 0.25);
      var intersects = false;

      for (final p in samples) {
        if (rect.contains(p)) {
          intersects = true;
          break;
        }
      }

      if (intersects) {
        hits++;
      }
    }
  }

  return hits;
}

List<Offset> _sampleSegment(Offset a, Offset b, int count) {
  if (count <= 2) {
    return <Offset>[a, b];
  }
  final points = <Offset>[];
  for (int i = 0; i <= count; i++) {
    final t = i / count;
    points.add(Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t));
  }
  return points;
}

int _countNodeOverlapPairs({
  required List<String> nodeOrder,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required double minGap,
}) {
  var overlaps = 0;

  for (int i = 0; i < nodeOrder.length - 1; i++) {
    final a = nodeOrder[i];
    final ra = _nodeRect(a, positions, sizeByNode).inflate(minGap / 2);

    for (int j = i + 1; j < nodeOrder.length; j++) {
      final b = nodeOrder[j];
      final rb = _nodeRect(b, positions, sizeByNode).inflate(minGap / 2);
      if (ra.overlaps(rb)) {
        overlaps++;
      }
    }
  }

  return overlaps;
}

int _countSubgraphMembershipViolations({
  required List<String> nodeOrder,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<List<String>> subgraphNodeGroups,
  required double minGap,
}) {
  if (subgraphNodeGroups.isEmpty) {
    return 0;
  }

  var violations = 0;

  for (final group in subgraphNodeGroups) {
    final members = group.where((id) => positions.containsKey(id)).toSet();
    if (members.length < 2) {
      continue;
    }

    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;

    for (final id in members) {
      final r = _nodeRect(id, positions, sizeByNode);
      left = math.min(left, r.left);
      top = math.min(top, r.top);
      right = math.max(right, r.right);
      bottom = math.max(bottom, r.bottom);
    }

    final bounds = Rect.fromLTRB(
      left,
      top,
      right,
      bottom,
    ).inflate(minGap * 0.5);

    for (final id in nodeOrder) {
      if (members.contains(id)) {
        continue;
      }
      if (_nodeRect(id, positions, sizeByNode).overlaps(bounds)) {
        violations++;
      }
    }
  }

  return violations;
}

double _totalEdgeLength({
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<(String, String)> allEdges,
}) {
  var total = 0.0;
  for (final edge in allEdges) {
    final segment = _edgeAnchors(
      fromId: edge.$1,
      toId: edge.$2,
      positions: positions,
      sizeByNode: sizeByNode,
    );
    if (segment != null) {
      total += (segment.$1 - segment.$2).distance;
    }
  }
  return total;
}

double _alignmentScore(Map<String, Offset> positions) {
  final ids = positions.keys.toList(growable: false);
  var score = 0.0;

  for (int i = 0; i < ids.length - 1; i++) {
    for (int j = i + 1; j < ids.length; j++) {
      final a = positions[ids[i]]!;
      final b = positions[ids[j]]!;
      if ((a.dx - b.dx).abs() <= 4) {
        score += 1.8;
      }
      if ((a.dy - b.dy).abs() <= 4) {
        score += 1.8;
      }
    }
  }

  return score;
}

(Offset, Offset)? _edgeAnchors({
  required String fromId,
  required String toId,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
}) {
  final fromPos = positions[fromId];
  final toPos = positions[toId];
  final fromSize = sizeByNode[fromId];
  final toSize = sizeByNode[toId];

  if (fromPos == null || toPos == null || fromSize == null || toSize == null) {
    return null;
  }

  final fromRect = Rect.fromLTWH(
    fromPos.dx,
    fromPos.dy,
    fromSize.width,
    fromSize.height,
  );
  final toRect = Rect.fromLTWH(toPos.dx, toPos.dy, toSize.width, toSize.height);

  // Keep link endpoints on node borders, oriented toward the opposite node.
  final fromAnchor = _pointOnRectBorderTowards(fromRect, toRect.center);
  final toAnchor = _pointOnRectBorderTowards(toRect, fromRect.center);

  return (fromAnchor, toAnchor);
}

Offset _pointOnRectBorderTowards(Rect rect, Offset target) {
  final center = rect.center;
  final vector = target - center;
  if (vector.distanceSquared == 0) {
    return center;
  }

  final halfW = rect.width / 2;
  final halfH = rect.height / 2;
  final scale = 1 / math.max(vector.dx.abs() / halfW, vector.dy.abs() / halfH);
  return center + vector * scale;
}

Rect _nodeRect(
  String id,
  Map<String, Offset> positions,
  Map<String, Size> sizeByNode,
) {
  final p = positions[id]!;
  final s = sizeByNode[id]!;
  return Rect.fromLTWH(p.dx, p.dy, s.width, s.height);
}

bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
  double cross(Offset u, Offset v) => u.dx * v.dy - u.dy * v.dx;

  bool onSegment(Offset p, Offset q, Offset r) {
    const eps = 1e-9;
    return q.dx <= math.max(p.dx, r.dx) + eps &&
        q.dx >= math.min(p.dx, r.dx) - eps &&
        q.dy <= math.max(p.dy, r.dy) + eps &&
        q.dy >= math.min(p.dy, r.dy) - eps;
  }

  int orientation(Offset p, Offset q, Offset r) {
    final v = cross(q - p, r - p);
    if (v.abs() <= 1e-9) {
      return 0;
    }
    return v > 0 ? 1 : 2;
  }

  final o1 = orientation(a, b, c);
  final o2 = orientation(a, b, d);
  final o3 = orientation(c, d, a);
  final o4 = orientation(c, d, b);

  if (o1 != o2 && o3 != o4) {
    return true;
  }
  if (o1 == 0 && onSegment(a, c, b)) {
    return true;
  }
  if (o2 == 0 && onSegment(a, d, b)) {
    return true;
  }
  if (o3 == 0 && onSegment(c, a, d)) {
    return true;
  }
  if (o4 == 0 && onSegment(c, b, d)) {
    return true;
  }

  return false;
}
