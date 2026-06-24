import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'block_model.dart';

class AutoLayoutQualityProfile {
  final double iterationMul;
  final double repulsionMul;
  final double springMul;
  final double overlapMul;
  final double hpwlMul;
  final double crossingMul;
  final double spacingMul;
  final int channelPitch;
  final double snapTargetWeight;

  const AutoLayoutQualityProfile({
    required this.iterationMul,
    required this.repulsionMul,
    required this.springMul,
    required this.overlapMul,
    required this.hpwlMul,
    required this.crossingMul,
    required this.spacingMul,
    required this.channelPitch,
    required this.snapTargetWeight,
  });
}

class AutoLayoutEngine {
  static Map<String, Offset> computeMermaidAutoLayout({
    required List<String> nodeOrder,
    required List<({String fromId, String toId, String label})> edgeData,
    required String direction,
    required List<Block> effectiveBlocks,
    required AutoLayoutQualityProfile quality,
    Map<String, Offset>? seedPositions,
  }) {
    if (nodeOrder.isEmpty) {
      return {};
    }

    final nodeSet = nodeOrder.toSet();
    final directedEdges = <(String, String)>[];
    final allEdges = <(String, String)>[];
    final allEdgeSeen = <String>{};
    final neighbors = <String, Set<String>>{
      for (final id in nodeOrder) id: <String>{},
    };
    final degree = <String, int>{for (final id in nodeOrder) id: 0};

    for (final edge in edgeData) {
      if (!nodeSet.contains(edge.fromId) || !nodeSet.contains(edge.toId)) {
        continue;
      }
      if (edge.fromId == edge.toId) {
        continue;
      }

      directedEdges.add((edge.fromId, edge.toId));
      final a = edge.fromId;
      final b = edge.toId;
      final undirectedKey = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
      if (allEdgeSeen.add(undirectedKey)) {
        allEdges.add((a, b));
        neighbors[a]!.add(b);
        neighbors[b]!.add(a);
        degree[a] = (degree[a] ?? 0) + 1;
        degree[b] = (degree[b] ?? 0) + 1;
      }
    }

    final sizeByNode = <String, Size>{
      for (final id in nodeOrder)
        id: _sizeForNode(effectiveBlocks, id) ?? const Size(150, 100),
    };

    final hasSeeds = (seedPositions ?? const <String, Offset>{}).isNotEmpty;
    final seeded = seedPositions ?? const <String, Offset>{};

    final positions = _buildInitialPositions(
      nodeOrder: nodeOrder,
      direction: direction,
      sizeByNode: sizeByNode,
      directedEdges: directedEdges,
      neighbors: neighbors,
      degree: degree,
      seedPositions: seedPositions,
    );

    final avgWidth =
        sizeByNode.values.fold<double>(150.0, (sum, size) => sum + size.width) /
        math.max(1, sizeByNode.length);
    final avgHeight =
        sizeByNode.values.fold<double>(
          100.0,
          (sum, size) => sum + size.height,
        ) /
        math.max(1, sizeByNode.length);
    final scaledGap =
        (((avgWidth + avgHeight) * 0.07) + quality.channelPitch * 8.0) *
        quality.spacingMul;
    final blockGap = scaledGap.clamp(42.0, 140.0);
    final iterations = ((190 + nodeOrder.length * 8) * quality.iterationMul)
        .round()
        .clamp(180, 1000);

    final repulsionK = 7800.0 * quality.repulsionMul;
    final springK = 0.022 * quality.springMul;
    final separationK = 0.95 * quality.overlapMul;
    final crossingK = 34.0 * quality.crossingMul;
    final blockCutK = 44.0 * quality.hpwlMul;
    final medianK = 0.018 * quality.hpwlMul;
    final anchorK = hasSeeds ? (0.12 + 0.16 * quality.snapTargetWeight) : 0.0;
    final preserveDistanceK = hasSeeds ? 0.11 : 0.0;

    final isHorizontal = direction == 'LR' || direction == 'RL';
    final isReverse = direction == 'RL' || direction == 'BT';
    final flowSign = isReverse ? -1.0 : 1.0;

    final forces = <String, Offset>{
      for (final id in nodeOrder) id: Offset.zero,
    };
    final seededCenterByNode = <String, Offset>{
      for (final id in nodeOrder)
        if (seeded.containsKey(id))
          id: _nodeCenter(seeded[id]!, sizeByNode[id]!),
    };

    for (int iter = 0; iter < iterations; iter++) {
      final cooling = 1.0 - iter / (iterations + 10.0);
      final conflictScore = <String, double>{
        for (final id in nodeOrder) id: 0.0,
      };

      for (final id in nodeOrder) {
        forces[id] = Offset.zero;
      }

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

          final delta = ca - cb;
          final dist2 = math.max(
            12.0,
            delta.dx * delta.dx + delta.dy * delta.dy,
          );
          final dist = math.sqrt(dist2);
          final dir = dist > 1e-6 ? delta / dist : const Offset(1, 0);

          final reqDx = (sa.width + sb.width) / 2 + blockGap;
          final reqDy = (sa.height + sb.height) / 2 + blockGap;
          final overlapX = reqDx - (ca.dx - cb.dx).abs();
          final overlapY = reqDy - (ca.dy - cb.dy).abs();

          if (overlapX > 0 && overlapY > 0) {
            conflictScore[a] = conflictScore[a]! + 3.0;
            conflictScore[b] = conflictScore[b]! + 3.0;
            if (overlapX < overlapY) {
              final sx = ca.dx >= cb.dx ? 1.0 : -1.0;
              final push = Offset(sx * overlapX * separationK, 0);
              forces[a] = forces[a]! + push;
              forces[b] = forces[b]! - push;
            } else {
              final sy = ca.dy >= cb.dy ? 1.0 : -1.0;
              final push = Offset(0, sy * overlapY * separationK);
              forces[a] = forces[a]! + push;
              forces[b] = forces[b]! - push;
            }
          } else {
            final repulse = dir * (repulsionK / dist2);
            forces[a] = forces[a]! + repulse;
            forces[b] = forces[b]! - repulse;
          }

          if (hasSeeds &&
              seededCenterByNode.containsKey(a) &&
              seededCenterByNode.containsKey(b)) {
            final seededA = seededCenterByNode[a]!;
            final seededB = seededCenterByNode[b]!;
            final seededDist = (seededA - seededB).distance;
            if (seededDist > 1e-6) {
              final targetSeedDistance = seededDist * 1.02;
              final targetClearanceDistance =
                  math.max(reqDx, reqDy) + blockGap * 0.35;
              final minAllowed = math.max(
                targetSeedDistance,
                targetClearanceDistance,
              );
              if (dist < minAllowed) {
                final missing = minAllowed - dist;
                final push = dir * (missing * preserveDistanceK);
                forces[a] = forces[a]! + push;
                forces[b] = forces[b]! - push;
              }
            }
          }
        }
      }

