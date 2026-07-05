import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/block_model.dart';

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
  final double alignmentPriority;
  final double seededAlignmentPriority;

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
    required this.alignmentPriority,
    this.seededAlignmentPriority = 1.0,
  });
}

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

class AutoLayoutEngine {
  static bool enableDiagnosticsLogs = true;
  static final List<String> _auditTrail = <String>[];
  static const int _maxAuditTrailLines = 120000;

  static void setDiagnosticsLogsEnabled(bool enabled) {
    enableDiagnosticsLogs = enabled;
  }

  static void clearAuditTrail() {
    _auditTrail.clear();
  }

  static List<String> getAuditTrailSnapshot() {
    return List<String>.unmodifiable(_auditTrail);
  }

  static void _pushAuditTrailLine(String line) {
    _auditTrail.add(line);
    if (_auditTrail.length > _maxAuditTrailLines) {
      _auditTrail.removeRange(0, _auditTrail.length - _maxAuditTrailLines);
    }
  }

  static void debugLog(String message) {
    _logAudit(message);
  }

  static void _logAudit(String message) {
    if (!enableDiagnosticsLogs) {
      return;
    }
    final line = '[ELK-AUDIT] $message';
    _pushAuditTrailLine(line);
    debugPrint(line);
  }

  static void _logDiag(String message) {
    if (!enableDiagnosticsLogs) {
      return;
    }
    final line = '[ELK-DIAG] $message';
    _pushAuditTrailLine(line);
    debugPrint(line);
  }

