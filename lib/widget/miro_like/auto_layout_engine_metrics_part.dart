part of 'auto_layout_engine.dart';

_LayoutMetrics _collectMetrics({
  required List<String> nodeOrder,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<(String, String)> allEdges,
  required List<List<String>> subgraphNodeGroups,
  required double minGap,
  required String direction,
  required double bezierSamplingStepPx,
  required double subgraphTitleBandHeight,
  required double subgraphTitlePadding,
}) {
  final watch = Stopwatch()..start();
  final crossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
  final edgeOverNodeHits = _countEdgeOverNodeBezierHits(
    nodeOrder: nodeOrder,
    positions: positions,
    sizeByNode: sizeByNode,
    allEdges: allEdges,
    minGap: minGap,
    direction: direction,
    samplingStepPx: bezierSamplingStepPx,
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
    subgraphTitleBandHeight: subgraphTitleBandHeight,
    subgraphTitlePadding: subgraphTitlePadding,
  );
  final hardViolation = nodeOverlapPairs + subgraphViolations;
  final totalEdgeLength = _totalEdgeLength(positions, sizeByNode, allEdges);
  final alignmentScore = _alignmentScore(positions);

  final objective =
      crossings * 1000000.0 +
      edgeOverNodeHits * 220000.0 +
      nodeOverlapPairs * 120000.0 +
      subgraphViolations * 180000.0 +
      totalEdgeLength * 0.04 -
      alignmentScore * 2.0;

  if (watch.elapsedMilliseconds > 250) {
    AutoLayoutEngine._logAudit(
      'stage=metrics_profile elapsedMs=${watch.elapsedMilliseconds} nodes=${nodeOrder.length} edges=${allEdges.length} crossings=$crossings edgeOverNode=$edgeOverNodeHits',
    );
  }

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

int _countEdgeCrossings(
  Map<String, Offset> positions,
  Map<String, Size> sizeByNode,
  List<(String, String)> allEdges,
) {
  var crossings = 0;
  for (int i = 0; i < allEdges.length - 1; i++) {
    final e1 = allEdges[i];
    final shared = <String>{e1.$1, e1.$2};
    final p1 = _nodeCenter(positions[e1.$1]!, sizeByNode[e1.$1]!);
    final p2 = _nodeCenter(positions[e1.$2]!, sizeByNode[e1.$2]!);
    for (int j = i + 1; j < allEdges.length; j++) {
      final e2 = allEdges[j];
      if (shared.contains(e2.$1) || shared.contains(e2.$2)) {
        continue;
      }
      final p3 = _nodeCenter(positions[e2.$1]!, sizeByNode[e2.$1]!);
      final p4 = _nodeCenter(positions[e2.$2]!, sizeByNode[e2.$2]!);
      if (_segmentsIntersect(p1, p2, p3, p4)) {
        crossings++;
      }
    }
  }
  return crossings;
}

int _countEdgeOverNodeBezierHits({
  required List<String> nodeOrder,
  required Map<String, Offset> positions,
  required Map<String, Size> sizeByNode,
  required List<(String, String)> allEdges,
  required double minGap,
  required String direction,
  required double samplingStepPx,
}) {
  final watch = Stopwatch()..start();
  final flowHorizontal = direction == 'LR' || direction == 'RL';
  final rectByNode = <String, Rect>{
    for (final id in nodeOrder)
      id: Rect.fromLTWH(
        positions[id]!.dx,
        positions[id]!.dy,
        sizeByNode[id]!.width,
        sizeByNode[id]!.height,
      ),
  };

  var hits = 0;
  var edgeIndex = 0;

  for (final e in allEdges) {
    edgeIndex++;
    final a = e.$1;
    final b = e.$2;
    final p0 = _nodeCenter(positions[a]!, sizeByNode[a]!);
    final p3 = _nodeCenter(positions[b]!, sizeByNode[b]!);
    final mid = Offset((p0.dx + p3.dx) / 2, (p0.dy + p3.dy) / 2);
    final c1 = flowHorizontal ? Offset(mid.dx, p0.dy) : Offset(p0.dx, mid.dy);
    final c2 = flowHorizontal ? Offset(mid.dx, p3.dy) : Offset(p3.dx, mid.dy);

    // Hybrid approach: Direction-aware culling + Bbox analytics
    final curveBbox = Rect.fromLTRB(
      math.min(math.min(p0.dx, c1.dx), math.min(c2.dx, p3.dx)),
      math.min(math.min(p0.dy, c1.dy), math.min(c2.dy, p3.dy)),
      math.max(math.max(p0.dx, c1.dx), math.max(c2.dx, p3.dx)),
      math.max(math.max(p0.dy, c1.dy), math.max(c2.dy, p3.dy)),
    ).inflate(minGap * 0.5);

    // Direction-aware quick cull: for LR/RL, only check Y overlap; for TB/BT, only check X overlap
    for (final id in nodeOrder) {
      if (id == a || id == b) {
        continue;
      }
      final rect = rectByNode[id]!.inflate(minGap * 0.30);

      // Quick directional cull: if moving horizontally (LR/RL), only check Y; vertically (TB/BT), only check X
      bool cullPass = false;
      if (flowHorizontal) {
        // LR/RL: check Y range
        cullPass =
            !(rect.bottom < curveBbox.top || rect.top > curveBbox.bottom);
      } else {
        // TB/BT: check X range
        cullPass =
            !(rect.right < curveBbox.left || rect.left > curveBbox.right);
      }

      if (!cullPass) {
        continue;
      }

      // Second stage: quick bbox overlap (analytical, no sampling)
      if (!rect.overlaps(curveBbox)) {
        continue;
      }

      // Third stage: fine test with sparse sampling (only ~5-8 points for precision)
      final checkPoints = _sampleCubicSegmentsAdaptive(
        p0: p0,
        p1: c1,
        p2: c2,
        p3: p3,
        maxPoints: 8,
      );

      var intersects = false;
      for (final pt in checkPoints) {
        if (rect.contains(pt)) {
          intersects = true;
          break;
        }
      }

      if (intersects) {
        hits++;
      }
    }

    if (watch.elapsedMilliseconds > 1500 && edgeIndex % 8 == 0) {
      AutoLayoutEngine._logAudit(
        'stage=loop_progress stage=edge_over_node_bezier_hybrid edgeIndex=$edgeIndex/${allEdges.length} hits=$hits elapsedMs=${watch.elapsedMilliseconds}',
      );
    }

    if (AutoLayoutEngine._loopBudgetExceeded(
      stage: 'edge_over_node_bezier_hybrid',
      watch: watch,
      budgetMs: 1200,
      pass: edgeIndex,
      maxPasses: allEdges.length,
    )) {
      AutoLayoutEngine._logAudit(
        'stage=loop_guard stage=edge_over_node_bezier_hybrid trigger=budget_partial_return edgeIndex=$edgeIndex/${allEdges.length} hits=$hits',
      );
      break;
    }
  }

  if (watch.elapsedMilliseconds > 300) {
    AutoLayoutEngine._logAudit(
      'stage=edge_over_node_profile_hybrid edges=${allEdges.length} hits=$hits elapsedMs=${watch.elapsedMilliseconds}',
    );
  }

  return hits;
}

List<Offset> _sampleCubicSegmentsAdaptive({
  required Offset p0,
  required Offset p1,
  required Offset p2,
  required Offset p3,
  required int maxPoints,
}) {
  final points = <Offset>[p0, p3];
  if (maxPoints > 2) {
    points.insert(1, p1);
    if (maxPoints > 3) {
      points.insert(2, p2);
    }
    if (maxPoints > 4) {
      for (int i = 1; i < maxPoints - 2; i++) {
        final t = i / (maxPoints - 1);
        final mt = 1 - t;
        final x =
            mt * mt * mt * p0.dx +
            3 * mt * mt * t * p1.dx +
            3 * mt * t * t * p2.dx +
            t * t * t * p3.dx;
        final y =
            mt * mt * mt * p0.dy +
            3 * mt * mt * t * p1.dy +
            3 * mt * t * t * p2.dy +
            t * t * t * p3.dy;
        points.add(Offset(x, y));
      }
    }
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
    final pa = positions[a]!;
    final sa = sizeByNode[a]!;
    final ca = _nodeCenter(pa, sa);
    for (int j = i + 1; j < nodeOrder.length; j++) {
      final b = nodeOrder[j];
      final pb = positions[b]!;
      final sb = sizeByNode[b]!;
      final cb = _nodeCenter(pb, sb);

      final reqDx = (sa.width + sb.width) / 2 + minGap;
      final reqDy = (sa.height + sb.height) / 2 + minGap;
      final ox = reqDx - (ca.dx - cb.dx).abs();
      final oy = reqDy - (ca.dy - cb.dy).abs();
      if (ox > 0 && oy > 0) {
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
  required double subgraphTitleBandHeight,
  required double subgraphTitlePadding,
}) {
  if (subgraphNodeGroups.isEmpty) {
    return 0;
  }

  var violations = 0;
  final sets = [for (final g in subgraphNodeGroups) g.toSet()];
  final hierarchy = _buildGroupHierarchy(sets);

  for (int gi = 0; gi < subgraphNodeGroups.length; gi++) {
    final members = sets[gi];
    final bounds = _subgraphBounds(
      subgraphNodeGroups[gi],
      positions,
      sizeByNode,
      padding: minGap * 0.75 + subgraphTitlePadding,
    );
    final titleBand = Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.top + subgraphTitleBandHeight,
    );

    for (final id in nodeOrder) {
      if (members.contains(id)) {
        continue;
      }

      var skip = false;
      for (int oj = 0; oj < subgraphNodeGroups.length; oj++) {
        if (oj == gi || !sets[oj].contains(id)) {
          continue;
        }
        if (hierarchy[oj] == gi) {
          skip = true;
          break;
        }
      }
      if (skip) {
        continue;
      }

      final r = Rect.fromLTWH(
        positions[id]!.dx,
        positions[id]!.dy,
        sizeByNode[id]!.width,
        sizeByNode[id]!.height,
      );
      if (r.overlaps(bounds) || r.overlaps(titleBand)) {
        violations++;
      }
    }
  }

  return violations;
}

Map<int, int?> _buildGroupHierarchy(List<Set<String>> sets) {
  final parent = <int, int?>{for (int i = 0; i < sets.length; i++) i: null};
  for (int i = 0; i < sets.length; i++) {
    var bestParent = -1;
    var bestSize = 1 << 30;
    for (int j = 0; j < sets.length; j++) {
      if (i == j) {
        continue;
      }
      if (sets[j].containsAll(sets[i]) && sets[j].length > sets[i].length) {
        if (sets[j].length < bestSize) {
          bestSize = sets[j].length;
          bestParent = j;
        }
      }
    }
    parent[i] = bestParent == -1 ? null : bestParent;
  }
  return parent;
}

double _totalEdgeLength(
  Map<String, Offset> positions,
  Map<String, Size> sizeByNode,
  List<(String, String)> allEdges,
) {
  var total = 0.0;
  for (final e in allEdges) {
    final a = _nodeCenter(positions[e.$1]!, sizeByNode[e.$1]!);
    final b = _nodeCenter(positions[e.$2]!, sizeByNode[e.$2]!);
    total += (a - b).distance;
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
      final dx = (a.dx - b.dx).abs();
      final dy = (a.dy - b.dy).abs();
      if (dx <= 4) {
        score += 1.8;
      }
      if (dy <= 4) {
        score += 1.8;
      }
    }
  }
  return score;
}

Rect _subgraphBounds(
  List<String> nodeIds,
  Map<String, Offset> positions,
  Map<String, Size> sizeByNode, {
  double padding = 0.0,
}) {
  var left = double.infinity;
  var top = double.infinity;
  var right = -double.infinity;
  var bottom = -double.infinity;

  for (final id in nodeIds) {
    final p = positions[id];
    final s = sizeByNode[id];
    if (p == null || s == null) {
      continue;
    }
    left = math.min(left, p.dx);
    top = math.min(top, p.dy);
    right = math.max(right, p.dx + s.width);
    bottom = math.max(bottom, p.dy + s.height);
  }

  if (!left.isFinite || !top.isFinite || !right.isFinite || !bottom.isFinite) {
    return Rect.fromLTWH(0, 0, 1, 1);
  }

  return Rect.fromLTRB(
    left - padding,
    top - padding,
    right + padding,
    bottom + padding,
  );
}

Offset _nodeCenter(Offset topLeft, Size size) {
  return Offset(topLeft.dx + size.width / 2, topLeft.dy + size.height / 2);
}

Offset _meanOffset(Iterable<Offset> points) {
  var count = 0;
  var sx = 0.0;
  var sy = 0.0;
  for (final p in points) {
    sx += p.dx;
    sy += p.dy;
    count++;
  }
  if (count == 0) {
    return Offset.zero;
  }
  return Offset(sx / count, sy / count);
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