      for (final edge in allEdges) {
        final a = edge.$1;
        final b = edge.$2;
        final pa = positions[a]!;
        final pb = positions[b]!;
        final sa = sizeByNode[a]!;
        final sb = sizeByNode[b]!;
        final ca = _nodeCenter(pa, sa);
        final cb = _nodeCenter(pb, sb);

        final idealLen = math.max(
          180.0,
          ((sa.longestSide + sb.longestSide) * 0.70 + blockGap) *
              quality.spacingMul,
        );
        final delta = cb - ca;
        final dist = math.max(1.0, delta.distance);
        final dir = delta / dist;
        final spring = dir * ((dist - idealLen) * springK);
        forces[a] = forces[a]! + spring;
        forces[b] = forces[b]! - spring;
      }

      if (isHorizontal || direction == 'TB' || direction == 'BT') {
        for (final edge in directedEdges) {
          final fromId = edge.$1;
          final toId = edge.$2;
          final fromCenter = _nodeCenter(
            positions[fromId]!,
            sizeByNode[fromId]!,
          );
          final toCenter = _nodeCenter(positions[toId]!, sizeByNode[toId]!);
          final axisDelta = isHorizontal
              ? (toCenter.dx - fromCenter.dx)
              : (toCenter.dy - fromCenter.dy);
          final missing = (95.0 - flowSign * axisDelta).clamp(0.0, 240.0);
          if (missing <= 0) {
            continue;
          }

          final f = missing * 0.060;
          final dirForce = isHorizontal
              ? Offset(flowSign * f, 0)
              : Offset(0, flowSign * f);
          forces[fromId] = forces[fromId]! - dirForce;
          forces[toId] = forces[toId]! + dirForce;
        }
      }