  static AutoLayoutDebugMetrics collectDebugMetrics({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
  }) {
    final m = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
    );
    return AutoLayoutDebugMetrics(
      crossings: m.crossings,
      edgeOverNodeHits: m.edgeOverNodeHits,
      nodeOverlapPairs: m.nodeOverlapPairs,
      subgraphViolations: m.subgraphViolations,
      hardViolation: m.hardViolation,
      totalEdgeLength: m.totalEdgeLength,
      alignmentScore: m.alignmentScore,
      objective: m.objective,
    );
  }

  static Map<String, Offset> computeMermaidAutoLayout({
    required List<String> nodeOrder,
    required List<({String fromId, String toId, String label})> edgeData,
    required String direction,
    required List<Block> effectiveBlocks,
    required AutoLayoutQualityProfile quality,
    Map<String, Offset>? seedPositions,
    List<List<String>>? subgraphNodeGroups,
  }) {
    if (nodeOrder.isEmpty) {
      return {};
    }

    final nodeSet = nodeOrder.toSet();
    final directedEdges = <(String, String)>[];
    final directedSeen = <String>{};
    final allEdges = <(String, String)>[];
    final allSeen = <String>{};
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

      final a = edge.fromId;
      final b = edge.toId;
      if (directedSeen.add('$a|$b')) {
        directedEdges.add((a, b));
      }
      final key = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
      if (allSeen.add(key)) {
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
    final groups = _normalizeSubgraphGroups(subgraphNodeGroups, nodeSet);
    final groupSets = [for (final g in groups) g.toSet()];

    final seeded = seedPositions ?? const <String, Offset>{};
    final hasSeeds = seeded.isNotEmpty;
    final alignPriority = quality.alignmentPriority.clamp(-1.0, 2.0);
    final seededAlignPriority = quality.seededAlignmentPriority.clamp(0.0, 3.0);

    _logAudit(
      'stage=compute_start hasSeeds=$hasSeeds alignPriority=${alignPriority.toStringAsFixed(2)} seededPriority=${seededAlignPriority.toStringAsFixed(2)} seedIntent=${seededAlignPriority.toStringAsFixed(2)} forceSeedGlobalAlignment=false subgraphs=${groups.length}',
    );

    final renderer = _chooseRenderer(
      nodeCount: nodeOrder.length,
      edgeCount: allEdges.length,
      groups: groups,
    );
    _logAudit(
      'stage=renderer_choice renderer=$renderer n=${nodeOrder.length} m=${allEdges.length} density=${(allEdges.length / math.max(1, nodeOrder.length)).toStringAsFixed(2)}',
    );

    final basePositions = _computeLayeredLayout(
      nodeOrder: nodeOrder,
      directedEdges: directedEdges,
      neighbors: neighbors,
      degree: degree,
      sizeByNode: sizeByNode,
      direction: direction,
      quality: quality,
      seedPositions: seeded,
      subgraphNodeGroups: groups,
      renderer: renderer,
    );

    final avgWidth =
        sizeByNode.values.fold<double>(0.0, (s, z) => s + z.width) /
        math.max(1, sizeByNode.length);
    final avgHeight =
        sizeByNode.values.fold<double>(0.0, (s, z) => s + z.height) /
        math.max(1, sizeByNode.length);
    final spacing = quality.spacingMul.clamp(0.45, 2.2);
    final minGap =
        (((avgWidth + avgHeight) * 0.06) + quality.channelPitch * 5.0) *
        (0.30 + spacing * 0.90);
    final blockGap = minGap.clamp(12.0, 220.0);

    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: basePositions,
      sizeByNode: sizeByNode,
      minGap: blockGap,
    );
    _resolveSubgraphGroupOverlaps(
      positions: basePositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      subgraphNodeGroupSets: groupSets,
      minGap: blockGap,
    );
    _enforceSubgraphMembershipExclusion(
      nodeOrder: nodeOrder,
      positions: basePositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );

    var selectedPositions = basePositions;

    final seedPositionsProjected = <String, Offset>{
      for (final id in nodeOrder) id: seeded[id] ?? selectedPositions[id]!,
    };

    final candidateMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    final seedMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: seedPositionsProjected,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );

    final keepCandidateByDefault =
        !hasSeeds ||
        (candidateMetrics.hardViolation < seedMetrics.hardViolation) ||
        (candidateMetrics.hardViolation == seedMetrics.hardViolation &&
            (candidateMetrics.crossings < seedMetrics.crossings ||
                (candidateMetrics.crossings == seedMetrics.crossings &&
                    candidateMetrics.edgeOverNodeHits <=
                        seedMetrics.edgeOverNodeHits)));
    final severeRoutingRegression =
        hasSeeds &&
        candidateMetrics.crossings >= seedMetrics.crossings + 2 &&
        candidateMetrics.edgeOverNodeHits >= seedMetrics.edgeOverNodeHits + 2;
    final hardZeroRoutingNonRegressionRequired =
        hasSeeds &&
        candidateMetrics.hardViolation == 0 &&
        seedMetrics.hardViolation <= 2 &&
        (candidateMetrics.crossings > seedMetrics.crossings + 1 ||
            candidateMetrics.edgeOverNodeHits >
                seedMetrics.edgeOverNodeHits + 1);
    final softSeedGateAccepted =
        hasSeeds &&
        candidateMetrics.hardViolation <= seedMetrics.hardViolation &&
        candidateMetrics.crossings <= seedMetrics.crossings &&
        candidateMetrics.edgeOverNodeHits <= seedMetrics.edgeOverNodeHits + 2 &&
        candidateMetrics.totalEdgeLength <= seedMetrics.totalEdgeLength * 1.50;
    final bypassSeedFallback =
        hasSeeds &&
        candidateMetrics.hardViolation <= seedMetrics.hardViolation &&
        candidateMetrics.crossings <= seedMetrics.crossings - 1 &&
        candidateMetrics.edgeOverNodeHits <= seedMetrics.edgeOverNodeHits + 1 &&
        candidateMetrics.totalEdgeLength <= seedMetrics.totalEdgeLength * 1.35;

    _logAudit(
      'stage=seed_compare crossingsSeed=${seedMetrics.crossings} crossingsCandidate=${candidateMetrics.crossings} edgeOverNodeSeed=${seedMetrics.edgeOverNodeHits} edgeOverNodeCandidate=${candidateMetrics.edgeOverNodeHits}',
    );
    _logAudit(
      'stage=seed_fallback_check seedPenalty=${seedMetrics.objective.toStringAsFixed(4)} finalPenalty=${candidateMetrics.objective.toStringAsFixed(4)} seedLen=${seedMetrics.totalEdgeLength.toStringAsFixed(2)} finalLen=${candidateMetrics.totalEdgeLength.toStringAsFixed(2)} seedAlign=${seedMetrics.alignmentScore.toStringAsFixed(2)} finalAlign=${candidateMetrics.alignmentScore.toStringAsFixed(2)}',
    );

    final seedGateVeto =
        severeRoutingRegression || hardZeroRoutingNonRegressionRequired;
    final shouldKeepCandidate =
        (keepCandidateByDefault ||
            bypassSeedFallback ||
            softSeedGateAccepted) &&
        !seedGateVeto;
    if (hasSeeds && !shouldKeepCandidate) {
      final rejectReason = seedGateVeto
          ? (severeRoutingRegression
                ? 'routing_regression_severe'
                : 'hard_zero_routing_nonregression_failed')
          : 'gate_rejected';
      _logAudit('stage=seed_decision bypass=false reason=gate_rejected');
      _logAudit(
        'stage=seed_fallback_decision action=restore_seed reason=$rejectReason',
      );
      selectedPositions = seedPositionsProjected;
    } else {
      final seedReason = bypassSeedFallback
          ? 'bypass'
          : (softSeedGateAccepted ? 'soft_gate' : 'gate_accepted');
      _logAudit(
        'stage=seed_decision bypass=${bypassSeedFallback ? 'true' : 'false'} reason=keep_layout mode=$seedReason',
      );
      _logAudit(
        'stage=seed_fallback_decision action=keep_layout reason=$seedReason',
      );
    }

    final seedStabilityBaseline = <String, Offset>{
      for (final id in nodeOrder) id: selectedPositions[id]!,
    };
    final seedStabilityBaselineMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: seedStabilityBaseline,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    final seedIsPrimarySafe =
        seedMetrics.hardViolation == 0 &&
        seedMetrics.crossings <= candidateMetrics.crossings &&
        seedMetrics.edgeOverNodeHits <= candidateMetrics.edgeOverNodeHits;
    final seedStabilityGuardEnabled =
        hasSeeds && (!shouldKeepCandidate || seedIsPrimarySafe);
    _logAudit(
      'stage=seed_stability_guard enabled=${seedStabilityGuardEnabled ? 'true' : 'false'} baselineCross=${seedStabilityBaselineMetrics.crossings} baselineEdgeOver=${seedStabilityBaselineMetrics.edgeOverNodeHits} baselineHard=${seedStabilityBaselineMetrics.hardViolation}',
    );

    _repairRoutingByNodeMoves(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      degree: degree,
      direction: direction,
      minGap: blockGap,
      stageTag: 'post_seed',
    );

    if (quality.spacingMul <= 0.50 && !hasSeeds && alignPriority < 0.2) {
      _applyDenseCompaction(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: blockGap,
      );
      _resolveResidualOverlaps(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        minGap: blockGap,
      );
      _resolveSubgraphGroupOverlaps(
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        subgraphNodeGroups: groups,
        subgraphNodeGroupSets: groupSets,
        minGap: blockGap,
      );
      _enforceSubgraphMembershipExclusion(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        subgraphNodeGroups: groups,
        minGap: blockGap,
      );
    }

    _reduceEdgeCrossings(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      direction: direction,
      minGap: blockGap,
      stageTag: 'pre_axis',
    );
    _forceUncrossByEndpointKick(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      degree: degree,
      direction: direction,
      minGap: blockGap,
      stageTag: 'pre_axis',
    );

    final shouldAlign = alignPriority >= 0.0;
    if (shouldAlign) {
      _applyAxisAlignment(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: blockGap,
        alignmentPriority: alignPriority,
        seededAlignmentPriority: seededAlignPriority,
        snapTargetWeight: quality.snapTargetWeight,
        hasSeeds: hasSeeds,
      );
    } else {
      final reason = alignPriority < 0.0 ? 'align_disabled' : 'no_reason';
      _logAudit('stage=axis_align skipped=$reason');
    }

    _clearEdgePathOverBlockOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: blockGap,
      direction: direction,
      seededAlignmentPriority: seededAlignPriority,
    );

    final prePostPathRepairMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    final alignmentRequestedForPostRepair =
        alignPriority >= 0.20 || seededAlignPriority >= 0.95;
    final cleanGraphForPostRepair =
        prePostPathRepairMetrics.hardViolation == 0 &&
        prePostPathRepairMetrics.crossings == 0 &&
        prePostPathRepairMetrics.edgeOverNodeHits == 0;

    if (alignmentRequestedForPostRepair && cleanGraphForPostRepair) {
      _logAudit(
        'stage=routing_repair_post_path_clearance skipped=alignment_preserve_clean_graph cross=${prePostPathRepairMetrics.crossings} edgeOver=${prePostPathRepairMetrics.edgeOverNodeHits} hard=${prePostPathRepairMetrics.hardViolation}',
      );
    } else {
      _repairRoutingByNodeMoves(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        degree: degree,
        direction: direction,
        minGap: blockGap,
        stageTag: 'post_path_clearance',
      );
    }
    _finalCrossingEscape(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      degree: degree,
      direction: direction,
      minGap: blockGap,
      subgraphNodeGroups: groups,
    );
    _clearEdgePathOverBlockOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: blockGap,
      direction: direction,
      seededAlignmentPriority: seededAlignPriority,
    );
    _reduceEdgeCrossings(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      direction: direction,
      minGap: blockGap,
      stageTag: 'post_path_clearance',
    );
    _forceUncrossByEndpointKick(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      degree: degree,
      direction: direction,
      minGap: blockGap,
      stageTag: 'post_path_clearance',
    );

    final postPathMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    if (postPathMetrics.edgeOverNodeHits > 0) {
      _logAudit(
        'stage=post_path_clearance_strict trigger=true edgeOver=${postPathMetrics.edgeOverNodeHits} crossings=${postPathMetrics.crossings}',
      );
      _clearEdgePathOverBlockOverlaps(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        minGap: blockGap,
        direction: direction,
        seededAlignmentPriority: seededAlignPriority,
        strictMode: true,
      );
      _repairRoutingByNodeMoves(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        degree: degree,
        direction: direction,
        minGap: blockGap,
        stageTag: 'post_path_clearance_strict',
      );
      _reduceEdgeCrossings(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        direction: direction,
        minGap: blockGap,
        stageTag: 'post_path_clearance_strict',
      );
      _forceUncrossByEndpointKick(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        degree: degree,
        direction: direction,
        minGap: blockGap,
        stageTag: 'post_path_clearance_strict',
      );
    }

    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      minGap: blockGap,
    );
    _resolveSubgraphGroupOverlaps(
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      subgraphNodeGroupSets: groupSets,
      minGap: blockGap,
    );
    _enforceSubgraphMembershipExclusion(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      minGap: blockGap,
    );
    _enforceSubgraphMembershipExclusion(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    _hardStopNoCrossingSmallGraph(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      degree: degree,
      direction: direction,
      minGap: blockGap,
      subgraphNodeGroups: groups,
    );
    _gridSearchUncrossSmallGraph(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      degree: degree,
      direction: direction,
      minGap: blockGap,
      subgraphNodeGroups: groups,
    );
    _clearEdgePathOverBlockOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: blockGap,
      direction: direction,
      seededAlignmentPriority: seededAlignPriority,
    );
    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      minGap: blockGap,
    );
    _resolveSubgraphGroupOverlaps(
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      subgraphNodeGroupSets: groupSets,
      minGap: blockGap,
    );
    _enforceSubgraphMembershipExclusion(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );

    if (seedStabilityGuardEnabled) {
      final postMetrics = _collectMetrics(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: blockGap,
      );

      var movedNodes = 0;
      var maxDrift = 0.0;
      var sumDrift = 0.0;
      for (final id in nodeOrder) {
        final before = seedStabilityBaseline[id];
        final after = selectedPositions[id];
        if (before == null || after == null) {
          continue;
        }
        final d = (after - before).distance;
        if (d > 0.01) {
          movedNodes++;
        }
        if (d > maxDrift) {
          maxDrift = d;
        }
        sumDrift += d;
      }
      final avgDrift = nodeOrder.isEmpty
          ? 0.0
          : (sumDrift / math.max(1, nodeOrder.length));

      final worsenedPrimary =
          postMetrics.hardViolation >
              seedStabilityBaselineMetrics.hardViolation ||
          postMetrics.crossings > seedStabilityBaselineMetrics.crossings ||
          postMetrics.edgeOverNodeHits >
              seedStabilityBaselineMetrics.edgeOverNodeHits;
      final improvedHard =
          postMetrics.hardViolation <
          seedStabilityBaselineMetrics.hardViolation;
      final noPrimaryGain =
          postMetrics.hardViolation ==
              seedStabilityBaselineMetrics.hardViolation &&
          postMetrics.crossings == seedStabilityBaselineMetrics.crossings &&
          postMetrics.edgeOverNodeHits ==
              seedStabilityBaselineMetrics.edgeOverNodeHits;
      final worsenedObjective =
          postMetrics.objective > seedStabilityBaselineMetrics.objective + 1e-6;
      final excessiveDrift =
          movedNodes > 0 && (avgDrift > 6.0 || maxDrift > 18.0);
      final alignmentRequested =
          alignPriority >= 0.20 || seededAlignPriority >= 0.95;
      final driftRollbackAllowed = !alignmentRequested;
      final shouldRollback =
          (!improvedHard) &&
          (worsenedPrimary ||
              (noPrimaryGain &&
                  (worsenedObjective ||
                      (excessiveDrift && driftRollbackAllowed))));

      if (shouldRollback) {
        for (final id in nodeOrder) {
          selectedPositions[id] = seedStabilityBaseline[id]!;
        }
      }

      _logAudit(
        'stage=seed_stability_eval rollback=${shouldRollback ? 'true' : 'false'} improvedHard=${improvedHard ? 'true' : 'false'} worsenedPrimary=${worsenedPrimary ? 'true' : 'false'} noPrimaryGain=${noPrimaryGain ? 'true' : 'false'} worsenedObjective=${worsenedObjective ? 'true' : 'false'} excessiveDrift=${excessiveDrift ? 'true' : 'false'} alignmentRequested=${alignmentRequested ? 'true' : 'false'} driftRollbackAllowed=${driftRollbackAllowed ? 'true' : 'false'} avgDrift=${avgDrift.toStringAsFixed(2)} maxDrift=${maxDrift.toStringAsFixed(2)} movedNodes=$movedNodes postCross=${postMetrics.crossings} postEdgeOver=${postMetrics.edgeOverNodeHits} postHard=${postMetrics.hardViolation}',
      );
    }

    _enforceSubgraphToSubgraphGap(
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      subgraphNodeGroupSets: groupSets,
      minGap: blockGap,
    );

    // Final hard-constraint clamp: never return with avoidable overlap/subgraph violations.
    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      minGap: blockGap,
    );
    _enforceSubgraphMembershipExclusion(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    _enforceSubgraphVisualClearance(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    _enforceSubgraphToSubgraphGap(
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      subgraphNodeGroupSets: groupSets,
      minGap: blockGap,
    );
    _reanchorDisconnectedNodes(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      neighbors: neighbors,
      direction: direction,
      minGap: blockGap,
      subgraphNodeGroups: groups,
    );
    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      minGap: blockGap,
    );
    _enforceSubgraphMembershipExclusion(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    _enforceSubgraphToSubgraphGap(
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      subgraphNodeGroupSets: groupSets,
      minGap: blockGap,
    );
    for (int hardPass = 0; hardPass < 3; hardPass++) {
      final probe = _collectMetrics(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: blockGap,
      );
      if (probe.hardViolation == 0) {
        break;
      }
      _resolveResidualOverlaps(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        minGap: blockGap,
      );
      _enforceSubgraphMembershipExclusion(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        subgraphNodeGroups: groups,
        minGap: blockGap,
      );
      _enforceSubgraphVisualClearance(
        nodeOrder: nodeOrder,
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        subgraphNodeGroups: groups,
        minGap: blockGap,
      );
      _enforceSubgraphToSubgraphGap(
        positions: selectedPositions,
        sizeByNode: sizeByNode,
        subgraphNodeGroups: groups,
        subgraphNodeGroupSets: groupSets,
        minGap: blockGap,
      );
    }

    final finalMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    final baselineNearBoundaryContacts = _countSubgraphNearBoundaryContacts(
      nodeOrder: nodeOrder,
      positions: seedStabilityBaseline,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );
    final finalNearBoundaryContacts = _countSubgraphNearBoundaryContacts(
      nodeOrder: nodeOrder,
      positions: selectedPositions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: blockGap,
    );

    final primaryNotImprovedVsBaseline =
        finalMetrics.hardViolation >=
            seedStabilityBaselineMetrics.hardViolation &&
        finalMetrics.crossings >= seedStabilityBaselineMetrics.crossings &&
        finalMetrics.edgeOverNodeHits >=
            seedStabilityBaselineMetrics.edgeOverNodeHits;
    final clearanceImproved =
        finalNearBoundaryContacts < baselineNearBoundaryContacts;
    final objectiveWorsenedVsBaseline =
        finalMetrics.objective > seedStabilityBaselineMetrics.objective + 8.0;

    var finalMovedNodes = 0;
    var finalMaxDrift = 0.0;
    var finalSumDrift = 0.0;
    for (final id in nodeOrder) {
      final before = seedStabilityBaseline[id];
      final after = selectedPositions[id];
      if (before == null || after == null) {
        continue;
      }
      final d = (after - before).distance;
      if (d > 0.01) {
        finalMovedNodes++;
      }
      if (d > finalMaxDrift) {
        finalMaxDrift = d;
      }
      finalSumDrift += d;
    }
    final finalAvgDrift = nodeOrder.isEmpty
        ? 0.0
        : (finalSumDrift / math.max(1, nodeOrder.length));
    final massiveDrift =
        finalMovedNodes > 0 && (finalAvgDrift > 120.0 || finalMaxDrift > 700.0);
    final scoreExploded =
        finalMetrics.objective >
        seedStabilityBaselineMetrics.objective * 4.0 + 50000.0;
    final driftRollback =
        massiveDrift &&
        (finalAvgDrift > 180.0 ||
            finalMaxDrift > 900.0 ||
            finalMovedNodes >= math.max(4, nodeOrder.length ~/ 3));

    final rollbackFinalToSeedBaseline =
        seedStabilityGuardEnabled &&
        ((primaryNotImprovedVsBaseline &&
                !clearanceImproved &&
                objectiveWorsenedVsBaseline) ||
            (massiveDrift && scoreExploded) ||
            driftRollback);
    if (rollbackFinalToSeedBaseline) {
      for (final id in nodeOrder) {
        selectedPositions[id] = seedStabilityBaseline[id]!;
      }
    }

    final stableFinalMetrics = rollbackFinalToSeedBaseline
        ? _collectMetrics(
            nodeOrder: nodeOrder,
            positions: selectedPositions,
            sizeByNode: sizeByNode,
            allEdges: allEdges,
            subgraphNodeGroups: groups,
            minGap: blockGap,
          )
        : finalMetrics;
    _logAudit(
      'stage=final_seed_guard rollback=${rollbackFinalToSeedBaseline ? 'true' : 'false'} primaryNotImproved=${primaryNotImprovedVsBaseline ? 'true' : 'false'} clearanceImproved=${clearanceImproved ? 'true' : 'false'} objectiveWorsened=${objectiveWorsenedVsBaseline ? 'true' : 'false'} massiveDrift=${massiveDrift ? 'true' : 'false'} scoreExploded=${scoreExploded ? 'true' : 'false'} avgDrift=${finalAvgDrift.toStringAsFixed(2)} maxDrift=${finalMaxDrift.toStringAsFixed(2)} movedNodes=$finalMovedNodes nearBoundaryBaseline=$baselineNearBoundaryContacts nearBoundaryFinal=$finalNearBoundaryContacts',
    );
    _logAudit(
      'stage=final_hard_clamp crossings=${stableFinalMetrics.crossings} edgeOverNode=${stableFinalMetrics.edgeOverNodeHits} hard=${stableFinalMetrics.hardViolation} subgraphViol=${stableFinalMetrics.subgraphViolations} overlap=${stableFinalMetrics.nodeOverlapPairs}',
    );

    return selectedPositions;
  }

  static String _chooseRenderer({
    required int nodeCount,
    required int edgeCount,
    required List<List<String>> groups,
  }) {
    final density = edgeCount / math.max(1, nodeCount);
    final maxDepth = 1; // hierarchy depth is not explicit in this API shape.

    if (nodeCount >= 45 ||
        edgeCount >= 70 ||
        density >= 1.6 ||
        maxDepth >= 2 ||
        groups.length >= 3) {
      return 'elk-like';
    }
    return 'dagre-like';
  }

  static Map<String, Offset> _computeLayeredLayout({
    required List<String> nodeOrder,
    required List<(String, String)> directedEdges,
    required Map<String, Set<String>> neighbors,
    required Map<String, int> degree,
    required Map<String, Size> sizeByNode,
    required String direction,
    required AutoLayoutQualityProfile quality,
    required Map<String, Offset> seedPositions,
    required List<List<String>> subgraphNodeGroups,
    required String renderer,
  }) {
    final isHorizontal = direction == 'LR' || direction == 'RL';
    final reverseFlow = direction == 'RL' || direction == 'BT';

    final incoming = <String, Set<String>>{
      for (final id in nodeOrder) id: <String>{},
    };
    final outgoing = <String, Set<String>>{
      for (final id in nodeOrder) id: <String>{},
    };

    for (final e in directedEdges) {
      outgoing[e.$1]!.add(e.$2);
      incoming[e.$2]!.add(e.$1);
    }

    final order = _feedbackOrder(
      nodeOrder: nodeOrder,
      incoming: incoming,
      outgoing: outgoing,
      degree: degree,
      sizeByNode: sizeByNode,
      seedPositions: seedPositions,
      isHorizontal: isHorizontal,
    );
    final rank = <String, int>{
      for (int i = 0; i < order.length; i++) order[i]: i,
    };

    final acyclic = <(String, String)>[];
    for (final e in directedEdges) {
      final a = rank[e.$1] ?? 0;
      final b = rank[e.$2] ?? 0;
      acyclic.add(a <= b ? e : (e.$2, e.$1));
    }

    final layer = <String, int>{for (final id in nodeOrder) id: 0};
    final topo = [...order];
    for (final id in topo) {
      var best = 0;
      for (final parent in incoming[id]!) {
        best = math.max(best, (layer[parent] ?? 0) + 1);
      }
      layer[id] = best;
    }

    final maxLayer = layer.values.fold<int>(0, math.max);
    final layers = List.generate(maxLayer + 1, (_) => <String>[]);
    for (final id in nodeOrder) {
      layers[layer[id] ?? 0].add(id);
    }

    for (final l in layers) {
      l.sort((a, b) {
        final sa =
            _seedSecondary(seedPositions, sizeByNode, a, isHorizontal) ??
            (degree[a] ?? 0).toDouble();
        final sb =
            _seedSecondary(seedPositions, sizeByNode, b, isHorizontal) ??
            (degree[b] ?? 0).toDouble();
        final bySeed = sa.compareTo(sb);
        if (bySeed != 0) {
          return bySeed;
        }
        return a.compareTo(b);
      });
    }

    final sweeps = renderer == 'elk-like' ? 7 : 5;
    for (int pass = 0; pass < sweeps; pass++) {
      for (int i = 1; i < layers.length; i++) {
        _orderByNeighborBarycenter(
          layer: layers[i],
          neighbors: incoming,
          refLayer: layers[i - 1],
        );
        _swapReducePairCrossings(
          layer: layers[i],
          neighbors: incoming,
          refLayer: layers[i - 1],
        );
      }
      for (int i = layers.length - 2; i >= 0; i--) {
        _orderByNeighborBarycenter(
          layer: layers[i],
          neighbors: outgoing,
          refLayer: layers[i + 1],
        );
        _swapReducePairCrossings(
          layer: layers[i],
          neighbors: outgoing,
          refLayer: layers[i + 1],
        );
      }
    }

    final avgW =
        sizeByNode.values.fold<double>(0.0, (s, z) => s + z.width) /
        math.max(1, sizeByNode.length);
    final avgH =
        sizeByNode.values.fold<double>(0.0, (s, z) => s + z.height) /
        math.max(1, sizeByNode.length);
    final spacing = quality.spacingMul.clamp(0.45, 2.2);

    final layerGap =
        (((isHorizontal ? avgW : avgH) * 0.8) + (avgW + avgH) * 0.15) *
        (0.55 + spacing * 0.7);
    final laneGap =
        (((isHorizontal ? avgH : avgW) * 0.45) + 24.0) * (0.35 + spacing * 0.8);

    final positions = <String, Offset>{};
    for (int layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      final ids = layers[layerIndex];
      final sizes = ids
          .map(
            (id) =>
                isHorizontal ? sizeByNode[id]!.height : sizeByNode[id]!.width,
          )
          .toList(growable: false);
      final extent =
          sizes.fold<double>(0.0, (s, v) => s + v) +
          laneGap * math.max(0, ids.length - 1);
      var cursor = -extent / 2;
      for (int i = 0; i < ids.length; i++) {
        final id = ids[i];
        final size = sizeByNode[id]!;
        final centerSecondary = cursor + sizes[i] / 2;
        final centerPrimary = layerIndex * layerGap;
        final center = isHorizontal
            ? Offset(centerPrimary, centerSecondary)
            : Offset(centerSecondary, centerPrimary);
        positions[id] = center - Offset(size.width / 2, size.height / 2);
        cursor += sizes[i] + laneGap;
      }
    }

    _logSubgraphSurfaces(
      'after_place',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _clusterSubgraphs(
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      strength: renderer == 'elk-like' ? 0.32 : 0.24,
    );
    _logSubgraphSurfaces(
      'after_cluster_1',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _packConnectedComponents(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      neighbors: neighbors,
      gap: laneGap * 2.0,
    );
    _logSubgraphSurfaces(
      'after_component_pack',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _compactUnlinkedSubgraphMembers(
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      neighbors: neighbors,
      laneGap: laneGap,
      layerGap: layerGap,
      isHorizontal: isHorizontal,
    );
    _logSubgraphSurfaces(
      'after_unlinked_compact_1',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _clusterSubgraphs(
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      strength: renderer == 'elk-like' ? 0.30 : 0.22,
    );
    _logSubgraphSurfaces(
      'after_cluster_2',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _applyAspectRatioPreference(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      hasSubgraphs: subgraphNodeGroups.isNotEmpty,
      seedCount: seedPositions.length,
    );
    _logSubgraphSurfaces(
      'after_aspect',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _nudgeTowardSeed(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      seedPositions: seedPositions,
      layerByNode: layer,
      isHorizontal: isHorizontal,
    );
    _logSubgraphSurfaces(
      'after_seed_nudge',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _logSubgraphSurfaces(
      'after_sibling_pack',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );
    _logSubgraphSurfaces(
      'after_recursive_pack',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _compactUnlinkedSubgraphMembers(
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      neighbors: neighbors,
      laneGap: laneGap * 0.9,
      layerGap: layerGap,
      isHorizontal: isHorizontal,
    );
    _logSubgraphSurfaces(
      'after_unlinked_compact_2',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _clusterSubgraphs(
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      strength: renderer == 'elk-like' ? 0.22 : 0.18,
    );
    _logSubgraphSurfaces(
      'after_cluster_3',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _compactUnlinkedSubgraphMembers(
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      neighbors: neighbors,
      laneGap: laneGap * 0.85,
      layerGap: layerGap,
      isHorizontal: isHorizontal,
    );
    _logSubgraphSurfaces(
      'after_unlinked_compact_3',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    _translateToPositiveCanvas(nodeOrder, positions, sizeByNode);
    _logSubgraphSurfaces(
      'after_positive_canvas',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    if (reverseFlow) {
      _applyReverseDirection(nodeOrder, positions, sizeByNode, direction);
    }
    _logSubgraphSurfaces(
      'after_reverse_direction',
      direction,
      nodeOrder,
      subgraphNodeGroups,
      positions,
      sizeByNode,
    );

    return positions;
  }

  static List<String> _feedbackOrder({
    required List<String> nodeOrder,
    required Map<String, Set<String>> incoming,
    required Map<String, Set<String>> outgoing,
    required Map<String, int> degree,
    required Map<String, Size> sizeByNode,
    required Map<String, Offset> seedPositions,
    required bool isHorizontal,
  }) {
    final remaining = nodeOrder.toSet();
    final left = <String>[];
    final right = <String>[];

    int outLive(String id) => outgoing[id]!.where(remaining.contains).length;
    int inLive(String id) => incoming[id]!.where(remaining.contains).length;

    int cmp(String a, String b) {
      final sa = _seedPrimary(seedPositions, sizeByNode, a, isHorizontal);
      final sb = _seedPrimary(seedPositions, sizeByNode, b, isHorizontal);
      if (sa != null && sb != null) {
        final bySeed = sa.compareTo(sb);
        if (bySeed != 0) {
          return bySeed;
        }
      }
      final byDegree = (degree[b] ?? 0).compareTo(degree[a] ?? 0);
      if (byDegree != 0) {
        return byDegree;
      }
      return a.compareTo(b);
    }

    while (remaining.isNotEmpty) {
      final sinks = remaining.where((id) => outLive(id) == 0).toList()
        ..sort(cmp);
      if (sinks.isNotEmpty) {
        for (final id in sinks) {
          if (remaining.remove(id)) {
            right.add(id);
          }
        }
        continue;
      }

      final sources = remaining.where((id) => inLive(id) == 0).toList()
        ..sort(cmp);
      if (sources.isNotEmpty) {
        for (final id in sources) {
          if (remaining.remove(id)) {
            left.add(id);
          }
        }
        continue;
      }

      final cands = remaining.toList()
        ..sort((a, b) {
          final ia = outLive(a) - inLive(a);
          final ib = outLive(b) - inLive(b);
          final byImb = ib.compareTo(ia);
          if (byImb != 0) {
            return byImb;
          }
          return cmp(a, b);
        });
      final chosen = cands.first;
      remaining.remove(chosen);
      left.add(chosen);
    }

    return [...left, ...right.reversed];
  }

  static void _orderByNeighborBarycenter({
    required List<String> layer,
    required Map<String, Set<String>> neighbors,
    required List<String> refLayer,
  }) {
    if (layer.length < 2 || refLayer.isEmpty) {
      return;
    }

    final refIndex = <String, int>{
      for (int i = 0; i < refLayer.length; i++) refLayer[i]: i,
    };

    double bary(String id) {
      final values =
          (neighbors[id] ?? const <String>{})
              .where(refIndex.containsKey)
              .map((n) => refIndex[n]!.toDouble())
              .toList(growable: false)
            ..sort();
      if (values.isEmpty) {
        return 0.0;
      }
      return values[values.length ~/ 2];
    }

    final stable = <String, int>{
      for (int i = 0; i < layer.length; i++) layer[i]: i,
    };
    layer.sort((a, b) {
      final ba = bary(a);
      final bb = bary(b);
      final byBary = ba.compareTo(bb);
      if (byBary != 0) {
        return byBary;
      }
      return (stable[a] ?? 0).compareTo(stable[b] ?? 0);
    });
  }

  static void _swapReducePairCrossings({
    required List<String> layer,
    required Map<String, Set<String>> neighbors,
    required List<String> refLayer,
  }) {
    if (layer.length < 2 || refLayer.isEmpty) {
      return;
    }

    final refIndex = <String, int>{
      for (int i = 0; i < refLayer.length; i++) refLayer[i]: i,
    };

    int pairCross(String left, String right) {
      final l = (neighbors[left] ?? const <String>{})
          .where(refIndex.containsKey)
          .map((n) => refIndex[n]!)
          .toList(growable: false);
      final r = (neighbors[right] ?? const <String>{})
          .where(refIndex.containsKey)
          .map((n) => refIndex[n]!)
          .toList(growable: false);
      var c = 0;
      for (final li in l) {
        for (final ri in r) {
          if (li > ri) {
            c++;
          }
        }
      }
      return c;
    }

    for (int pass = 0; pass < 4; pass++) {
      var improved = false;
      for (int i = 0; i < layer.length - 1; i++) {
        final cur = pairCross(layer[i], layer[i + 1]);
        final swp = pairCross(layer[i + 1], layer[i]);
        if (swp < cur) {
          final t = layer[i];
          layer[i] = layer[i + 1];
          layer[i + 1] = t;
          improved = true;
        }
      }
      if (!improved) {
        break;
      }
    }
  }

  static void _clusterSubgraphs({
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> subgraphNodeGroups,
    required double strength,
  }) {
    if (subgraphNodeGroups.isEmpty) {
      return;
    }

    for (final group in subgraphNodeGroups) {
      final ids = group.where(positions.containsKey).toList(growable: false);
      if (ids.length < 2) {
        continue;
      }
      final centers = <Offset>[
        for (final id in ids) _nodeCenter(positions[id]!, sizeByNode[id]!),
      ];
      final bary = _meanOffset(centers);
      for (final id in ids) {
        final size = sizeByNode[id]!;
        final c = _nodeCenter(positions[id]!, size);
        final next = Offset(
          c.dx + (bary.dx - c.dx) * strength,
          c.dy + (bary.dy - c.dy) * strength,
        );
        positions[id] = next - Offset(size.width / 2, size.height / 2);
      }
    }
  }

  static void _packConnectedComponents({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required Map<String, Set<String>> neighbors,
    required double gap,
  }) {
    final remaining = nodeOrder.toSet();
    final components = <List<String>>[];
    while (remaining.isNotEmpty) {
      final start = remaining.first;
      final stack = <String>[start];
      final comp = <String>[];
      remaining.remove(start);
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        comp.add(cur);
        for (final n in neighbors[cur] ?? const <String>{}) {
          if (remaining.remove(n)) {
            stack.add(n);
          }
        }
      }
      components.add(comp);
    }

    if (components.length < 2) {
      return;
    }

    final ordered = [...components]
      ..sort((a, b) {
        final ba = _subgraphBounds(a, positions, sizeByNode);
        final bb = _subgraphBounds(b, positions, sizeByNode);
        final byY = ba.top.compareTo(bb.top);
        if (byY != 0) {
          return byY;
        }
        return ba.left.compareTo(bb.left);
      });

    final cols = math.max(1, math.sqrt(ordered.length).ceil());
    var x = 0.0;
    var y = 0.0;
    var rowH = 0.0;
    var col = 0;
    for (final comp in ordered) {
      final b = _subgraphBounds(comp, positions, sizeByNode);
      final delta = Offset(x - b.left, y - b.top);
      for (final id in comp) {
        positions[id] = positions[id]! + delta;
      }
      rowH = math.max(rowH, b.height);
      x += b.width + gap;
      col++;
      if (col >= cols) {
        col = 0;
        x = 0;
        y += rowH + gap;
        rowH = 0;
      }
    }
  }

  static void _compactUnlinkedSubgraphMembers({
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> subgraphNodeGroups,
    required Map<String, Set<String>> neighbors,
    required double laneGap,
    required double layerGap,
    required bool isHorizontal,
  }) {
    for (final group in subgraphNodeGroups) {
      final movable = <String>[];
      for (final id in group) {
        final p = positions[id];
        final s = sizeByNode[id];
        if (p == null || s == null) {
          continue;
        }
        movable.add(id);
      }
      if (movable.length < 2) {
        continue;
      }

      final forceLinear = movable.length <= 9;
      final center = _meanOffset([
        for (final id in movable) _nodeCenter(positions[id]!, sizeByNode[id]!),
      ]);

      final ordered = [...movable]
        ..sort((a, b) {
          final ca = _nodeCenter(positions[a]!, sizeByNode[a]!);
          final cb = _nodeCenter(positions[b]!, sizeByNode[b]!);
          final byPrimary = isHorizontal
              ? ca.dx.compareTo(cb.dx)
              : ca.dy.compareTo(cb.dy);
          if (byPrimary != 0) {
            return byPrimary;
          }
          return a.compareTo(b);
        });

      final avgW =
          ordered.fold<double>(0.0, (s, id) => s + sizeByNode[id]!.width) /
          ordered.length;
      final avgH =
          ordered.fold<double>(0.0, (s, id) => s + sizeByNode[id]!.height) /
          ordered.length;
      final stepX = avgW + laneGap * 0.35;
      final stepY = avgH + layerGap * 0.10;
      final linearStep = isHorizontal ? stepY : stepX;
      final startPrimary = isHorizontal
          ? center.dy - (ordered.length - 1) * linearStep / 2
          : center.dx - (ordered.length - 1) * linearStep / 2;
      final cols = forceLinear
          ? 1
          : math.max(1, math.sqrt(ordered.length).ceil());
      final rows = (ordered.length / cols).ceil();
      final startX = center.dx - (cols - 1) * stepX / 2;
      final startY = center.dy - (rows - 1) * stepY / 2;

      for (int i = 0; i < ordered.length; i++) {
        final id = ordered[i];
        final desired = forceLinear
            ? (isHorizontal
                  ? Offset(center.dx, startPrimary + i * linearStep)
                  : Offset(startPrimary + i * linearStep, center.dy))
            : Offset(startX + (i % cols) * stepX, startY + (i ~/ cols) * stepY);
        final current = _nodeCenter(positions[id]!, sizeByNode[id]!);
        final next = current + (desired - current) * 0.92;
        final size = sizeByNode[id]!;
        positions[id] = next - Offset(size.width / 2, size.height / 2);
      }
    }
  }

  static void _applyAspectRatioPreference({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required bool hasSubgraphs,
    required int seedCount,
  }) {
    if (positions.length < 2) {
      return;
    }
    final b = _subgraphBounds(nodeOrder, positions, sizeByNode);
    final ratio = b.width / math.max(1.0, b.height);
    final targetMin = hasSubgraphs ? 0.50 : 0.65;
    final targetMax = hasSubgraphs ? 2.10 : 1.60;
    if (ratio >= targetMin && ratio <= targetMax) {
      return;
    }

    final center = b.center;
    final seedDamping = seedCount == 0 ? 1.0 : 0.60;
    final maxStretch = hasSubgraphs ? 1.18 : 1.65;

    if (ratio > targetMax) {
      final scale = (1.0 + (math.sqrt(ratio / targetMax) - 1.0) * seedDamping)
          .clamp(1.0, maxStretch);
      for (final id in nodeOrder) {
        final size = sizeByNode[id]!;
        final c = _nodeCenter(positions[id]!, size);
        final next = Offset(c.dx, center.dy + (c.dy - center.dy) * scale);
        positions[id] = next - Offset(size.width / 2, size.height / 2);
      }
      return;
    }

    final scale =
        (1.0 +
                (math.sqrt(targetMin / math.max(0.01, ratio)) - 1.0) *
                    seedDamping)
            .clamp(1.0, maxStretch);
    for (final id in nodeOrder) {
      final size = sizeByNode[id]!;
      final c = _nodeCenter(positions[id]!, size);
      final next = Offset(center.dx + (c.dx - center.dx) * scale, c.dy);
      positions[id] = next - Offset(size.width / 2, size.height / 2);
    }
  }

  static void _nudgeTowardSeed({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required Map<String, Offset> seedPositions,
    required Map<String, int> layerByNode,
    required bool isHorizontal,
  }) {
    if (seedPositions.isEmpty) {
      return;
    }

    final maxLayer = layerByNode.values.fold<int>(0, math.max);
    final seededPrimary =
        seedPositions.entries
            .map(
              (e) => isHorizontal
                  ? e.value.dx + (sizeByNode[e.key]?.width ?? 0) / 2
                  : e.value.dy + (sizeByNode[e.key]?.height ?? 0) / 2,
            )
            .toList(growable: false)
          ..sort();
    if (seededPrimary.isEmpty) {
      return;
    }

    final minP = seededPrimary.first;
    final maxP = seededPrimary.last;
    final span = math.max(1.0, maxP - minP);

    for (final id in nodeOrder) {
      final seed = seedPositions[id];
      if (seed == null) {
        continue;
      }
      final size = sizeByNode[id]!;
      final c = _nodeCenter(positions[id]!, size);
      final targetPrimary =
          minP + ((layerByNode[id] ?? 0) / math.max(1, maxLayer)) * span;
      final seedSecondary = isHorizontal
          ? seed.dy + size.height / 2
          : seed.dx + size.width / 2;
      final next = isHorizontal
          ? Offset(
              c.dx * 0.82 + targetPrimary * 0.18,
              c.dy * 0.72 + seedSecondary * 0.28,
            )
          : Offset(
              c.dx * 0.72 + seedSecondary * 0.28,
              c.dy * 0.82 + targetPrimary * 0.18,
            );
      positions[id] = next - Offset(size.width / 2, size.height / 2);
    }
  }

  static void _translateToPositiveCanvas(
    List<String> nodeOrder,
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
  ) {
    final b = _subgraphBounds(nodeOrder, positions, sizeByNode);
    final delta = Offset(180 - b.left, 140 - b.top);
    for (final id in nodeOrder) {
      positions[id] = positions[id]! + delta;
    }
  }

  static void _applyReverseDirection(
    List<String> nodeOrder,
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
    String direction,
  ) {
    final b = _subgraphBounds(nodeOrder, positions, sizeByNode);
    if (direction == 'RL') {
      for (final id in nodeOrder) {
        final size = sizeByNode[id]!;
        final mirroredLeft =
            b.left + b.right - (positions[id]!.dx + size.width);
        positions[id] = Offset(mirroredLeft, positions[id]!.dy);
      }
      return;
    }
    if (direction == 'BT') {
      for (final id in nodeOrder) {
        final size = sizeByNode[id]!;
        final mirroredTop =
            b.top + b.bottom - (positions[id]!.dy + size.height);
        positions[id] = Offset(positions[id]!.dx, mirroredTop);
      }
    }
  }

  static void _logSubgraphSurfaces(
    String stage,
    String direction,
    List<String> nodeOrder,
    List<List<String>> subgraphNodeGroups,
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
  ) {
    if (!enableDiagnosticsLogs || subgraphNodeGroups.isEmpty) {
      return;
    }

    _logDiag(
      'stage=$stage direction=$direction nodeCount=${nodeOrder.length} subgraphCount=${subgraphNodeGroups.length}',
    );
    for (int i = 0; i < subgraphNodeGroups.length; i++) {
      final group = subgraphNodeGroups[i]
          .where(positions.containsKey)
          .toList(growable: false);
      if (group.isEmpty) {
        continue;
      }
      final b = _subgraphBounds(group, positions, sizeByNode);
      final area = b.width * b.height;
      final perimeter = b.width + b.height;
      final isolated =
          group.where((id) => true).length - group.where((id) => false).length;
      final centers = [
        for (final id in group) _nodeCenter(positions[id]!, sizeByNode[id]!),
      ];
      final bary = _meanOffset(centers);
      var avg = 0.0;
      var maxD = 0.0;
      for (final c in centers) {
        final d = (c - bary).distance;
        avg += d;
        if (d > maxD) {
          maxD = d;
        }
      }
      avg = centers.isEmpty ? 0.0 : avg / centers.length;
      _logDiag(
        'stage=$stage subgraph=group#$i size=${group.length} isolated=$isolated linked=${group.length - isolated} area=${area.toStringAsFixed(1)} perimeter=${perimeter.toStringAsFixed(1)} bounds=[${b.left.toStringAsFixed(1)},${b.top.toStringAsFixed(1)} -> ${b.right.toStringAsFixed(1)},${b.bottom.toStringAsFixed(1)}] spread(avg=${avg.toStringAsFixed(1)},max=${maxD.toStringAsFixed(1)})',
      );
    }
  }

  static _LayoutMetrics _collectMetrics({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
  }) {
    final crossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    final edgeOverNodeHits = _countEdgeOverBlockHits(
      nodeOrder,
      positions,
      sizeByNode,
      allEdges,
      minGap,
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
    final totalEdgeLength = _totalEdgeLength(positions, sizeByNode, allEdges);
    final alignmentScore = _edgeAlignmentScore(positions, sizeByNode);

    final objective =
        crossings * 1000000.0 +
        edgeOverNodeHits * 220000.0 +
        nodeOverlapPairs * 12000.0 +
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

  static void _applyDenseCompaction({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
  }) {
    if (nodeOrder.length < 2) {
      _logAudit('stage=dense_compaction skipped=too_few_nodes');
      return;
    }

    final seen = <String>{};
    final pairs = <(String, String)>[];
    for (final e in allEdges) {
      final k = e.$1.compareTo(e.$2) <= 0
          ? '${e.$1}|${e.$2}'
          : '${e.$2}|${e.$1}';
      if (seen.add(k)) {
        pairs.add(e);
      }
    }
    for (final g in subgraphNodeGroups) {
      for (int i = 0; i < g.length - 1; i++) {
        for (int j = i + 1; j < g.length; j++) {
          final a = g[i];
          final b = g[j];
          final k = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
          if (seen.add(k)) {
            pairs.add((a, b));
          }
        }
      }
    }

    if (pairs.isEmpty) {
      _logAudit('stage=dense_compaction skipped=no_pairs');
      return;
    }

    final targetGap = (minGap * 0.45).clamp(12.0, 32.0);
    const maxPasses = 8;
    var moves = 0;
    var movedDistance = 0.0;

    for (int pass = 0; pass < maxPasses; pass++) {
      var movedThisPass = 0;
      for (final p in pairs) {
        final pa = positions[p.$1];
        final pb = positions[p.$2];
        final sa = sizeByNode[p.$1];
        final sb = sizeByNode[p.$2];
        if (pa == null || pb == null || sa == null || sb == null) {
          continue;
        }

        final ca = _nodeCenter(pa, sa);
        final cb = _nodeCenter(pb, sb);
        final delta = cb - ca;
        final dist = delta.distance;
        if (dist <= 1e-6) {
          continue;
        }

        final desired =
            (math.max(sa.width, sb.width) + math.max(sa.height, sb.height)) /
                2 +
            targetGap;
        if (dist <= desired) {
          continue;
        }

        final excess = dist - desired;
        final step = (excess * 0.26).clamp(0.0, 36.0);
        if (step <= 0.05) {
          continue;
        }

        final dir = delta / dist;
        final shift = dir * (step * 0.5);
        positions[p.$1] = pa + shift;
        positions[p.$2] = pb - shift;
        moves++;
        movedThisPass++;
        movedDistance += step;
      }
      if (movedThisPass == 0) {
        break;
      }
    }

    _logAudit(
      'stage=dense_compaction pairs=${pairs.length} moves=$moves movedDistance=${movedDistance.toStringAsFixed(2)} targetGap=${targetGap.toStringAsFixed(1)}',
    );
  }

  static void _applyAxisAlignment({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
    required double alignmentPriority,
    required double seededAlignmentPriority,
    required double snapTargetWeight,
    required bool hasSeeds,
  }) {
    if (nodeOrder.length < 2) {
      _logAudit('stage=axis_align skipped=too_few_nodes');
      return;
    }

    final p =
        (alignmentPriority.clamp(0.0, 2.0) +
                (hasSeeds
                    ? seededAlignmentPriority.clamp(0.0, 3.0) * 0.55
                    : 0.0))
            .clamp(0.0, 3.0);
    final snapW = snapTargetWeight.clamp(0.0, 3.0);
    final subgraphHeavy = subgraphNodeGroups.length >= 3;
    final localityScale = subgraphHeavy ? 0.72 : 1.0;
    final tolerance = ((20.0 + 30.0 * p) * localityScale).clamp(18.0, 96.0);
    final blend = ((p >= 2.2 ? 1.0 : (0.58 + 0.17 * p)) * localityScale).clamp(
      0.50,
      1.0,
    );
    final minShift = p >= 1.5 ? 0.0 : 0.8;
    final passes =
        ((3 + p.round() + (hasSeeds ? 1 : 0)) - (subgraphHeavy ? 1 : 0)).clamp(
          3,
          7,
        );

    var avgW = 0.0;
    var avgH = 0.0;
    for (final id in nodeOrder) {
      final s = sizeByNode[id];
      if (s == null) {
        continue;
      }
      avgW += s.width;
      avgH += s.height;
    }
    if (nodeOrder.isNotEmpty) {
      avgW /= nodeOrder.length;
      avgH /= nodeOrder.length;
    }

    final gridStepX = (avgW * 0.62 + minGap * (0.80 + snapW * 0.10)).clamp(
      56.0,
      220.0,
    );
    final gridStepY = (avgH * 0.64 + minGap * (0.86 + snapW * 0.12)).clamp(
      52.0,
      220.0,
    );

    double medianValue(Iterable<double> values) {
      final sorted = values.toList()..sort();
      if (sorted.isEmpty) {
        return 0.0;
      }
      return sorted[sorted.length ~/ 2];
    }

    final gridAnchorX = medianValue(
      nodeOrder.map((id) => positions[id]?.dx ?? 0.0),
    );
    final gridAnchorY = medianValue(
      nodeOrder.map((id) => positions[id]?.dy ?? 0.0),
    );

    double snapToGrid(double value, double anchor, double step) {
      if (step <= 1e-6) {
        return value;
      }
      final k = ((value - anchor) / step).roundToDouble();
      return anchor + k * step;
    }

    _logAudit(
      'stage=axis_align_start passes=$passes priority=${p.toStringAsFixed(2)} snapWeight=${snapW.toStringAsFixed(2)} tolerance=${tolerance.toStringAsFixed(1)} blend=${blend.toStringAsFixed(2)} grid=[${gridStepX.toStringAsFixed(1)},${gridStepY.toStringAsFixed(1)}] hasSeeds=$hasSeeds',
    );

    var moves = 0;
    var movedDistance = 0.0;
    var rejectedByGuards = 0;

    var currentCrossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    var currentEdgeOverNode = _countEdgeOverBlockHits(
      nodeOrder,
      positions,
      sizeByNode,
      allEdges,
      minGap,
    );
    var currentSubgraphViol = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
    );
    var currentOverlapPairs = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );
    var currentAlignScore = _edgeAlignmentScore(positions, sizeByNode);

    List<(String, String)> buildSpatialNeighborPairs() {
      final ids = [
        for (final id in nodeOrder)
          if (positions.containsKey(id)) id,
      ];
      if (ids.length < 2) {
        return const <(String, String)>[];
      }

      final targetK =
          ((3 + (p * 0.9).round() + (snapW * 0.6).round()) -
                  (subgraphHeavy ? 1 : 0))
              .clamp(2, 6);
      final maxRadius =
          ((minGap * (5.2 + snapW * 0.7) + 120.0 + 18.0 * p) * localityScale)
              .clamp(120.0, 420.0);
      final maxRadius2 = maxRadius * maxRadius;
      final seen = <String>{};
      final pairs = <(String, String)>[];

      for (final a in ids) {
        final pa = positions[a]!;
        final dist = <({String id, double d2})>[];
        for (final b in ids) {
          if (a == b) {
            continue;
          }
          final pb = positions[b]!;
          final dx = pb.dx - pa.dx;
          final dy = pb.dy - pa.dy;
          dist.add((id: b, d2: dx * dx + dy * dy));
        }
        dist.sort((x, y) => x.d2.compareTo(y.d2));

        var added = 0;
        for (final c in dist) {
          if (added >= 2 && c.d2 > maxRadius2) {
            break;
          }
          final b = c.id;
          final k = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
          if (seen.add(k)) {
            pairs.add((a, b));
            added++;
          }
          if (added >= targetK) {
            break;
          }
        }
      }

      return pairs;
    }

    var neighborPairs = buildSpatialNeighborPairs();

    double neighborAlignmentPenalty() {
      var penalty = 0.0;
      for (final pair in neighborPairs) {
        final pa = positions[pair.$1];
        final pb = positions[pair.$2];
        if (pa == null || pb == null) {
          continue;
        }
        final dy = (pa.dy - pb.dy).abs();
        final dx = (pa.dx - pb.dx).abs();
        // Spatial neighborhood should prefer same row/column, not physical closeness.
        penalty += math.min(dy, dx * 0.95);
      }
      return penalty;
    }

    double gridPenalty() {
      var penalty = 0.0;
      for (final id in nodeOrder) {
        final p0 = positions[id];
        if (p0 == null) {
          continue;
        }
        final gx = snapToGrid(p0.dx, gridAnchorX, gridStepX);
        final gy = snapToGrid(p0.dy, gridAnchorY, gridStepY);
        penalty += (p0.dx - gx).abs() * 0.85;
        penalty += (p0.dy - gy).abs();
      }
      return penalty;
    }

    var currentNeighborPenalty = neighborAlignmentPenalty();
    var currentGridPenalty = gridPenalty();

    bool tryProposal(Map<String, Offset> proposal) {
      if (proposal.isEmpty) {
        return false;
      }
      final old = <String, Offset>{};
      for (final entry in proposal.entries) {
        old[entry.key] = positions[entry.key]!;
        positions[entry.key] = entry.value;
      }

      final candCrossings = _countEdgeCrossings(
        positions,
        sizeByNode,
        allEdges,
      );
      final candEdgeOverNode = _countEdgeOverBlockHits(
        nodeOrder,
        positions,
        sizeByNode,
        allEdges,
        minGap,
      );
      final candSubgraphViol = _countSubgraphMembershipViolations(
        nodeOrder: nodeOrder,
        positions: positions,
        sizeByNode: sizeByNode,
        subgraphNodeGroups: subgraphNodeGroups,
        minGap: minGap,
      );
      final candOverlapPairs = _countNodeOverlapPairs(
        nodeOrder: nodeOrder,
        positions: positions,
        sizeByNode: sizeByNode,
        minGap: minGap,
      );
      final candAlignScore = _edgeAlignmentScore(positions, sizeByNode);
      final candNeighborPenalty = neighborAlignmentPenalty();
      final candGridPenalty = gridPenalty();

      final guardsOk =
          candCrossings <= currentCrossings &&
          candEdgeOverNode <= currentEdgeOverNode &&
          candSubgraphViol <= currentSubgraphViol &&
          candOverlapPairs <= currentOverlapPairs;
      final alignImproved =
          candNeighborPenalty + 0.05 < currentNeighborPenalty ||
          candGridPenalty + 0.05 < currentGridPenalty ||
          candAlignScore > currentAlignScore + 0.05;

      if (guardsOk && alignImproved) {
        currentCrossings = candCrossings;
        currentEdgeOverNode = candEdgeOverNode;
        currentSubgraphViol = candSubgraphViol;
        currentOverlapPairs = candOverlapPairs;
        currentAlignScore = candAlignScore;
        currentNeighborPenalty = candNeighborPenalty;
        currentGridPenalty = candGridPenalty;
        movedDistance += proposal.entries
            .map((e) => (e.value - old[e.key]!).distance)
            .fold<double>(0.0, (s, v) => s + v);
        return true;
      }

      for (final entry in old.entries) {
        positions[entry.key] = entry.value;
      }
      rejectedByGuards++;
      return false;
    }

    // Spatial-neighbor-first alignment: align top edges, then left edges.
    final neighborPasses = (2 + p.round()).clamp(2, 5);
    for (int pass = 0; pass < neighborPasses; pass++) {
      neighborPairs = buildSpatialNeighborPairs();
      var movedThisPass = false;
      for (final pair in neighborPairs) {
        final a = pair.$1;
        final b = pair.$2;
        final pa = positions[a]!;
        final pb = positions[b]!;
        final topTarget = snapToGrid(
          (pa.dy + pb.dy) * 0.5,
          gridAnchorY,
          gridStepY,
        );
        final leftTarget = snapToGrid(
          (pa.dx + pb.dx) * 0.5,
          gridAnchorX,
          gridStepX,
        );
        final topBlend = ((0.72 + 0.12 * p) * localityScale).clamp(0.52, 1.0);
        final leftBlend = ((0.52 + 0.10 * p) * localityScale).clamp(0.42, 0.95);

        final topProposal = <String, Offset>{};
        final dAy = topTarget - pa.dy;
        final dBy = topTarget - pb.dy;
        if (dAy.abs() > 0.25) {
          topProposal[a] = Offset(pa.dx, pa.dy + dAy * topBlend);
        }
        if (dBy.abs() > 0.25) {
          topProposal[b] = Offset(pb.dx, pb.dy + dBy * topBlend);
        }
        if (tryProposal(topProposal)) {
          moves++;
          movedThisPass = true;
        }

        final pa2 = positions[a]!;
        final pb2 = positions[b]!;
        final leftProposal = <String, Offset>{};
        final dAx = leftTarget - pa2.dx;
        final dBx = leftTarget - pb2.dx;
        if (dAx.abs() > 0.25) {
          leftProposal[a] = Offset(pa2.dx + dAx * leftBlend, pa2.dy);
        }
        if (dBx.abs() > 0.25) {
          leftProposal[b] = Offset(pb2.dx + dBx * leftBlend, pb2.dy);
        }
        if (tryProposal(leftProposal)) {
          moves++;
          movedThisPass = true;
        }
      }
      if (!movedThisPass) {
        break;
      }
    }

    final snapPasses = (1 + snapW.round()).clamp(1, 4);
    final snapBlend = ((0.35 + 0.12 * p + 0.10 * snapW) * localityScale).clamp(
      0.22,
      0.90,
    );
    for (int pass = 0; pass < snapPasses; pass++) {
      var movedThisPass = false;
      for (final id in nodeOrder) {
        final pos = positions[id];
        if (pos == null) {
          continue;
        }
        final gx = snapToGrid(pos.dx, gridAnchorX, gridStepX);
        final gy = snapToGrid(pos.dy, gridAnchorY, gridStepY);
        final dx = gx - pos.dx;
        final dy = gy - pos.dy;
        if (dx.abs() < 0.25 && dy.abs() < 0.25) {
          continue;
        }
        final proposal = Offset(
          pos.dx + dx * snapBlend,
          pos.dy + dy * snapBlend,
        );
        if (tryProposal({id: proposal})) {
          moves++;
          movedThisPass = true;
        }
      }
      if (!movedThisPass) {
        break;
      }
    }

    int applyAxis(bool alignTop) {
      final tuples = <({String id, double value})>[];
      for (final id in nodeOrder) {
        final pos = positions[id];
        if (pos == null) {
          continue;
        }
        tuples.add((id: id, value: alignTop ? pos.dy : pos.dx));
      }
      tuples.sort((a, b) => a.value.compareTo(b.value));

      var axisMoves = 0;
      int start = 0;
      while (start < tuples.length) {
        int end = start + 1;
        while (end < tuples.length &&
            (tuples[end].value - tuples[start].value) <= tolerance) {
          end++;
        }

        if (end - start >= 2) {
          final window = tuples.sublist(start, end);
          final values = window.map((e) => e.value).toList()..sort();
          final target = values[values.length ~/ 2];

          for (final item in window) {
            final oldPos = positions[item.id]!;
            final delta = target - item.value;
            if (delta.abs() <= minShift) {
              continue;
            }
            final shift = delta * blend;
            final candidatePos = alignTop
                ? Offset(oldPos.dx, oldPos.dy + shift)
                : Offset(oldPos.dx + shift, oldPos.dy);
            if (tryProposal({item.id: candidatePos})) {
              axisMoves++;
            } else {
              // proposal rejected by hard guards or no alignment gain
            }
          }
        }

        start = end;
      }

      return axisMoves;
    }

    for (int pass = 0; pass < passes; pass++) {
      moves += applyAxis(true);
      moves += applyAxis(false);
    }

    _logAudit(
      'stage=axis_align_done moves=$moves movedDistance=${movedDistance.toStringAsFixed(2)} rejectedByGuards=$rejectedByGuards crossings=$currentCrossings edgeOverNode=$currentEdgeOverNode neighborPenalty=${currentNeighborPenalty.toStringAsFixed(2)} gridPenalty=${currentGridPenalty.toStringAsFixed(2)}',
    );
  }

  static void _clearEdgePathOverBlockOverlaps({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required double minGap,
    required String direction,
    required double seededAlignmentPriority,
    bool strictMode = false,
  }) {
    if (nodeOrder.length < 3 || allEdges.isEmpty) {
      _logAudit('stage=edge_path_clearance skipped=insufficient_graph');
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    final primaryBlend = strictMode
        ? (seededAlignmentPriority >= 1.8 ? 0.70 : 0.56)
        : (seededAlignmentPriority >= 1.8 ? 0.75 : 0.62);
    final step = ((minGap * 0.62 + 12.0) * (strictMode ? 1.22 : 1.0)).clamp(
      10.0,
      72.0,
    );
    final inflation = ((minGap * 0.42) * (strictMode ? 1.25 : 1.0)).clamp(
      8.0,
      96.0,
    );

    var hits = 0;
    var moves = 0;
    var rejected = 0;

    final maxPasses = strictMode ? 24 : 14;
    for (int pass = 0; pass < maxPasses; pass++) {
      final rectByNode = <String, Rect>{
        for (final id in nodeOrder)
          id: Rect.fromLTWH(
            positions[id]!.dx,
            positions[id]!.dy,
            sizeByNode[id]!.width,
            sizeByNode[id]!.height,
          ),
      };

      var movedThisPass = 0;
      var hitsThisPass = 0;
      for (final edge in allEdges) {
        final a = edge.$1;
        final b = edge.$2;
        final p1 = _nodeCenter(positions[a]!, sizeByNode[a]!);
        final p2 = _nodeCenter(positions[b]!, sizeByNode[b]!);
        final seg = p2 - p1;
        final segLen2 = seg.dx * seg.dx + seg.dy * seg.dy;
        if (segLen2 <= 1e-6) {
          continue;
        }

        for (final id in nodeOrder) {
          if (id == a || id == b) {
            continue;
          }
          final expanded = rectByNode[id]!.inflate(inflation);
          if (!_segmentIntersectsRect(p1, p2, expanded)) {
            continue;
          }

          hitsThisPass++;
          final oldPos = positions[id]!;
          final center = _nodeCenter(oldPos, sizeByNode[id]!);
          final t =
              (((center.dx - p1.dx) * seg.dx) +
                  ((center.dy - p1.dy) * seg.dy)) /
              segLen2;
          final clampedT = t.clamp(0.0, 1.0);
          final closest = Offset(
            p1.dx + seg.dx * clampedT,
            p1.dy + seg.dy * clampedT,
          );
          var push = center - closest;
          if (push.distanceSquared <= 1e-6) {
            push = Offset(-seg.dy, seg.dx);
          }

          final normalized = push / math.max(1e-6, push.distance);
          var biased = flowHorizontal
              ? Offset(normalized.dx * primaryBlend, normalized.dy)
              : Offset(normalized.dx, normalized.dy * primaryBlend);
          if (biased.distanceSquared <= 1e-6) {
            biased = normalized;
          }
          final dir = biased / math.max(1e-6, biased.distance);

          final baseline = _routingObjective(
            nodeOrder: nodeOrder,
            positions: positions,
            sizeByNode: sizeByNode,
            allEdges: allEdges,
            minGap: minGap,
          );
          final baselineEdgeOver = _countEdgeOverBlockHits(
            nodeOrder,
            positions,
            sizeByNode,
            allEdges,
            minGap,
          );
          positions[id] = oldPos + dir * step;
          final candidate = _routingObjective(
            nodeOrder: nodeOrder,
            positions: positions,
            sizeByNode: sizeByNode,
            allEdges: allEdges,
            minGap: minGap,
          );
          final candidateEdgeOver = _countEdgeOverBlockHits(
            nodeOrder,
            positions,
            sizeByNode,
            allEdges,
            minGap,
          );

          final objectiveAccepted = candidate <= baseline + 1e-6;
          final strictEdgeOverAccepted =
              strictMode &&
              candidateEdgeOver < baselineEdgeOver &&
              candidate <= baseline * 1.10 + 1200.0;

          if (objectiveAccepted || strictEdgeOverAccepted) {
            movedThisPass++;
          } else {
            positions[id] = oldPos;
            rejected++;
          }
        }
      }

      hits += hitsThisPass;
      moves += movedThisPass;
      if (hitsThisPass == 0 || movedThisPass == 0) {
        break;
      }
    }

    _logAudit(
      'stage=edge_path_clearance hits=$hits moves=$moves rejected=$rejected step=${step.toStringAsFixed(1)} inflation=${inflation.toStringAsFixed(1)} flow=$direction primaryBlend=${primaryBlend.toStringAsFixed(2)} strict=${strictMode ? 'true' : 'false'}',
    );
  }

  static int _countEdgeCrossings(
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

  static int _countNodeOverlapPairs({
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

  static int _countEdgeOverBlockHits(
    List<String> nodeOrder,
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
    List<(String, String)> allEdges,
    double minGap,
  ) {
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
          hits++;
        }
      }
    }

    return hits;
  }

  static int _countSubgraphMembershipViolations({
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
    final groupSets = [for (final g in subgraphNodeGroups) g.toSet()];
    final nodeGroupIndices = <String, List<int>>{};
    for (int gi = 0; gi < subgraphNodeGroups.length; gi++) {
      for (final id in subgraphNodeGroups[gi]) {
        nodeGroupIndices.putIfAbsent(id, () => <int>[]).add(gi);
      }
    }
    final pad = _subgraphExclusionGap(minGap);

    for (int i = 0; i < subgraphNodeGroups.length; i++) {
      final members = groupSets[i];
      final bounds = _subgraphBounds(
        subgraphNodeGroups[i],
        positions,
        sizeByNode,
        padding: pad,
      );

      for (final id in nodeOrder) {
        if (members.contains(id)) {
          continue;
        }
        final ownerGroups = nodeGroupIndices[id] ?? const <int>[];
        var skip = false;
        for (final otherGi in ownerGroups) {
          final ownerMembers = groupSets[otherGi];
          final ownerIsDescendantOrEqual = members.containsAll(ownerMembers);
          if (ownerIsDescendantOrEqual) {
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
        final ow =
            math.min(r.right, bounds.right) - math.max(r.left, bounds.left);
        final oh =
            math.min(r.bottom, bounds.bottom) - math.max(r.top, bounds.top);
        if (ow > 0 && oh > 0) {
          violations++;
        }
      }
    }

    return violations;
  }

  static int _countSubgraphNearBoundaryContacts({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
  }) {
    if (subgraphNodeGroups.isEmpty) {
      return 0;
    }

    var contacts = 0;
    final groupSets = [for (final g in subgraphNodeGroups) g.toSet()];
    final nodeGroupIndices = <String, List<int>>{};
    for (int gi = 0; gi < subgraphNodeGroups.length; gi++) {
      for (final id in subgraphNodeGroups[gi]) {
        nodeGroupIndices.putIfAbsent(id, () => <int>[]).add(gi);
      }
    }

    final pad = (_subgraphExclusionGap(minGap) + minGap * 0.20 + 6.0).clamp(
      20.0,
      100.0,
    );

    for (int i = 0; i < subgraphNodeGroups.length; i++) {
      final members = groupSets[i];
      final bounds = _subgraphBounds(
        subgraphNodeGroups[i],
        positions,
        sizeByNode,
        padding: pad,
      );

      for (final id in nodeOrder) {
        if (members.contains(id)) {
          continue;
        }
        final ownerGroups = nodeGroupIndices[id] ?? const <int>[];
        var skip = false;
        for (final otherGi in ownerGroups) {
          final ownerMembers = groupSets[otherGi];
          final ownerIsDescendantOrEqual = members.containsAll(ownerMembers);
          if (ownerIsDescendantOrEqual) {
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
        final ow =
            math.min(r.right, bounds.right) - math.max(r.left, bounds.left);
        final oh =
            math.min(r.bottom, bounds.bottom) - math.max(r.top, bounds.top);
        if (ow > 0 && oh > 0) {
          contacts++;
        }
      }
    }

    return contacts;
  }

  static double _routingObjective({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required double minGap,
  }) {
    final crossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    final overlapPairs = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );
    final edgeOverNode = _countEdgeOverBlockHits(
      nodeOrder,
      positions,
      sizeByNode,
      allEdges,
      minGap,
    );
    final subgraphViolations = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: const <List<String>>[],
      minGap: minGap,
    );
    final edgeLength = _totalEdgeLength(positions, sizeByNode, allEdges);

    return crossings * 1000000.0 +
        edgeOverNode * 220000.0 +
        overlapPairs * 12000.0 +
        subgraphViolations * 180000.0 +
        edgeLength * 0.04;
  }

  static void _reduceEdgeCrossings({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required String direction,
    required double minGap,
    required String stageTag,
  }) {
    if (allEdges.length < 2) {
      _logAudit('stage=edge_crossing_reduce_$stageTag skipped=too_few_edges');
      return;
    }
    if (allEdges.length > 220 || nodeOrder.length > 260) {
      _logAudit(
        'stage=edge_crossing_reduce_$stageTag skipped=graph_too_large edges=${allEdges.length} nodes=${nodeOrder.length}',
      );
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    final nudge = (minGap * 0.30 + 10.0).clamp(10.0, 40.0);

    var currentCrossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    var currentOverlaps = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );
    if (currentCrossings == 0) {
      _logAudit('stage=edge_crossing_reduce_$stageTag skipped=no_crossings');
      return;
    }

    var acceptedMoves = 0;
    const maxPasses = 20;
    for (int pass = 0; pass < maxPasses; pass++) {
      var improvedThisPass = false;

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
          if (!_segmentsIntersect(p1, p2, p3, p4)) {
            continue;
          }

          final edge1Len = (p2 - p1).distance;
          final edge2Len = (p4 - p3).distance;
          final moveEdge1 = edge1Len <= edge2Len;
          final edgeToMove = moveEdge1 ? e1 : e2;
          final moveCenter = moveEdge1
              ? _meanOffset([p1, p2])
              : _meanOffset([p3, p4]);
          final otherCenter = moveEdge1
              ? _meanOffset([p3, p4])
              : _meanOffset([p1, p2]);
          final signRef = flowHorizontal
              ? (moveCenter.dy >= otherCenter.dy ? 1.0 : -1.0)
              : (moveCenter.dx >= otherCenter.dx ? 1.0 : -1.0);

          final orthoPositive = flowHorizontal
              ? Offset(0, signRef * nudge)
              : Offset(signRef * nudge, 0);
          final orthoNegative = flowHorizontal
              ? Offset(0, -signRef * nudge)
              : Offset(-signRef * nudge, 0);

          final plans = <({String idA, String idB, Offset dA, Offset dB})>[
            (
              idA: edgeToMove.$1,
              idB: edgeToMove.$2,
              dA: orthoPositive,
              dB: orthoPositive,
            ),
            (
              idA: edgeToMove.$1,
              idB: edgeToMove.$2,
              dA: orthoNegative,
              dB: orthoNegative,
            ),
            (
              idA: edgeToMove.$1,
              idB: edgeToMove.$2,
              dA: orthoPositive * 0.85,
              dB: Offset.zero,
            ),
            (
              idA: edgeToMove.$1,
              idB: edgeToMove.$2,
              dA: orthoNegative * 0.85,
              dB: Offset.zero,
            ),
            (
              idA: edgeToMove.$1,
              idB: edgeToMove.$2,
              dA: Offset.zero,
              dB: orthoPositive * 0.85,
            ),
            (
              idA: edgeToMove.$1,
              idB: edgeToMove.$2,
              dA: Offset.zero,
              dB: orthoNegative * 0.85,
            ),
          ];

          var bestPlan = -1;
          var bestCross = currentCrossings;
          var bestOver = currentOverlaps;

          for (int k = 0; k < plans.length; k++) {
            final plan = plans[k];
            final oldA = positions[plan.idA]!;
            final oldB = positions[plan.idB]!;
            positions[plan.idA] = oldA + plan.dA;
            positions[plan.idB] = oldB + plan.dB;

            final c = _countEdgeCrossings(positions, sizeByNode, allEdges);
            final o = _countNodeOverlapPairs(
              nodeOrder: nodeOrder,
              positions: positions,
              sizeByNode: sizeByNode,
              minGap: minGap,
            );

            final crossingImproved = c < currentCrossings;
            final overlapBudget = crossingImproved
                ? currentOverlaps + 3
                : currentOverlaps;
            final withinBudget = o <= overlapBudget;
            final better = c < bestCross || (c == bestCross && o < bestOver);
            if (withinBudget && better) {
              bestPlan = k;
              bestCross = c;
              bestOver = o;
            }

            positions[plan.idA] = oldA;
            positions[plan.idB] = oldB;
          }

          final improved =
              bestPlan >= 0 &&
              (bestCross < currentCrossings ||
                  (bestCross == currentCrossings &&
                      bestOver < currentOverlaps));
          if (improved) {
            final plan = plans[bestPlan];
            positions[plan.idA] = positions[plan.idA]! + plan.dA;
            positions[plan.idB] = positions[plan.idB]! + plan.dB;
            currentCrossings = bestCross;
            currentOverlaps = bestOver;
            acceptedMoves++;
            improvedThisPass = true;
            break;
          }
        }

        if (improvedThisPass || currentCrossings == 0) {
          break;
        }
      }

      if (!improvedThisPass || currentCrossings == 0) {
        break;
      }
    }

    _logAudit(
      'stage=edge_crossing_reduce_$stageTag crossings=$currentCrossings acceptedMoves=$acceptedMoves nudge=${nudge.toStringAsFixed(1)}',
    );
  }

  static void _repairRoutingByNodeMoves({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required String direction,
    required double minGap,
    required String stageTag,
  }) {
    if (allEdges.length < 2 || nodeOrder.length < 3) {
      _logAudit('stage=routing_repair_$stageTag skipped=insufficient_graph');
      return;
    }
    if (allEdges.length > 260 || nodeOrder.length > 180) {
      _logAudit(
        'stage=routing_repair_$stageTag skipped=graph_too_large edges=${allEdges.length} nodes=${nodeOrder.length}',
      );
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    final primaryStep = (minGap * 0.45 + 12.0).clamp(14.0, 72.0);
    final crossStep = (primaryStep * 1.6).clamp(20.0, 110.0);
    final sideStep = (primaryStep * 0.70).clamp(10.0, 52.0);

    var objective = _routingObjective(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
    );
    var crossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    var acceptedMoves = 0;

    final sortedNodes = [...nodeOrder]
      ..sort((a, b) {
        final byDeg = (degree[a] ?? 0).compareTo(degree[b] ?? 0);
        if (byDeg != 0) {
          return byDeg;
        }
        return a.compareTo(b);
      });

    const maxPasses = 18;
    for (int pass = 0; pass < maxPasses; pass++) {
      var improved = false;

      for (final id in sortedNodes) {
        final oldPos = positions[id]!;
        final candidates = <Offset>[
          if (flowHorizontal) ...[
            Offset(0, crossStep),
            Offset(0, -crossStep),
            Offset(sideStep, 0),
            Offset(-sideStep, 0),
            Offset(sideStep, crossStep * 0.65),
            Offset(-sideStep, -crossStep * 0.65),
          ] else ...[
            Offset(crossStep, 0),
            Offset(-crossStep, 0),
            Offset(0, sideStep),
            Offset(0, -sideStep),
            Offset(crossStep * 0.65, sideStep),
            Offset(-crossStep * 0.65, -sideStep),
          ],
        ];

        var bestPos = oldPos;
        var bestObjective = objective;
        var bestCross = crossings;

        for (final delta in candidates) {
          positions[id] = oldPos + delta;
          final c = _countEdgeCrossings(positions, sizeByNode, allEdges);
          final s = _routingObjective(
            nodeOrder: nodeOrder,
            positions: positions,
            sizeByNode: sizeByNode,
            allEdges: allEdges,
            minGap: minGap,
          );

          final crossingImproved = c < bestCross;
          final objectiveImproved = c == bestCross && s + 1e-6 < bestObjective;
          if (crossingImproved || objectiveImproved) {
            bestCross = c;
            bestObjective = s;
            bestPos = positions[id]!;
          }
        }

        positions[id] = oldPos;
        if (bestPos != oldPos) {
          positions[id] = bestPos;
          crossings = bestCross;
          objective = bestObjective;
          acceptedMoves++;
          improved = true;
          if (crossings == 0) {
            break;
          }
        }
      }

      if (!improved || crossings == 0) {
        break;
      }
    }

    _logAudit(
      'stage=routing_repair_$stageTag crossings=$crossings acceptedMoves=$acceptedMoves objective=${objective.toStringAsFixed(1)} step=(${primaryStep.toStringAsFixed(1)},${crossStep.toStringAsFixed(1)})',
    );
  }

  static void _forceUncrossByEndpointKick({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required String direction,
    required double minGap,
    required String stageTag,
  }) {
    if (allEdges.length < 2 || nodeOrder.length < 3) {
      _logAudit('stage=force_uncross_$stageTag skipped=insufficient_graph');
      return;
    }
    if (allEdges.length > 260 || nodeOrder.length > 220) {
      _logAudit(
        'stage=force_uncross_$stageTag skipped=graph_too_large edges=${allEdges.length} nodes=${nodeOrder.length}',
      );
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    final crossStep = (minGap * 0.80 + 30.0).clamp(24.0, 130.0);
    final sideStep = (crossStep * 0.35).clamp(8.0, 44.0);

    var crossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    var objective = _routingObjective(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
    );

    if (crossings == 0) {
      _logAudit('stage=force_uncross_$stageTag skipped=no_crossings');
      return;
    }

    var acceptedMoves = 0;
    const maxPasses = 28;
    for (int pass = 0; pass < maxPasses; pass++) {
      String? bestNode;
      Offset bestDelta = Offset.zero;
      var bestCross = crossings;
      var bestObj = objective;

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
          if (!_segmentsIntersect(p1, p2, p3, p4)) {
            continue;
          }

          final crossingCenter = _meanOffset([p1, p2, p3, p4]);
          final endpoints = <String>[e1.$1, e1.$2, e2.$1, e2.$2]
            ..sort((a, b) {
              final byDeg = (degree[a] ?? 0).compareTo(degree[b] ?? 0);
              if (byDeg != 0) {
                return byDeg;
              }
              return a.compareTo(b);
            });

          for (final id in endpoints) {
            final c = _nodeCenter(positions[id]!, sizeByNode[id]!);
            final sign = flowHorizontal
                ? (c.dy >= crossingCenter.dy ? 1.0 : -1.0)
                : (c.dx >= crossingCenter.dx ? 1.0 : -1.0);
            final deltas = <Offset>[
              if (flowHorizontal) ...[
                Offset(0, sign * crossStep),
                Offset(0, -sign * crossStep),
                Offset(sideStep, sign * crossStep * 0.72),
                Offset(-sideStep, -sign * crossStep * 0.72),
              ] else ...[
                Offset(sign * crossStep, 0),
                Offset(-sign * crossStep, 0),
                Offset(sign * crossStep * 0.72, sideStep),
                Offset(-sign * crossStep * 0.72, -sideStep),
              ],
            ];

            final old = positions[id]!;
            for (final delta in deltas) {
              positions[id] = old + delta;
              final candCross = _countEdgeCrossings(
                positions,
                sizeByNode,
                allEdges,
              );
              final candObj = _routingObjective(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                allEdges: allEdges,
                minGap: minGap,
              );

              final betterCross = candCross < bestCross;
              final tieBetterObj =
                  candCross == bestCross && candObj + 1e-6 < bestObj;
              if (betterCross || tieBetterObj) {
                bestNode = id;
                bestDelta = delta;
                bestCross = candCross;
                bestObj = candObj;
              }
            }
            positions[id] = old;
          }
        }
      }

      final improved =
          bestNode != null &&
          (bestCross < crossings ||
              (bestCross == crossings && bestObj + 1e-6 < objective));
      if (!improved) {
        break;
      }

      final chosen = bestNode;
      positions[chosen] = positions[chosen]! + bestDelta;
      crossings = bestCross;
      objective = bestObj;
      acceptedMoves++;
      if (crossings == 0) {
        break;
      }
    }

    _logAudit(
      'stage=force_uncross_$stageTag crossings=$crossings acceptedMoves=$acceptedMoves step=${crossStep.toStringAsFixed(1)}',
    );
  }

  static void _finalCrossingEscape({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required String direction,
    required double minGap,
    required List<List<String>> subgraphNodeGroups,
  }) {
    if (allEdges.length < 2 || nodeOrder.length < 3) {
      _logAudit('stage=final_crossing_escape skipped=insufficient_graph');
      return;
    }
    if (nodeOrder.length > 24 || allEdges.length > 40) {
      _logAudit(
        'stage=final_crossing_escape skipped=graph_too_large nodes=${nodeOrder.length} edges=${allEdges.length}',
      );
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    var currentCrossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    var currentEdgeOver = _countEdgeOverBlockHits(
      nodeOrder,
      positions,
      sizeByNode,
      allEdges,
      minGap,
    );
    var currentOverlapPairs = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );
    var currentSubgraphViol = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
    );
    var currentObjective = _routingObjective(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
    );

    if (currentCrossings == 0) {
      _logAudit('stage=final_crossing_escape skipped=no_crossings');
      return;
    }

    final kick = (minGap * 1.35 + 44.0).clamp(36.0, 180.0);
    final side = (kick * 0.40).clamp(12.0, 64.0);
    var acceptedMoves = 0;
    const maxPasses = 20;

    bool isBetter({
      required int cross,
      required int edgeOver,
      required int subgraphViol,
      required int overlapPairs,
      required double objective,
      required int refCross,
      required int refEdgeOver,
      required int refSubgraphViol,
      required int refOverlapPairs,
      required double refObjective,
    }) {
      if (cross != refCross) {
        return cross < refCross;
      }
      if (edgeOver != refEdgeOver) {
        return edgeOver < refEdgeOver;
      }
      if (subgraphViol != refSubgraphViol) {
        return subgraphViol < refSubgraphViol;
      }
      if (overlapPairs != refOverlapPairs) {
        return overlapPairs < refOverlapPairs;
      }
      return objective + 1e-6 < refObjective;
    }

    for (int pass = 0; pass < maxPasses; pass++) {
      String? bestNode;
      Offset bestDelta = Offset.zero;
      var bestCross = currentCrossings;
      var bestEdgeOver = currentEdgeOver;
      var bestSubgraphViol = currentSubgraphViol;
      var bestOverlap = currentOverlapPairs;
      var bestObjective = currentObjective;

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
          if (!_segmentsIntersect(p1, p2, p3, p4)) {
            continue;
          }

          final crossingCenter = _meanOffset([p1, p2, p3, p4]);
          final endpoints = <String>[e1.$1, e1.$2, e2.$1, e2.$2]
            ..sort((a, b) {
              final byDeg = (degree[a] ?? 0).compareTo(degree[b] ?? 0);
              if (byDeg != 0) {
                return byDeg;
              }
              return a.compareTo(b);
            });

          for (final id in endpoints) {
            final c = _nodeCenter(positions[id]!, sizeByNode[id]!);
            final sign = flowHorizontal
                ? (c.dy >= crossingCenter.dy ? 1.0 : -1.0)
                : (c.dx >= crossingCenter.dx ? 1.0 : -1.0);
            final candidates = <Offset>[
              if (flowHorizontal) ...[
                Offset(0, sign * kick),
                Offset(0, -sign * kick),
                Offset(side, sign * kick * 0.7),
                Offset(-side, -sign * kick * 0.7),
              ] else ...[
                Offset(sign * kick, 0),
                Offset(-sign * kick, 0),
                Offset(sign * kick * 0.7, side),
                Offset(-sign * kick * 0.7, -side),
              ],
            ];

            final old = positions[id]!;
            for (final delta in candidates) {
              positions[id] = old + delta;

              final candSubViol = _countSubgraphMembershipViolations(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                subgraphNodeGroups: subgraphNodeGroups,
                minGap: minGap,
              );
              if (candSubViol > currentSubgraphViol) {
                continue;
              }

              final candCross = _countEdgeCrossings(
                positions,
                sizeByNode,
                allEdges,
              );
              final candEdgeOver = _countEdgeOverBlockHits(
                nodeOrder,
                positions,
                sizeByNode,
                allEdges,
                minGap,
              );
              final candOverlap = _countNodeOverlapPairs(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                minGap: minGap,
              );
              final candObjective = _routingObjective(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                allEdges: allEdges,
                minGap: minGap,
              );

              if (isBetter(
                cross: candCross,
                edgeOver: candEdgeOver,
                subgraphViol: candSubViol,
                overlapPairs: candOverlap,
                objective: candObjective,
                refCross: bestCross,
                refEdgeOver: bestEdgeOver,
                refSubgraphViol: bestSubgraphViol,
                refOverlapPairs: bestOverlap,
                refObjective: bestObjective,
              )) {
                bestNode = id;
                bestDelta = delta;
                bestCross = candCross;
                bestEdgeOver = candEdgeOver;
                bestSubgraphViol = candSubViol;
                bestOverlap = candOverlap;
                bestObjective = candObjective;
              }
            }
            positions[id] = old;
          }
        }
      }

      final improved =
          bestNode != null &&
          isBetter(
            cross: bestCross,
            edgeOver: bestEdgeOver,
            subgraphViol: bestSubgraphViol,
            overlapPairs: bestOverlap,
            objective: bestObjective,
            refCross: currentCrossings,
            refEdgeOver: currentEdgeOver,
            refSubgraphViol: currentSubgraphViol,
            refOverlapPairs: currentOverlapPairs,
            refObjective: currentObjective,
          );

      if (!improved) {
        break;
      }

      final chosen = bestNode;
      positions[chosen] = positions[chosen]! + bestDelta;
      currentCrossings = bestCross;
      currentEdgeOver = bestEdgeOver;
      currentSubgraphViol = bestSubgraphViol;
      currentOverlapPairs = bestOverlap;
      currentObjective = bestObjective;
      acceptedMoves++;

      if (currentCrossings == 0) {
        break;
      }
    }

    _logAudit(
      'stage=final_crossing_escape crossings=$currentCrossings edgeOverNode=$currentEdgeOver subgraphViol=$currentSubgraphViol acceptedMoves=$acceptedMoves kick=${kick.toStringAsFixed(1)}',
    );
  }

  static void _hardStopNoCrossingSmallGraph({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required String direction,
    required double minGap,
    required List<List<String>> subgraphNodeGroups,
  }) {
    if (allEdges.length < 2 || nodeOrder.length < 3) {
      _logAudit('stage=hard_stop_no_crossing skipped=insufficient_graph');
      return;
    }
    if (nodeOrder.length > 24 || allEdges.length > 40) {
      _logAudit(
        'stage=hard_stop_no_crossing skipped=graph_too_large nodes=${nodeOrder.length} edges=${allEdges.length}',
      );
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    var currentCross = _countEdgeCrossings(positions, sizeByNode, allEdges);
    if (currentCross == 0) {
      _logAudit('stage=hard_stop_no_crossing skipped=no_crossings');
      return;
    }

    var currentEdgeOver = _countEdgeOverBlockHits(
      nodeOrder,
      positions,
      sizeByNode,
      allEdges,
      minGap,
    );
    var currentSubgraphViol = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
    );
    var currentOverlap = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );

    final crossKick = (minGap * 1.75 + 70.0).clamp(64.0, 260.0);
    final sideKick = (crossKick * 0.42).clamp(14.0, 84.0);
    var accepted = 0;
    const maxPasses = 24;

    for (int pass = 0; pass < maxPasses; pass++) {
      String? bestNode;
      Offset bestDelta = Offset.zero;
      var bestCross = currentCross;
      var bestEdgeOver = currentEdgeOver;
      var bestSubgraphViol = currentSubgraphViol;
      var bestOverlap = currentOverlap;

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
          if (!_segmentsIntersect(p1, p2, p3, p4)) {
            continue;
          }

          final crossingCenter = _meanOffset([p1, p2, p3, p4]);
          final endpoints = <String>[e1.$1, e1.$2, e2.$1, e2.$2]
            ..sort((a, b) {
              final byDeg = (degree[a] ?? 0).compareTo(degree[b] ?? 0);
              if (byDeg != 0) {
                return byDeg;
              }
              return a.compareTo(b);
            });

          for (final id in endpoints) {
            final c = _nodeCenter(positions[id]!, sizeByNode[id]!);
            final sign = flowHorizontal
                ? (c.dy >= crossingCenter.dy ? 1.0 : -1.0)
                : (c.dx >= crossingCenter.dx ? 1.0 : -1.0);

            final candidates = <Offset>[
              if (flowHorizontal) ...[
                Offset(0, sign * crossKick),
                Offset(0, -sign * crossKick),
                Offset(0, sign * crossKick * 1.35),
                Offset(0, -sign * crossKick * 1.35),
                Offset(sideKick, sign * crossKick * 0.72),
                Offset(-sideKick, -sign * crossKick * 0.72),
                Offset(sideKick, 0),
                Offset(-sideKick, 0),
              ] else ...[
                Offset(sign * crossKick, 0),
                Offset(-sign * crossKick, 0),
                Offset(sign * crossKick * 1.35, 0),
                Offset(-sign * crossKick * 1.35, 0),
                Offset(sign * crossKick * 0.72, sideKick),
                Offset(-sign * crossKick * 0.72, -sideKick),
                Offset(0, sideKick),
                Offset(0, -sideKick),
              ],
            ];

            final old = positions[id]!;
            for (final delta in candidates) {
              positions[id] = old + delta;
              final candSubgraphViol = _countSubgraphMembershipViolations(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                subgraphNodeGroups: subgraphNodeGroups,
                minGap: minGap,
              );
              final candEdgeOver = _countEdgeOverBlockHits(
                nodeOrder,
                positions,
                sizeByNode,
                allEdges,
                minGap,
              );
              final candOverlap = _countNodeOverlapPairs(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                minGap: minGap,
              );
              final candCross = _countEdgeCrossings(
                positions,
                sizeByNode,
                allEdges,
              );

              final guardOk =
                  candSubgraphViol <= currentSubgraphViol + 1 &&
                  candEdgeOver <= currentEdgeOver + 1;
              final better =
                  candCross < bestCross ||
                  (candCross == bestCross &&
                      (candEdgeOver < bestEdgeOver ||
                          (candEdgeOver == bestEdgeOver &&
                              candSubgraphViol < bestSubgraphViol)));

              if (guardOk && better) {
                bestNode = id;
                bestDelta = delta;
                bestCross = candCross;
                bestEdgeOver = candEdgeOver;
                bestSubgraphViol = candSubgraphViol;
                bestOverlap = candOverlap;
              }
            }
            positions[id] = old;
          }
        }
      }

      final improved = bestNode != null && bestCross < currentCross;
      if (improved) {
        final chosen = bestNode;
        positions[chosen] = positions[chosen]! + bestDelta;
        currentCross = bestCross;
        currentEdgeOver = bestEdgeOver;
        currentSubgraphViol = bestSubgraphViol;
        currentOverlap = bestOverlap;
        accepted++;
      } else {
        final laneMove = _applyCrossingPairLaneMove(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          allEdges: allEdges,
          degree: degree,
          direction: direction,
          minGap: minGap,
          subgraphNodeGroups: subgraphNodeGroups,
          currentCrossings: currentCross,
          currentEdgeOver: currentEdgeOver,
          currentSubgraphViol: currentSubgraphViol,
        );
        if (!laneMove.moved) {
          break;
        }
        currentCross = laneMove.crossings;
        currentEdgeOver = laneMove.edgeOverNode;
        currentSubgraphViol = laneMove.subgraphViol;
        currentOverlap = _countNodeOverlapPairs(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          minGap: minGap,
        );
        accepted += laneMove.moves;
      }

      if (currentCross == 0) {
        break;
      }
    }

    _logAudit(
      'stage=hard_stop_no_crossing crossings=$currentCross edgeOverNode=$currentEdgeOver subgraphViol=$currentSubgraphViol acceptedMoves=$accepted kick=${crossKick.toStringAsFixed(1)}',
    );
  }

  static void _gridSearchUncrossSmallGraph({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required String direction,
    required double minGap,
    required List<List<String>> subgraphNodeGroups,
  }) {
    if (allEdges.length < 2 || nodeOrder.length < 3) {
      _logAudit('stage=grid_uncross skipped=insufficient_graph');
      return;
    }
    if (nodeOrder.length > 24 || allEdges.length > 40) {
      _logAudit(
        'stage=grid_uncross skipped=graph_too_large nodes=${nodeOrder.length} edges=${allEdges.length}',
      );
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    var currentCross = _countEdgeCrossings(positions, sizeByNode, allEdges);
    if (currentCross == 0) {
      _logAudit('stage=grid_uncross skipped=no_crossings');
      return;
    }

    var currentEdgeOver = _countEdgeOverBlockHits(
      nodeOrder,
      positions,
      sizeByNode,
      allEdges,
      minGap,
    );
    var currentSubViol = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
    );
    var currentOverlap = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );

    final laneStep = (minGap * 1.4 + 56.0).clamp(48.0, 180.0);
    final sideStep = (laneStep * 0.38).clamp(12.0, 72.0);
    final candidatesByNode = [...nodeOrder]
      ..sort((a, b) {
        final byDeg = (degree[a] ?? 0).compareTo(degree[b] ?? 0);
        if (byDeg != 0) {
          return byDeg;
        }
        return a.compareTo(b);
      });

    var accepted = 0;
    const maxPasses = 12;
    for (int pass = 0; pass < maxPasses; pass++) {
      String? bestNode;
      Offset bestPos = Offset.zero;
      var bestCross = currentCross;
      var bestEdgeOver = currentEdgeOver;
      var bestSubViol = currentSubViol;
      var bestOverlap = currentOverlap;

      for (final id in candidatesByNode) {
        final old = positions[id]!;
        final size = sizeByNode[id]!;
        final oldCenter = _nodeCenter(old, size);

        final trials = <Offset>[old];
        for (int k = 1; k <= 3; k++) {
          final lane = laneStep * k;
          if (flowHorizontal) {
            trials.add(Offset(old.dx, old.dy + lane));
            trials.add(Offset(old.dx, old.dy - lane));
            trials.add(Offset(old.dx + sideStep * k, old.dy + lane * 0.7));
            trials.add(Offset(old.dx - sideStep * k, old.dy - lane * 0.7));
          } else {
            trials.add(Offset(old.dx + lane, old.dy));
            trials.add(Offset(old.dx - lane, old.dy));
            trials.add(Offset(old.dx + lane * 0.7, old.dy + sideStep * k));
            trials.add(Offset(old.dx - lane * 0.7, old.dy - sideStep * k));
          }
        }

        for (final trial in trials) {
          if (trial == old) {
            continue;
          }
          positions[id] = trial;

          final candCross = _countEdgeCrossings(
            positions,
            sizeByNode,
            allEdges,
          );
          final candSubViol = _countSubgraphMembershipViolations(
            nodeOrder: nodeOrder,
            positions: positions,
            sizeByNode: sizeByNode,
            subgraphNodeGroups: subgraphNodeGroups,
            minGap: minGap,
          );
          final candEdgeOver = _countEdgeOverBlockHits(
            nodeOrder,
            positions,
            sizeByNode,
            allEdges,
            minGap,
          );
          final candOverlap = _countNodeOverlapPairs(
            nodeOrder: nodeOrder,
            positions: positions,
            sizeByNode: sizeByNode,
            minGap: minGap,
          );

          // Allow temporary local degradation by 1 while seeking a true crossing drop.
          final guardOk =
              candSubViol <= currentSubViol + 1 &&
              candEdgeOver <= currentEdgeOver + 1 &&
              candOverlap <= currentOverlap + 2;
          final improved =
              candCross < bestCross ||
              (candCross == bestCross &&
                  (candEdgeOver < bestEdgeOver ||
                      (candEdgeOver == bestEdgeOver &&
                          (candSubViol < bestSubViol ||
                              (candSubViol == bestSubViol &&
                                  candOverlap < bestOverlap)))));

          if (guardOk && improved) {
            bestNode = id;
            bestPos = trial;
            bestCross = candCross;
            bestEdgeOver = candEdgeOver;
            bestSubViol = candSubViol;
            bestOverlap = candOverlap;
          }

          positions[id] = old;
        }

        // Try one strong jump based on the current center to break symmetrical traps.
        final jump = flowHorizontal
            ? Offset(old.dx, oldCenter.dy + laneStep * 2.8 - size.height / 2)
            : Offset(oldCenter.dx + laneStep * 2.8 - size.width / 2, old.dy);
        positions[id] = jump;
        final jumpCross = _countEdgeCrossings(positions, sizeByNode, allEdges);
        final jumpSubViol = _countSubgraphMembershipViolations(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          subgraphNodeGroups: subgraphNodeGroups,
          minGap: minGap,
        );
        final jumpEdgeOver = _countEdgeOverBlockHits(
          nodeOrder,
          positions,
          sizeByNode,
          allEdges,
          minGap,
        );
        final jumpOverlap = _countNodeOverlapPairs(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          minGap: minGap,
        );
        final jumpGuard =
            jumpSubViol <= currentSubViol + 1 &&
            jumpEdgeOver <= currentEdgeOver + 1 &&
            jumpOverlap <= currentOverlap + 2;
        final jumpImproved =
            jumpCross < bestCross ||
            (jumpCross == bestCross &&
                (jumpEdgeOver < bestEdgeOver ||
                    (jumpEdgeOver == bestEdgeOver &&
                        (jumpSubViol < bestSubViol ||
                            (jumpSubViol == bestSubViol &&
                                jumpOverlap < bestOverlap)))));
        if (jumpGuard && jumpImproved) {
          bestNode = id;
          bestPos = jump;
          bestCross = jumpCross;
          bestEdgeOver = jumpEdgeOver;
          bestSubViol = jumpSubViol;
          bestOverlap = jumpOverlap;
        }
        positions[id] = old;
      }

      final improved = bestNode != null && bestCross < currentCross;
      if (!improved) {
        break;
      }

      positions[bestNode] = bestPos;
      currentCross = bestCross;
      currentEdgeOver = bestEdgeOver;
      currentSubViol = bestSubViol;
      currentOverlap = bestOverlap;
      accepted++;

      if (currentCross == 0) {
        break;
      }
    }

    _logAudit(
      'stage=grid_uncross crossings=$currentCross edgeOverNode=$currentEdgeOver subgraphViol=$currentSubViol overlapPairs=$currentOverlap acceptedMoves=$accepted lane=${laneStep.toStringAsFixed(1)}',
    );
  }

  static void _reanchorDisconnectedNodes({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required Map<String, Set<String>> neighbors,
    required String direction,
    required double minGap,
    required List<List<String>> subgraphNodeGroups,
  }) {
    final disconnected = <String>[
      for (final id in nodeOrder)
        if (neighbors[id]?.isEmpty ?? true) id,
    ];
    if (disconnected.isEmpty) {
      return;
    }

    final connected = <String>[
      for (final id in nodeOrder)
        if (!(neighbors[id]?.isEmpty ?? true)) id,
    ];
    if (connected.isEmpty) {
      return;
    }

    final flowHorizontal = direction == 'LR' || direction == 'RL';
    final shell = _subgraphBounds(connected, positions, sizeByNode);
    final laneGap = (minGap * 0.95 + 36.0).clamp(34.0, 180.0);
    final baselineSubViol = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
    );
    final baselineOverlap = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );

    final ordered = [...disconnected]
      ..sort((a, b) {
        final areaA = sizeByNode[a]!.width * sizeByNode[a]!.height;
        final areaB = sizeByNode[b]!.width * sizeByNode[b]!.height;
        final bySize = areaA.compareTo(areaB);
        if (bySize != 0) {
          return bySize;
        }
        return a.compareTo(b);
      });

    final slotsByGroup = <int, int>{};
    var moved = 0;
    for (int i = 0; i < ordered.length; i++) {
      final id = ordered[i];
      final size = sizeByNode[id]!;
      final oldPos = positions[id]!;

      int? chosenGroupIndex;
      Rect? chosenAnchor;
      double chosenArea = double.infinity;
      for (int g = 0; g < subgraphNodeGroups.length; g++) {
        final group = subgraphNodeGroups[g];
        if (!group.contains(id)) {
          continue;
        }
        final peers = <String>[
          for (final member in group)
            if (member != id && positions.containsKey(member)) member,
        ];
        if (peers.isEmpty) {
          continue;
        }
        final linkedPeers = <String>[
          for (final member in peers)
            if (!((neighbors[member]?.isEmpty) ?? true)) member,
        ];
        final anchorPeers = linkedPeers.isNotEmpty ? linkedPeers : peers;
        final bounds = _subgraphBounds(anchorPeers, positions, sizeByNode);
        final area = bounds.width * bounds.height;
        if (area < chosenArea) {
          chosenArea = area;
          chosenGroupIndex = g;
          chosenAnchor = bounds;
        }
      }

      final anchor = chosenAnchor ?? shell;
      final slot = chosenGroupIndex == null
          ? i
          : (slotsByGroup[chosenGroupIndex] ?? 0);
      if (chosenGroupIndex != null) {
        slotsByGroup[chosenGroupIndex] = slot + 1;
      }

      final anchorCenter = anchor.center;
      final slotShift = laneGap * (slot * 0.38);
      final offsets = <Offset>[
        if (flowHorizontal) ...[
          Offset(0, -laneGap - slotShift),
          Offset(0, laneGap + slotShift),
          Offset(laneGap * 0.75, 0),
          Offset(-laneGap * 0.75, 0),
          Offset(laneGap * 0.55, -laneGap * 0.55 - slotShift),
          Offset(-laneGap * 0.55, laneGap * 0.55 + slotShift),
        ] else ...[
          Offset(-laneGap - slotShift, 0),
          Offset(laneGap + slotShift, 0),
          Offset(0, laneGap * 0.75),
          Offset(0, -laneGap * 0.75),
          Offset(-laneGap * 0.55 - slotShift, laneGap * 0.55),
          Offset(laneGap * 0.55 + slotShift, -laneGap * 0.55),
        ],
      ];

      var best = oldPos;
      var bestScore = double.infinity;
      for (final delta in offsets) {
        final center = anchorCenter + delta;
        final candidate = center - Offset(size.width / 2, size.height / 2);
        positions[id] = candidate;

        final candSubViol = _countSubgraphMembershipViolations(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          subgraphNodeGroups: subgraphNodeGroups,
          minGap: minGap,
        );
        final candOverlap = _countNodeOverlapPairs(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          minGap: minGap,
        );
        final distToAnchor =
            (_nodeCenter(candidate, size) - anchorCenter).distance;
        final score =
            (candSubViol - baselineSubViol).clamp(0, 9999) * 1000000.0 +
            (candOverlap - baselineOverlap).clamp(0, 9999) * 100000.0 +
            distToAnchor;
        if (score < bestScore) {
          bestScore = score;
          best = candidate;
        }
      }

      positions[id] = best;
      if ((best - oldPos).distance > 0.01) {
        moved++;
      }
    }

    if (moved > 0) {
      _logAudit(
        'stage=disconnected_reanchor moved=$moved count=${disconnected.length} flow=$direction',
      );
    }
  }

  static ({
    bool moved,
    int crossings,
    int edgeOverNode,
    int subgraphViol,
    int moves,
  })
  _applyCrossingPairLaneMove({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required String direction,
    required double minGap,
    required List<List<String>> subgraphNodeGroups,
    required int currentCrossings,
    required int currentEdgeOver,
    required int currentSubgraphViol,
  }) {
    final flowHorizontal = direction == 'LR' || direction == 'RL';
    final laneKick = (minGap * 2.0 + 96.0).clamp(80.0, 320.0);

    String? bestA;
    String? bestB;
    Offset bestDelta = Offset.zero;
    var bestCross = currentCrossings;
    var bestEdgeOver = currentEdgeOver;
    var bestSubViol = currentSubgraphViol;

    for (int i = 0; i < allEdges.length - 1; i++) {
      final e1 = allEdges[i];
      final p1 = _nodeCenter(positions[e1.$1]!, sizeByNode[e1.$1]!);
      final p2 = _nodeCenter(positions[e1.$2]!, sizeByNode[e1.$2]!);
      final shared = <String>{e1.$1, e1.$2};

      for (int j = i + 1; j < allEdges.length; j++) {
        final e2 = allEdges[j];
        if (shared.contains(e2.$1) || shared.contains(e2.$2)) {
          continue;
        }
        final p3 = _nodeCenter(positions[e2.$1]!, sizeByNode[e2.$1]!);
        final p4 = _nodeCenter(positions[e2.$2]!, sizeByNode[e2.$2]!);
        if (!_segmentsIntersect(p1, p2, p3, p4)) {
          continue;
        }

        final edge1Cost = (degree[e1.$1] ?? 0) + (degree[e1.$2] ?? 0);
        final edge2Cost = (degree[e2.$1] ?? 0) + (degree[e2.$2] ?? 0);
        final moveEdge = edge1Cost <= edge2Cost ? e1 : e2;
        final centerMove = _meanOffset([
          _nodeCenter(positions[moveEdge.$1]!, sizeByNode[moveEdge.$1]!),
          _nodeCenter(positions[moveEdge.$2]!, sizeByNode[moveEdge.$2]!),
        ]);
        final centerOther = moveEdge == e1
            ? _meanOffset([p3, p4])
            : _meanOffset([p1, p2]);
        final sign = flowHorizontal
            ? (centerMove.dy >= centerOther.dy ? 1.0 : -1.0)
            : (centerMove.dx >= centerOther.dx ? 1.0 : -1.0);

        final deltas = <Offset>[
          if (flowHorizontal) ...[
            Offset(0, sign * laneKick),
            Offset(0, -sign * laneKick),
            Offset(0, sign * laneKick * 1.3),
            Offset(0, -sign * laneKick * 1.3),
          ] else ...[
            Offset(sign * laneKick, 0),
            Offset(-sign * laneKick, 0),
            Offset(sign * laneKick * 1.3, 0),
            Offset(-sign * laneKick * 1.3, 0),
          ],
        ];

        for (final delta in deltas) {
          final oldA = positions[moveEdge.$1]!;
          final oldB = positions[moveEdge.$2]!;
          positions[moveEdge.$1] = oldA + delta;
          positions[moveEdge.$2] = oldB + delta;

          final candSubViol = _countSubgraphMembershipViolations(
            nodeOrder: nodeOrder,
            positions: positions,
            sizeByNode: sizeByNode,
            subgraphNodeGroups: subgraphNodeGroups,
            minGap: minGap,
          );
          final candEdgeOver = _countEdgeOverBlockHits(
            nodeOrder,
            positions,
            sizeByNode,
            allEdges,
            minGap,
          );
          final candCross = _countEdgeCrossings(
            positions,
            sizeByNode,
            allEdges,
          );

          final guardOk =
              candSubViol <= currentSubgraphViol + 1 &&
              candEdgeOver <= currentEdgeOver + 1;
          final better =
              candCross < bestCross ||
              (candCross == bestCross &&
                  (candEdgeOver < bestEdgeOver ||
                      (candEdgeOver == bestEdgeOver &&
                          candSubViol < bestSubViol)));
          if (guardOk && better) {
            bestA = moveEdge.$1;
            bestB = moveEdge.$2;
            bestDelta = delta;
            bestCross = candCross;
            bestEdgeOver = candEdgeOver;
            bestSubViol = candSubViol;
          }

          positions[moveEdge.$1] = oldA;
          positions[moveEdge.$2] = oldB;
        }
      }
    }

    if (bestA == null || bestB == null || bestCross >= currentCrossings) {
      return (
        moved: false,
        crossings: currentCrossings,
        edgeOverNode: currentEdgeOver,
        subgraphViol: currentSubgraphViol,
        moves: 0,
      );
    }

    positions[bestA] = positions[bestA]! + bestDelta;
    positions[bestB] = positions[bestB]! + bestDelta;
    return (
      moved: true,
      crossings: bestCross,
      edgeOverNode: bestEdgeOver,
      subgraphViol: bestSubViol,
      moves: 1,
    );
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

  static void _resolveSubgraphGroupOverlaps({
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> subgraphNodeGroups,
    required List<Set<String>> subgraphNodeGroupSets,
    required double minGap,
  }) {
    if (subgraphNodeGroups.length < 2) {
      return;
    }

    final subgraphGap = (minGap * 1.45 + 12.0).clamp(48.0, 300.0);
    final pad = (minGap * 0.70).clamp(12.0, 56.0);
    for (int pass = 0; pass < 22; pass++) {
      var moved = false;

      for (int i = 0; i < subgraphNodeGroups.length - 1; i++) {
        final groupA = subgraphNodeGroups[i];
        final setA = subgraphNodeGroupSets[i];
        final rectA = _subgraphBounds(
          groupA,
          positions,
          sizeByNode,
          padding: pad,
        );

        for (int j = i + 1; j < subgraphNodeGroups.length; j++) {
          final groupB = subgraphNodeGroups[j];
          final setB = subgraphNodeGroupSets[j];
          if (_subgraphGroupsCanCoexist(setA, setB)) {
            continue;
          }

          final rectB = _subgraphBounds(
            groupB,
            positions,
            sizeByNode,
            padding: pad,
          );
          final dx = rectA.center.dx - rectB.center.dx;
          final dy = rectA.center.dy - rectB.center.dy;
          final reqDx = (rectA.width + rectB.width) / 2 + subgraphGap;
          final reqDy = (rectA.height + rectB.height) / 2 + subgraphGap;
          final missX = reqDx - dx.abs();
          final missY = reqDy - dy.abs();
          if (missX <= 0 || missY <= 0) {
            continue;
          }

          moved = true;
          final axisX = missX < missY;
          final sign = axisX ? (dx >= 0 ? 1.0 : -1.0) : (dy >= 0 ? 1.0 : -1.0);
          final shift = ((axisX ? missX : missY) + 1.0) * 0.5;
          final delta = axisX
              ? Offset(sign * shift, 0)
              : Offset(0, sign * shift);

          for (final id in groupA) {
            positions[id] = positions[id]! + delta;
          }
          for (final id in groupB) {
            positions[id] = positions[id]! - delta;
          }
        }
      }

      if (!moved) {
        break;
      }
    }
  }

  static void _enforceSubgraphToSubgraphGap({
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> subgraphNodeGroups,
    required List<Set<String>> subgraphNodeGroupSets,
    required double minGap,
  }) {
    if (subgraphNodeGroups.length < 2) {
      _logAudit('stage=subgraph_group_gap skipped=insufficient_groups');
      return;
    }

    final subgraphGap = (minGap * 1.95 + 24.0).clamp(64.0, 360.0);
    final pad = (minGap * 0.90).clamp(16.0, 72.0);
    final nestedInset = (minGap * 0.85 + 22.0).clamp(28.0, 120.0);
    final nestedParentExtraPad = (minGap * 0.75 + 20.0).clamp(24.0, 120.0);
    var movedPairs = 0;
    var touchedPairs = 0;

    for (int pass = 0; pass < 28; pass++) {
      var movedThisPass = 0;
      var touchedThisPass = 0;

      for (int i = 0; i < subgraphNodeGroups.length - 1; i++) {
        final aNodes = subgraphNodeGroups[i];
        final aSet = subgraphNodeGroupSets[i];
        final aRect = _subgraphBounds(
          aNodes,
          positions,
          sizeByNode,
          padding: pad,
        );

        for (int j = i + 1; j < subgraphNodeGroups.length; j++) {
          final bNodes = subgraphNodeGroups[j];
          final bSet = subgraphNodeGroupSets[j];
          final aContainsB = aSet.containsAll(bSet);
          final bContainsA = bSet.containsAll(aSet);

          if (aContainsB || bContainsA) {
            final parentNodes = aContainsB ? aNodes : bNodes;
            final childNodes = aContainsB ? bNodes : aNodes;

            final parentRect = _subgraphBounds(
              parentNodes,
              positions,
              sizeByNode,
              padding: pad + nestedParentExtraPad,
            );
            final childRect = _subgraphBounds(
              childNodes,
              positions,
              sizeByNode,
              padding: pad,
            );

            var dx = 0.0;
            var dy = 0.0;
            final leftInset = childRect.left - parentRect.left;
            if (leftInset < nestedInset) {
              dx += (nestedInset - leftInset);
            }
            final rightInset = parentRect.right - childRect.right;
            if (rightInset < nestedInset) {
              dx -= (nestedInset - rightInset);
            }
            final topInset = childRect.top - parentRect.top;
            if (topInset < nestedInset) {
              dy += (nestedInset - topInset);
            }
            final bottomInset = parentRect.bottom - childRect.bottom;
            if (bottomInset < nestedInset) {
              dy -= (nestedInset - bottomInset);
            }

            if (dx.abs() > 1e-3 || dy.abs() > 1e-3) {
              final delta = Offset(dx, dy);
              for (final id in childNodes) {
                positions[id] = positions[id]! + delta;
              }
              touchedThisPass++;
              movedThisPass++;
            }
            continue;
          }

          if (_subgraphGroupsCanCoexist(aSet, bSet)) {
            continue;
          }

          final bRect = _subgraphBounds(
            bNodes,
            positions,
            sizeByNode,
            padding: pad,
          );
          final dx = aRect.center.dx - bRect.center.dx;
          final dy = aRect.center.dy - bRect.center.dy;
          final reqDx = (aRect.width + bRect.width) / 2 + subgraphGap;
          final reqDy = (aRect.height + bRect.height) / 2 + subgraphGap;
          final missX = reqDx - dx.abs();
          final missY = reqDy - dy.abs();
          if (missX <= 0 || missY <= 0) {
            continue;
          }

          touchedThisPass++;
          final axisX = missX < missY;
          final sign = axisX ? (dx >= 0 ? 1.0 : -1.0) : (dy >= 0 ? 1.0 : -1.0);
          final shift = ((axisX ? missX : missY) + 1.0) * 0.28;
          final delta = axisX
              ? Offset(sign * shift, 0)
              : Offset(0, sign * shift);

          for (final id in aNodes) {
            positions[id] = positions[id]! + delta;
          }
          for (final id in bNodes) {
            positions[id] = positions[id]! - delta;
          }
          movedThisPass++;
        }
      }

      movedPairs += movedThisPass;
      touchedPairs += touchedThisPass;
      if (touchedThisPass == 0 || movedThisPass == 0) {
        break;
      }
    }

    var remaining = 0;
    for (int i = 0; i < subgraphNodeGroups.length - 1; i++) {
      final aNodes = subgraphNodeGroups[i];
      final aSet = subgraphNodeGroupSets[i];
      final aRect = _subgraphBounds(
        aNodes,
        positions,
        sizeByNode,
        padding: pad,
      );
      for (int j = i + 1; j < subgraphNodeGroups.length; j++) {
        final bNodes = subgraphNodeGroups[j];
        final bSet = subgraphNodeGroupSets[j];
        if (_subgraphGroupsCanCoexist(aSet, bSet)) {
          continue;
        }
        final bRect = _subgraphBounds(
          bNodes,
          positions,
          sizeByNode,
          padding: pad,
        );
        final dx = (aRect.center.dx - bRect.center.dx).abs();
        final dy = (aRect.center.dy - bRect.center.dy).abs();
        final reqDx = (aRect.width + bRect.width) / 2 + subgraphGap;
        final reqDy = (aRect.height + bRect.height) / 2 + subgraphGap;
        if (dx < reqDx && dy < reqDy) {
          remaining++;
        }
      }
    }

    _logAudit(
      'stage=subgraph_group_gap touched=$touchedPairs moves=$movedPairs remaining=$remaining gap=${subgraphGap.toStringAsFixed(1)} pad=${pad.toStringAsFixed(1)} nestedInset=${nestedInset.toStringAsFixed(1)} parentExtraPad=${nestedParentExtraPad.toStringAsFixed(1)}',
    );
  }

  static void _enforceSubgraphMembershipExclusion({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
  }) {
    if (subgraphNodeGroups.isEmpty || nodeOrder.length < 2) {
      _logAudit('stage=subgraph_membership_exclusion skipped=no_subgraphs');
      return;
    }

    final groupSets = [for (final g in subgraphNodeGroups) g.toSet()];
    final nodeGroupIndices = <String, List<int>>{};
    for (int gi = 0; gi < subgraphNodeGroups.length; gi++) {
      for (final id in subgraphNodeGroups[gi]) {
        nodeGroupIndices.putIfAbsent(id, () => <int>[]).add(gi);
      }
    }
    final padding = _subgraphExclusionGap(minGap);
    final clearance = (minGap * 0.35 + 6.0).clamp(8.0, 28.0);
    _logAudit(
      'stage=subgraph_membership_exclusion_policy coexist=hierarchy_only skip=descendant_only padding=${padding.toStringAsFixed(1)} clearance=${clearance.toStringAsFixed(1)}',
    );
    const passCount = 28;
    var totalViolations = 0;
    var totalMoves = 0;

    for (int pass = 0; pass < passCount; pass++) {
      var movedThisPass = 0;
      var violationsThisPass = 0;

      final bounds = [
        for (final group in subgraphNodeGroups)
          _subgraphBounds(group, positions, sizeByNode, padding: padding),
      ];

      for (int gi = 0; gi < subgraphNodeGroups.length; gi++) {
        final members = groupSets[gi];
        final b = bounds[gi];

        for (final id in nodeOrder) {
          if (members.contains(id)) {
            continue;
          }
          final ownerGroups = nodeGroupIndices[id] ?? const <int>[];
          var skip = false;
          for (final otherGi in ownerGroups) {
            final ownerMembers = groupSets[otherGi];
            final ownerIsDescendantOrEqual = members.containsAll(ownerMembers);
            if (ownerIsDescendantOrEqual) {
              skip = true;
              break;
            }
          }
          if (skip) {
            continue;
          }

          final p = positions[id]!;
          final s = sizeByNode[id]!;
          final r = Rect.fromLTWH(p.dx, p.dy, s.width, s.height);
          final ow = math.min(r.right, b.right) - math.max(r.left, b.left);
          final oh = math.min(r.bottom, b.bottom) - math.max(r.top, b.top);
          if (ow <= 0 || oh <= 0) {
            continue;
          }

          violationsThisPass++;
          final delta = _subgraphExclusionDelta(
            nodeRect: r,
            subgraphBounds: b,
            clearance: clearance,
          );

          positions[id] = p + delta;
          movedThisPass++;
        }
      }

      totalViolations += violationsThisPass;
      totalMoves += movedThisPass;
      if (violationsThisPass == 0 || movedThisPass == 0) {
        break;
      }
    }

    final remaining = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
    );

    _logAudit(
      'stage=subgraph_membership_exclusion violations=$totalViolations moves=$totalMoves remaining=$remaining padding=${padding.toStringAsFixed(1)}',
    );
  }

  static void _enforceSubgraphVisualClearance({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
  }) {
    if (subgraphNodeGroups.isEmpty || nodeOrder.length < 2) {
      return;
    }

    final groupSets = [for (final g in subgraphNodeGroups) g.toSet()];
    final nodeGroupIndices = <String, List<int>>{};
    for (int gi = 0; gi < subgraphNodeGroups.length; gi++) {
      for (final id in subgraphNodeGroups[gi]) {
        nodeGroupIndices.putIfAbsent(id, () => <int>[]).add(gi);
      }
    }

    final visualPadding = (_subgraphExclusionGap(minGap) + minGap * 0.40 + 10.0)
        .clamp(24.0, 120.0);
    final clearance = (minGap * 0.45 + 10.0).clamp(10.0, 36.0);
    var movedTotal = 0;

    for (int pass = 0; pass < 14; pass++) {
      var movedThisPass = 0;
      final bounds = [
        for (final group in subgraphNodeGroups)
          _subgraphBounds(group, positions, sizeByNode, padding: visualPadding),
      ];

      for (int gi = 0; gi < subgraphNodeGroups.length; gi++) {
        final members = groupSets[gi];
        final b = bounds[gi];

        for (final id in nodeOrder) {
          if (members.contains(id)) {
            continue;
          }
          final ownerGroups = nodeGroupIndices[id] ?? const <int>[];
          var skip = false;
          for (final otherGi in ownerGroups) {
            final ownerMembers = groupSets[otherGi];
            final ownerIsDescendantOrEqual = members.containsAll(ownerMembers);
            if (ownerIsDescendantOrEqual) {
              skip = true;
              break;
            }
          }
          if (skip) {
            continue;
          }

          final p = positions[id]!;
          final s = sizeByNode[id]!;
          final r = Rect.fromLTWH(p.dx, p.dy, s.width, s.height);
          final ow = math.min(r.right, b.right) - math.max(r.left, b.left);
          final oh = math.min(r.bottom, b.bottom) - math.max(r.top, b.top);
          if (ow <= 0 || oh <= 0) {
            continue;
          }

          final delta = _subgraphExclusionDelta(
            nodeRect: r,
            subgraphBounds: b,
            clearance: clearance,
          );
          positions[id] = p + delta;
          movedThisPass++;
        }
      }

      movedTotal += movedThisPass;
      if (movedThisPass == 0) {
        break;
      }
    }

    _logAudit(
      'stage=subgraph_visual_clearance moves=$movedTotal padding=${visualPadding.toStringAsFixed(1)} clearance=${clearance.toStringAsFixed(1)}',
    );
  }

  static double _subgraphExclusionGap(double minGap) {
    return (minGap * 0.75 + 12.0).clamp(16.0, 84.0);
  }

  static double _totalEdgeLength(
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
    List<(String, String)> allEdges,
  ) {
    var total = 0.0;
    for (final e in allEdges) {
      final pa = positions[e.$1];
      final pb = positions[e.$2];
      final sa = sizeByNode[e.$1];
      final sb = sizeByNode[e.$2];
      if (pa == null || pb == null || sa == null || sb == null) {
        continue;
      }
      total += (_nodeCenter(pa, sa) - _nodeCenter(pb, sb)).distance;
    }
    return total;
  }

  static double _edgeAlignmentScore(
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
  ) {
    final ids = positions.keys.toList();
    var score = 0.0;
    for (int i = 0; i < ids.length - 1; i++) {
      final a = ids[i];
      final pa = positions[a];
      if (pa == null) {
        continue;
      }
      for (int j = i + 1; j < ids.length; j++) {
        final b = ids[j];
        final pb = positions[b];
        if (pb == null) {
          continue;
        }
        final dTop = (pa.dy - pb.dy).abs();
        final dLeft = (pa.dx - pb.dx).abs();
        if (dTop <= 2.0) {
          score += 2.2;
        } else if (dTop <= 8.0) {
          score += 0.9;
        }
        if (dLeft <= 2.0) {
          score += 2.2;
        } else if (dLeft <= 8.0) {
          score += 0.9;
        }
      }
    }
    return score;
  }

  static Rect _subgraphBounds(
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
      final p = positions[id]!;
      final s = sizeByNode[id]!;
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx + s.width);
      bottom = math.max(bottom, p.dy + s.height);
    }

    return Rect.fromLTRB(
      left - padding,
      top - padding,
      right + padding,
      bottom + padding,
    );
  }

  static Offset _subgraphExclusionDelta({
    required Rect nodeRect,
    required Rect subgraphBounds,
    required double clearance,
  }) {
    final moveLeft = (subgraphBounds.left - clearance) - nodeRect.right;
    final moveRight = (subgraphBounds.right + clearance) - nodeRect.left;
    final moveUp = (subgraphBounds.top - clearance) - nodeRect.bottom;
    final moveDown = (subgraphBounds.bottom + clearance) - nodeRect.top;

    final options = <Offset>[
      Offset(moveLeft, 0),
      Offset(moveRight, 0),
      Offset(0, moveUp),
      Offset(0, moveDown),
    ];

    options.sort((a, b) => a.distanceSquared.compareTo(b.distanceSquared));
    return options.first;
  }

  static bool _subgraphGroupsCanCoexist(Set<String> a, Set<String> b) {
    // Only true hierarchy can coexist geometrically (parent/child groups).
    // Partial overlaps must still be separated and excluded.
    return a.containsAll(b) || b.containsAll(a);
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

  static List<List<String>> _normalizeSubgraphGroups(
    List<List<String>>? rawGroups,
    Set<String> allowedNodeIds,
  ) {
    if (rawGroups == null || rawGroups.isEmpty) {
      return const <List<String>>[];
    }

    final output = <List<String>>[];
    final seenGroups = <String>{};
    for (final raw in rawGroups) {
      final seenNodes = <String>{};
      final cleaned = <String>[];
      for (final id in raw) {
        if (!allowedNodeIds.contains(id) || !seenNodes.add(id)) {
          continue;
        }
        cleaned.add(id);
      }

      if (cleaned.length < 2) {
        continue;
      }

      final key = [...cleaned]..sort();
      final sig = key.join('|');
      if (!seenGroups.add(sig)) {
        continue;
      }
      output.add(cleaned);
    }

    return output;
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

  static double? _seedPrimary(
    Map<String, Offset> seedPositions,
    Map<String, Size> sizeByNode,
    String id,
    bool isHorizontal,
  ) {
    final seed = seedPositions[id];
    final size = sizeByNode[id];
    if (seed == null || size == null) {
      return null;
    }
    return isHorizontal ? seed.dx + size.width / 2 : seed.dy + size.height / 2;
  }

  static double? _seedSecondary(
    Map<String, Offset> seedPositions,
    Map<String, Size> sizeByNode,
    String id,
    bool isHorizontal,
  ) {
    final seed = seedPositions[id];
    final size = sizeByNode[id];
    if (seed == null || size == null) {
      return null;
    }
    return isHorizontal ? seed.dy + size.height / 2 : seed.dx + size.width / 2;
  }
}

class _LayoutMetrics {
  final int crossings;
  final int edgeOverNodeHits;
  final int nodeOverlapPairs;
  final int subgraphViolations;
  final int hardViolation;
  final double totalEdgeLength;
  final double alignmentScore;
  final double objective;

  const _LayoutMetrics({
    required this.crossings,
    required this.edgeOverNodeHits,
    required this.nodeOverlapPairs,
    required this.subgraphViolations,
    required this.hardViolation,
    required this.totalEdgeLength,
    required this.alignmentScore,
    required this.objective,
  });
}