      if (allEdges.length > 1) {
        for (int i = 0; i < allEdges.length - 1; i++) {
          final e1 = allEdges[i];
          for (int j = i + 1; j < allEdges.length; j++) {
            final e2 = allEdges[j];
            final shared =
                e1.$1 == e2.$1 ||
                e1.$1 == e2.$2 ||
                e1.$2 == e2.$1 ||
                e1.$2 == e2.$2;
            if (shared) {
              continue;
            }

            final a1 = _nodeCenter(positions[e1.$1]!, sizeByNode[e1.$1]!);
            final b1 = _nodeCenter(positions[e1.$2]!, sizeByNode[e1.$2]!);
            final a2 = _nodeCenter(positions[e2.$1]!, sizeByNode[e2.$1]!);
            final b2 = _nodeCenter(positions[e2.$2]!, sizeByNode[e2.$2]!);

            if (!_segmentsIntersect(a1, b1, a2, b2)) {
              continue;
            }

            conflictScore[e1.$1] = conflictScore[e1.$1]! + 2.4;
            conflictScore[e1.$2] = conflictScore[e1.$2]! + 2.4;
            conflictScore[e2.$1] = conflictScore[e2.$1]! + 2.4;
            conflictScore[e2.$2] = conflictScore[e2.$2]! + 2.4;

            final n1 = _segmentNormal(a1, b1);
            final n2 = _segmentNormal(a2, b2);
            final push = crossingK * (0.25 + cooling);

            forces[e1.$1] = forces[e1.$1]! + n1 * push;
            forces[e1.$2] = forces[e1.$2]! + n1 * push;
            forces[e2.$1] = forces[e2.$1]! + n2 * push;
            forces[e2.$2] = forces[e2.$2]! + n2 * push;
          }
        }
      }

      final rectByNode = <String, Rect>{
        for (final id in nodeOrder)
          id: Rect.fromLTWH(
            positions[id]!.dx,
            positions[id]!.dy,
            sizeByNode[id]!.width,
            sizeByNode[id]!.height,
          ),
      };

      for (final edge in allEdges) {
        final fromId = edge.$1;
        final toId = edge.$2;
        final fromCenter = _nodeCenter(positions[fromId]!, sizeByNode[fromId]!);
        final toCenter = _nodeCenter(positions[toId]!, sizeByNode[toId]!);

        for (final nodeId in nodeOrder) {
          if (nodeId == fromId || nodeId == toId) {
            continue;
          }

          final blockRect = rectByNode[nodeId]!.inflate(blockGap * 0.45);
          if (!_segmentIntersectsRect(fromCenter, toCenter, blockRect)) {
            continue;
          }

          conflictScore[nodeId] = conflictScore[nodeId]! + 2.8;
          conflictScore[fromId] = conflictScore[fromId]! + 1.4;
          conflictScore[toId] = conflictScore[toId]! + 1.4;

          final center = blockRect.center;
          final nearest = _closestPointOnSegment(center, fromCenter, toCenter);
          var away = center - nearest;
          final dist = away.distance;
          away = dist > 1e-6
              ? away / dist
              : _segmentNormal(fromCenter, toCenter);

          final push = blockCutK * (0.22 + cooling);
          forces[nodeId] = forces[nodeId]! + away * push;
          forces[fromId] = forces[fromId]! - away * (push * 0.34);
          forces[toId] = forces[toId]! - away * (push * 0.34);
        }
      }

      for (final id in nodeOrder) {
        final linked = neighbors[id]!;
        if (linked.isEmpty) {
          continue;
        }

        var sum = Offset.zero;
        for (final n in linked) {
          sum += _nodeCenter(positions[n]!, sizeByNode[n]!);
        }
        final barycenter = sum / linked.length.toDouble();
        final currentCenter = _nodeCenter(positions[id]!, sizeByNode[id]!);
        forces[id] = forces[id]! + (barycenter - currentCenter) * medianK;

        if (hasSeeds && seeded.containsKey(id)) {
          final anchor = seeded[id]!;
          final conflict = conflictScore[id] ?? 0.0;
          final lock = conflict > 0.05 ? 0.30 : 1.0;
          forces[id] =
              forces[id]! + (anchor - positions[id]!) * (anchorK * lock);
        }
      }

      final baseStep = (0.16 * cooling).clamp(0.018, 0.16);
      for (final id in nodeOrder) {
        final conflict = conflictScore[id] ?? 0.0;
        final stableMul = hasSeeds ? (conflict > 0.05 ? 1.0 : 0.12) : 1.0;
        var step = forces[id]! * (baseStep * stableMul);

        final maxStep = 34.0 * (0.35 + cooling);
        if (step.distance > maxStep) {
          step = step / step.distance * maxStep;
        }

        var next = positions[id]! + step;
        if (hasSeeds && seeded.containsKey(id)) {
          final anchor = seeded[id]!;
          final maxRadius = conflict > 0.05 ? 260.0 : 20.0;
          final delta = next - anchor;
          if (delta.distance > maxRadius) {
            next = anchor + (delta / delta.distance) * maxRadius;
          }
        }
        positions[id] = next;
      }
    }

    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: blockGap,
    );

    _tryOpportunisticAlignment(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      neighbors: neighbors,
      direction: direction,
      minGap: blockGap,
    );

    _snapSeedJitterIfSafe(
      nodeOrder: nodeOrder,
      positions: positions,
      seedPositions: seeded,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: blockGap,
    );

    if (hasSeeds) {
      final finalPenalty = _hardConstraintPenalty(
        nodeOrder: nodeOrder,
        positions: positions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        minGap: blockGap,
      );
      final finalLength = _totalEdgeLength(positions, sizeByNode, allEdges);

      final seededPositions = <String, Offset>{
        for (final id in nodeOrder) id: seeded[id] ?? positions[id]!,
      };
      final seedPenalty = _hardConstraintPenalty(
        nodeOrder: nodeOrder,
        positions: seededPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        minGap: blockGap,
      );
      final seedLength = _totalEdgeLength(
        seededPositions,
        sizeByNode,
        allEdges,
      );

      final betterPenalty = finalPenalty + 1e-6 < seedPenalty;
      final equalPenalty = (finalPenalty - seedPenalty).abs() <= 1e-6;
      final betterLength = finalLength < seedLength * 0.995;

      if (!(betterPenalty || (equalPenalty && betterLength))) {
        return seededPositions;
      }
    }

    return positions;
  }

  static void _tryOpportunisticAlignment({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, Set<String>> neighbors,
    required String direction,
    required double minGap,
  }) {
    if (nodeOrder.length < 2) {
      return;
    }

    final alignTolerance = direction == 'LR' || direction == 'RL' ? 46.0 : 38.0;
    const minUsefulShift = 1.0;

    final baselinePenalty = _hardConstraintPenalty(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
    );
    var currentPenalty = baselinePenalty;
    var currentLength = _totalEdgeLength(positions, sizeByNode, allEdges);

    Map<String, Offset> buildAlignedCandidate({
      required Map<String, Offset> source,
      required bool alignTop,
    }) {
      final candidate = Map<String, Offset>.from(source);
      final tuples = <({String id, double edge})>[];
      for (final id in nodeOrder) {
        final p = candidate[id];
        final s = sizeByNode[id];
        if (p == null || s == null) {
          continue;
        }
        tuples.add((id: id, edge: alignTop ? p.dy : (p.dx + s.width)));
      }
      tuples.sort((a, b) => a.edge.compareTo(b.edge));

      int start = 0;
      while (start < tuples.length) {
        int end = start + 1;
        while (end < tuples.length &&
            (tuples[end].edge - tuples[start].edge) <= alignTolerance) {
          end++;
        }

        if (end - start >= 2) {
          final window = tuples.sublist(start, end);
          final values = window.map((e) => e.edge).toList()..sort();
          final target = values[values.length ~/ 2];

          for (final item in window) {
            final p = candidate[item.id]!;
            final s = sizeByNode[item.id]!;
            if ((item.edge - target).abs() < minUsefulShift) {
              continue;
            }
            if (alignTop) {
              candidate[item.id] = Offset(p.dx, target);
            } else {
              candidate[item.id] = Offset(target - s.width, p.dy);
            }
          }
        }

        start = end;
      }

      return candidate;
    }

    bool tryAccept(Map<String, Offset> candidate) {
      final penalty = _hardConstraintPenalty(
        nodeOrder: nodeOrder,
        positions: candidate,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        minGap: minGap,
      );
      final length = _totalEdgeLength(candidate, sizeByNode, allEdges);
      final keepsHardConstraints = penalty <= currentPenalty + 1e-6;
      final keepsLengthReasonable = length <= currentLength * 1.03;
      if (keepsHardConstraints && keepsLengthReasonable) {
        positions
          ..clear()
          ..addAll(candidate);
        currentPenalty = penalty;
        currentLength = length;
        return true;
      }
      return false;
    }

    final topCandidate = buildAlignedCandidate(
      source: positions,
      alignTop: true,
    );
    tryAccept(topCandidate);
    final rightCandidate = buildAlignedCandidate(
      source: positions,
      alignTop: false,
    );
    tryAccept(rightCandidate);
    final bothCandidate = buildAlignedCandidate(
      source: buildAlignedCandidate(source: positions, alignTop: true),
      alignTop: false,
    );
    tryAccept(bothCandidate);
  }

  static void _snapSeedJitterIfSafe({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Offset> seedPositions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required double minGap,
  }) {
    if (seedPositions.isEmpty) {
      return;
    }

    final baselinePenalty = _hardConstraintPenalty(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
    );
    final baselineLength = _totalEdgeLength(positions, sizeByNode, allEdges);

    for (final id in nodeOrder) {
      final seed = seedPositions[id];
      if (seed == null) {
        continue;
      }

      final current = positions[id]!;
      final drift = (current - seed).distance;
      if (drift > 12.0) {
        continue;
      }

      positions[id] = seed;
      final penalty = _hardConstraintPenalty(
        nodeOrder: nodeOrder,
        positions: positions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        minGap: minGap,
      );
      final length = _totalEdgeLength(positions, sizeByNode, allEdges);
      if (penalty > baselinePenalty + 1e-6 || length > baselineLength * 1.02) {
        positions[id] = current;
      }
    }
  }

  static double _totalEdgeLength(
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
    List<(String, String)> allEdges,
  ) {
    var total = 0.0;
    for (final edge in allEdges) {
      final a = edge.$1;
      final b = edge.$2;
      final pa = positions[a];
      final pb = positions[b];
      final sa = sizeByNode[a];
      final sb = sizeByNode[b];
      if (pa == null || pb == null || sa == null || sb == null) {
        continue;
      }
      total += (_nodeCenter(pa, sa) - _nodeCenter(pb, sb)).distance;
    }
    return total;
  }

  static double _hardConstraintPenalty({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required double minGap,
  }) {
    var penalty = 0.0;

    final rectByNode = <String, Rect>{
      for (final id in nodeOrder)
        id: Rect.fromLTWH(
          positions[id]!.dx,
          positions[id]!.dy,
          sizeByNode[id]!.width,
          sizeByNode[id]!.height,
        ),
    };

    for (int i = 0; i < nodeOrder.length - 1; i++) {
      final a = nodeOrder[i];
      final ra = rectByNode[a]!;
      final sa = sizeByNode[a]!;
      for (int j = i + 1; j < nodeOrder.length; j++) {
        final b = nodeOrder[j];
        final rb = rectByNode[b]!;
        final sb = sizeByNode[b]!;

        final dx = (ra.center.dx - rb.center.dx).abs();
        final dy = (ra.center.dy - rb.center.dy).abs();
        final reqDx = (sa.width + sb.width) / 2 + minGap;
        final reqDy = (sa.height + sb.height) / 2 + minGap;
        final ox = reqDx - dx;
        final oy = reqDy - dy;
        if (ox > 0 && oy > 0) {
          penalty += 200000 + ox * oy * 1600;
        }
      }
    }

    for (int i = 0; i < allEdges.length - 1; i++) {
      final e1 = allEdges[i];
      final sharedNodes = <String>{e1.$1, e1.$2};
      final p1 = _nodeCenter(positions[e1.$1]!, sizeByNode[e1.$1]!);
      final p2 = _nodeCenter(positions[e1.$2]!, sizeByNode[e1.$2]!);
      for (int j = i + 1; j < allEdges.length; j++) {
        final e2 = allEdges[j];
        if (sharedNodes.contains(e2.$1) || sharedNodes.contains(e2.$2)) {
          continue;
        }
        final p3 = _nodeCenter(positions[e2.$1]!, sizeByNode[e2.$1]!);
        final p4 = _nodeCenter(positions[e2.$2]!, sizeByNode[e2.$2]!);
        if (_segmentsIntersect(p1, p2, p3, p4)) {
          penalty += 60000;
        }
      }
    }

    for (final edge in allEdges) {
      final a = edge.$1;
      final b = edge.$2;
      final p1 = _nodeCenter(positions[a]!, sizeByNode[a]!);
      final p2 = _nodeCenter(positions[b]!, sizeByNode[b]!);
      for (final id in nodeOrder) {
        if (id == a || id == b) {
          continue;
        }
        if (_segmentIntersectsRect(
          p1,
          p2,
          rectByNode[id]!.inflate(minGap * 0.35),
        )) {
          penalty += 120000;
        }
      }
    }

    return penalty;
  }

  static Map<String, Offset> _buildInitialPositions({
    required List<String> nodeOrder,
    required String direction,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> directedEdges,
    required Map<String, Set<String>> neighbors,
    required Map<String, int> degree,
    required Map<String, Offset>? seedPositions,
  }) {
    final out = <String, Offset>{};
    final seeds = seedPositions ?? const <String, Offset>{};

    if (seeds.isNotEmpty) {
      for (final id in nodeOrder) {
        out[id] = seeds[id] ?? Offset.zero;
      }

      final center = _meanOffset(out.values);
      int offsetIndex = 0;
      for (final id in nodeOrder) {
        if (seeds.containsKey(id)) {
          continue;
        }
        out[id] = _spiralTopLeft(
          center: center,
          index: offsetIndex++,
          direction: direction,
          size: sizeByNode[id]!,
        );
      }
      return out;
    }

    final indegree = <String, int>{for (final id in nodeOrder) id: 0};
    final outgoing = <String, List<String>>{
      for (final id in nodeOrder) id: <String>[],
    };
    for (final edge in directedEdges) {
      indegree[edge.$2] = (indegree[edge.$2] ?? 0) + 1;
      outgoing[edge.$1]!.add(edge.$2);
    }

    final roots = nodeOrder.where((id) => (indegree[id] ?? 0) == 0).toList();
    roots.sort((a, b) => (degree[b] ?? 0).compareTo(degree[a] ?? 0));
    if (roots.isEmpty) {
      roots.addAll(nodeOrder.take(1));
    }

    final layerByNode = <String, int>{};
    final queue = <String>[...roots];
    for (final id in roots) {
      layerByNode[id] = 0;
    }

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentLayer = layerByNode[current] ?? 0;
      for (final to in outgoing[current] ?? const <String>[]) {
        final nextLayer = currentLayer + 1;
        final existing = layerByNode[to];
        if (existing == null || nextLayer < existing) {
          layerByNode[to] = nextLayer;
          queue.add(to);
        }
      }
    }

    for (final id in nodeOrder) {
      layerByNode.putIfAbsent(id, () => 0);
    }

    final layers = <int, List<String>>{};
    for (final id in nodeOrder) {
      final layer = layerByNode[id] ?? 0;
      layers.putIfAbsent(layer, () => <String>[]).add(id);
    }

    for (final ids in layers.values) {
      ids.sort((a, b) {
        final byDegree = (degree[b] ?? 0).compareTo(degree[a] ?? 0);
        if (byDegree != 0) {
          return byDegree;
        }
        return a.compareTo(b);
      });
    }

    final sortedLayers = layers.keys.toList()..sort();
    final maxNodeW = sizeByNode.values.fold<double>(
      140.0,
      (m, s) => math.max(m, s.width),
    );
    final maxNodeH = sizeByNode.values.fold<double>(
      90.0,
      (m, s) => math.max(m, s.height),
    );
    final layerPitch = (maxNodeW + 170.0).clamp(220.0, 420.0);
    final lanePitch = (maxNodeH + 100.0).clamp(150.0, 320.0);
    final isHorizontal = direction == 'LR' || direction == 'RL';
    final flowSign = (direction == 'RL' || direction == 'BT') ? -1.0 : 1.0;

    const base = Offset(260, 180);
    for (final layer in sortedLayers) {
      final ids = layers[layer] ?? const <String>[];
      for (int i = 0; i < ids.length; i++) {
        final id = ids[i];
        final side = i - (ids.length - 1) / 2;
        final center = isHorizontal
            ? Offset(
                base.dx + flowSign * layer * layerPitch,
                base.dy + side * lanePitch,
              )
            : Offset(
                base.dx + side * lanePitch,
                base.dy + flowSign * layer * layerPitch,
              );
        final size = sizeByNode[id]!;
        out[id] = center - Offset(size.width / 2, size.height / 2);
      }
    }

    return out;
  }

  static void _resolveResidualOverlaps({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required double minGap,
  }) {
    for (int pass = 0; pass < 16; pass++) {
      var moved = false;
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
          final overlapX = reqDx - (ca.dx - cb.dx).abs();
          final overlapY = reqDy - (ca.dy - cb.dy).abs();
          if (overlapX <= 0 || overlapY <= 0) {
            continue;
          }

          moved = true;
          if (overlapX < overlapY) {
            final sign = ca.dx >= cb.dx ? 1.0 : -1.0;
            final shift = (overlapX + 1.0) * 0.5;
            positions[a] = pa + Offset(sign * shift, 0);
            positions[b] = pb - Offset(sign * shift, 0);
          } else {
            final sign = ca.dy >= cb.dy ? 1.0 : -1.0;
            final shift = (overlapY + 1.0) * 0.5;
            positions[a] = pa + Offset(0, sign * shift);
            positions[b] = pb - Offset(0, sign * shift);
          }
        }
      }
      if (!moved) {
        break;
      }
    }
  }

  static Offset _spiralTopLeft({
    required Offset center,
    required int index,
    required String direction,
    required Size size,
  }) {
    final angle = index * 0.72;
    final radial = 46.0 + index * 14.0;
    final anisotropy = (direction == 'LR' || direction == 'RL') ? 1.30 : 0.78;
    final cx = center.dx + math.cos(angle) * radial * anisotropy;
    final cy = center.dy + math.sin(angle) * radial;
    return Offset(cx - size.width / 2, cy - size.height / 2);
  }

  static Offset _nodeCenter(Offset topLeft, Size size) {
    return Offset(topLeft.dx + size.width / 2, topLeft.dy + size.height / 2);
  }

  static Offset _meanOffset(Iterable<Offset> points) {
    var count = 0;
    var sx = 0.0;
    var sy = 0.0;
    for (final p in points) {
      count++;
      sx += p.dx;
      sy += p.dy;
    }
    if (count == 0) {
      return Offset.zero;
    }
    return Offset(sx / count, sy / count);
  }

  static Offset _segmentNormal(Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    if (len <= 1e-6) {
      return const Offset(0, 1);
    }
    return Offset(-d.dy / len, d.dx / len);
  }

  static Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final denom = ab.dx * ab.dx + ab.dy * ab.dy;
    if (denom <= 1e-8) {
      return a;
    }
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / denom;
    final clamped = t.clamp(0.0, 1.0);
    return a + ab * clamped;
  }

  static bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    if (rect.contains(a) || rect.contains(b)) {
      return true;
    }

    final tl = Offset(rect.left, rect.top);
    final tr = Offset(rect.right, rect.top);
    final br = Offset(rect.right, rect.bottom);
    final bl = Offset(rect.left, rect.bottom);

    return _segmentsIntersect(a, b, tl, tr) ||
        _segmentsIntersect(a, b, tr, br) ||
        _segmentsIntersect(a, b, br, bl) ||
        _segmentsIntersect(a, b, bl, tl);
  }

  static Size? _sizeForNode(List<Block> blocks, String id) {
    for (final block in blocks) {
      if (block.id == id) {
        return block.size;
      }
    }
    return null;
  }

  static bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    double cross(Offset u, Offset v) => u.dx * v.dy - u.dy * v.dx;

    bool onSegment(Offset p, Offset q, Offset r) {
      const eps = 1e-9;
      return q.dx <= math.max(p.dx, r.dx) + eps &&
          q.dx >= math.min(p.dx, r.dx) - eps &&
          q.dy <= math.max(p.dy, r.dy) + eps &&
          q.dy >= math.min(p.dy, r.dy) - eps;
    }

    int orientation(Offset p, Offset q, Offset r) {
      final value = cross(q - p, r - p);
      if (value.abs() <= 1e-9) {
        return 0;
      }
      return value > 0 ? 1 : 2;
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
}
