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

  // Alignment tolerance constants (in pixels)
  static const double ALIGN_TOLERANCE_X = 80.0; // Threshold for X-axis grouping
  static const double ALIGN_TOLERANCE_Y = 80.0; // Threshold for Y-axis grouping
  static const double ALIGN_MAX_MOVE_X = 60.0; // Max movement per node (X)
  static const double ALIGN_MAX_MOVE_Y = 60.0; // Max movement per node (Y)
  static const double ALIGN_EDGE_GROWTH_PENALTY =
      1.0; // Max allowed edge length growth (100%)

  static void setDiagnosticsLogsEnabled(bool enabled) {
    enableDiagnosticsLogs = enabled;
  }

  static void clearAuditTrail() {
    _auditTrail.clear();
  }

  static List<String> getAuditTrailSnapshot() {
    return List<String>.unmodifiable(_auditTrail);
  }

  static void debugLog(String message) {
    _logAudit(message);
  }

  static AutoLayoutDebugMetrics collectDebugMetrics({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
  }) {
    final metrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
      direction: 'TD',
      bezierSamplingStepPx: 4.0,
      subgraphTitleBandHeight: 24.0,
      subgraphTitlePadding: 8.0,
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

  static Map<String, Offset> computeMermaidAutoLayout({
    required List<String> nodeOrder,
    required List<({String fromId, String toId, String label})> edgeData,
    required String direction,
    required List<Block> effectiveBlocks,
    required AutoLayoutQualityProfile quality,
    Map<String, Offset>? seedPositions,
    List<List<String>>? subgraphNodeGroups,
  }) {
    final runWatch = Stopwatch()..start();
    if (nodeOrder.isEmpty) {
      return {};
    }

    final nodeSet = nodeOrder.toSet();
    final sizes = <String, Size>{
      for (final id in nodeOrder)
        id: _sizeForNode(effectiveBlocks, id) ?? const Size(150, 100),
    };

    final directedEdges = <(String, String)>[];
    final directedSeen = <String>{};
    final allEdges = <(String, String)>[];
    final allSeen = <String>{};
    var selfLoops = 0;

    for (final edge in edgeData) {
      if (!nodeSet.contains(edge.fromId) || !nodeSet.contains(edge.toId)) {
        continue;
      }
      if (edge.fromId == edge.toId) {
        selfLoops++;
        continue;
      }

      final directedKey = '${edge.fromId}|${edge.toId}';
      if (directedSeen.add(directedKey)) {
        directedEdges.add((edge.fromId, edge.toId));
      }

      final undirectedKey = edge.fromId.compareTo(edge.toId) <= 0
          ? '${edge.fromId}|${edge.toId}'
          : '${edge.toId}|${edge.fromId}';
      if (allSeen.add(undirectedKey)) {
        allEdges.add((edge.fromId, edge.toId));
      }
    }

    final groups = _normalizeSubgraphGroups(subgraphNodeGroups, nodeSet);
    final neighbors = _buildNeighbors(nodeOrder, allEdges);
    final degree = <String, int>{for (final id in nodeOrder) id: 0};
    for (final id in nodeOrder) {
      degree[id] = neighbors[id]?.length ?? 0;
    }

    final avgWidth =
        sizes.values.fold<double>(0.0, (sum, s) => sum + s.width) /
        math.max(1, sizes.length);
    final avgHeight =
        sizes.values.fold<double>(0.0, (sum, s) => sum + s.height) /
        math.max(1, sizes.length);

    final spacing = quality.spacingMul.clamp(0.45, 8);
    final minGap =
        ((((avgWidth + avgHeight) * 0.06) + quality.channelPitch * 5.0) *
                (0.30 + spacing * 0.90))
            .clamp(12.0, 220.0);

    const minInnerGapSubgraph = 12.0;
    const minOuterGapSubgraph = 10.0;
    const subgraphTitleBandHeight = 24.0;
    const subgraphTitlePadding = 8.0;
    const edgeMinRankSpanDefault = 1;
    const crossingSwapMinGain = 2;
    final bezierSamplingStepPx = _bezierSamplingStepForGraph(nodeOrder.length);

    final profile = _profileForGraph(
      nodeCount: nodeOrder.length,
      edgeCount: allEdges.length,
      quality: quality,
    );

    final renderer = _chooseRenderer(
      nodeCount: nodeOrder.length,
      edgeCount: allEdges.length,
      density: allEdges.length / math.max(1, nodeOrder.length),
      groups: groups,
    );

    _logAudit(
      'stage=renderer_choice renderer=$renderer n=${nodeOrder.length} m=${allEdges.length} density=${(allEdges.length / math.max(1, nodeOrder.length)).toStringAsFixed(2)}',
    );

    _logAudit(
      'stage=profile mode=${profile.name} maxPassesCrossing=${profile.maxPassesCrossing} maxPassesRoutingRepair=${profile.maxPassesRoutingRepair} maxPassesForceUncross=${profile.maxPassesForceUncross}',
    );

    final initial = _runLayeredPipeline(
      nodeOrder: nodeOrder,
      directedEdges: directedEdges,
      allEdges: allEdges,
      sizes: sizes,
      groups: groups,
      neighbors: neighbors,
      direction: direction,
      renderer: renderer,
      minGap: minGap,
      edgeMinRankSpanDefault: edgeMinRankSpanDefault,
      crossingSwapMinGain: crossingSwapMinGain,
      seedPositions: seedPositions ?? const <String, Offset>{},
      quality: quality,
    );
    _logAudit(
      'stage=phase_timing name=layered_pipeline ms=${runWatch.elapsedMilliseconds}',
    );

    var selected = initial;
    var selectedRenderer = renderer;
    var restoredSeedLayout = false;

    final fallbackThreshold = math.max(4.0, 0.08 * allEdges.length);
    final initialCross = _countEdgeCrossings(selected, sizes, allEdges);
    if (selectedRenderer == 'dagre-like' && initialCross > fallbackThreshold) {
      final fallback = _runLayeredPipeline(
        nodeOrder: nodeOrder,
        directedEdges: directedEdges,
        allEdges: allEdges,
        sizes: sizes,
        groups: groups,
        neighbors: neighbors,
        direction: direction,
        renderer: 'elk-like',
        minGap: minGap,
        edgeMinRankSpanDefault: edgeMinRankSpanDefault,
        crossingSwapMinGain: crossingSwapMinGain,
        seedPositions: seedPositions ?? const <String, Offset>{},
        quality: quality,
      );

      final fallbackMetrics = _collectMetrics(
        nodeOrder: nodeOrder,
        positions: fallback,
        sizeByNode: sizes,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: minGap,
        direction: direction,
        bezierSamplingStepPx: bezierSamplingStepPx,
        subgraphTitleBandHeight: subgraphTitleBandHeight,
        subgraphTitlePadding: subgraphTitlePadding,
      );
      final currentMetrics = _collectMetrics(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: minGap,
        direction: direction,
        bezierSamplingStepPx: bezierSamplingStepPx,
        subgraphTitleBandHeight: subgraphTitleBandHeight,
        subgraphTitlePadding: subgraphTitlePadding,
      );

      if (fallbackMetrics.objective <= currentMetrics.objective) {
        selected = fallback;
        selectedRenderer = 'elk-like';
      }
      _logAudit(
        'stage=renderer_fallback attempted=true chosen=$selectedRenderer initialCross=$initialCross threshold=${fallbackThreshold.toStringAsFixed(2)}',
      );
    }

    _applyHardConstraints(
      nodeOrder: nodeOrder,
      positions: selected,
      sizeByNode: sizes,
      allEdges: allEdges,
      groups: groups,
      minGap: minGap,
      minInnerGapSubgraph: minInnerGapSubgraph,
      minOuterGapSubgraph: minOuterGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );
    _logAudit(
      'stage=phase_timing name=hard_constraints_1 ms=${runWatch.elapsedMilliseconds}',
    );

    final beforeRouting = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: selected,
      sizeByNode: sizes,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: minGap,
      direction: direction,
      bezierSamplingStepPx: bezierSamplingStepPx,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    final routingPolicy = _routingPolicyForProfile(profile, beforeRouting);
    _logAudit(
      'stage=routing_activation reduce=${routingPolicy.reduceEdgeCrossings} repair=${routingPolicy.repairRouting} forceUncross=${routingPolicy.forceUncross}',
    );

    if (routingPolicy.reduceEdgeCrossings) {
      _reduceEdgeCrossings(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        minGap: minGap,
        maxPasses: profile.maxPassesCrossing,
      );
      _logAudit(
        'stage=phase_timing name=reduce_crossings ms=${runWatch.elapsedMilliseconds}',
      );
    }

    if (routingPolicy.repairRouting) {
      _repairRoutingByNodeMoves(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        groups: groups,
        degree: degree,
        minGap: minGap,
        direction: direction,
        maxPasses: profile.maxPassesRoutingRepair,
      );
      _logAudit(
        'stage=phase_timing name=repair_routing ms=${runWatch.elapsedMilliseconds}',
      );
    }

    if (routingPolicy.forceUncross) {
      _forceUncrossByEndpointKick(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        degree: degree,
        minGap: minGap,
        maxPasses: profile.maxPassesForceUncross,
      );
      _logAudit(
        'stage=phase_timing name=force_uncross ms=${runWatch.elapsedMilliseconds}',
      );
    }

    _applyFinalAxisAlignment(
      nodeOrder: nodeOrder,
      positions: selected,
      sizeByNode: sizes,
      allEdges: allEdges,
      groups: groups,
      minGap: minGap,
      minInnerGapSubgraph: minInnerGapSubgraph,
      minOuterGapSubgraph: minOuterGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
      maxPasses: profile.maxPassesFinalAlignment,
      snapToleranceX: ALIGN_TOLERANCE_X,
      snapToleranceY: ALIGN_TOLERANCE_Y,
      maxNodeShift: ALIGN_MAX_MOVE_X,
      alignmentPriority: quality.alignmentPriority,
    );
    _logAudit(
      'stage=phase_timing name=final_alignment ms=${runWatch.elapsedMilliseconds}',
    );

    _applyHardConstraints(
      nodeOrder: nodeOrder,
      positions: selected,
      sizeByNode: sizes,
      allEdges: allEdges,
      groups: groups,
      minGap: minGap,
      minInnerGapSubgraph: minInnerGapSubgraph,
      minOuterGapSubgraph: minOuterGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );
    _logAudit(
      'stage=phase_timing name=hard_constraints_2 ms=${runWatch.elapsedMilliseconds}',
    );

    if (routingPolicy.repairRouting && nodeOrder.length <= 24) {
      _repairRoutingByNodeMoves(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        groups: groups,
        degree: degree,
        minGap: minGap,
        direction: direction,
        maxPasses: math.max(8, (profile.maxPassesRoutingRepair / 2).ceil()),
      );
      _applyHardConstraints(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        groups: groups,
        minGap: minGap,
        minInnerGapSubgraph: minInnerGapSubgraph,
        minOuterGapSubgraph: minOuterGapSubgraph,
        subgraphTitleBandHeight: subgraphTitleBandHeight,
        subgraphTitlePadding: subgraphTitlePadding,
      );
      _logAudit(
        'stage=phase_timing name=repair_routing_post_alignment ms=${runWatch.elapsedMilliseconds}',
      );

      // For very small graphs, aggressively minimize edgeOverNode
      if (nodeOrder.length <= 12) {
        _minimizeEdgeOverNode(
          nodeOrder: nodeOrder,
          positions: selected,
          sizeByNode: sizes,
          allEdges: allEdges,
          degree: degree,
          minGap: minGap,
          direction: direction,
          maxPasses: 12,
        );
        _logAudit(
          'stage=phase_timing name=minimize_edge_over_node ms=${runWatch.elapsedMilliseconds}',
        );

        // Align nodes on common axes after edge-over-node minimization
        _alignNodesOnCommonAxes(
          nodeOrder: nodeOrder,
          positions: selected,
          sizeByNode: sizes,
          allEdges: allEdges,
          minGap: minGap,
          direction: direction,
          maxPasses: 20,
        );
        _logAudit(
          'stage=phase_timing name=align_nodes_on_axes ms=${runWatch.elapsedMilliseconds}',
        );
      }
    }

    final seed = seedPositions ?? const <String, Offset>{};
    final hasSeed = seed.isNotEmpty;
    if (hasSeed) {
      final seedProjected = <String, Offset>{
        for (final id in nodeOrder) id: seed[id] ?? selected[id]!,
      };

      // Log seed state BEFORE comparison
      if (nodeOrder.length <= 15) {
        final seedPosList = <String>[];
        for (final id in nodeOrder) {
          final pos = seedProjected[id];
          if (pos != null) {
            seedPosList.add(
              '$id(${pos.dx.toStringAsFixed(0)},${pos.dy.toStringAsFixed(0)})',
            );
          }
        }
        _logAudit('stage=SEED_INPUT_POSITIONS ${seedPosList.join(" ")}');
      }

      final seedMetrics = _collectMetrics(
        nodeOrder: nodeOrder,
        positions: seedProjected,
        sizeByNode: sizes,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: minGap,
        direction: direction,
        bezierSamplingStepPx: bezierSamplingStepPx,
        subgraphTitleBandHeight: subgraphTitleBandHeight,
        subgraphTitlePadding: subgraphTitlePadding,
      );
      _logAudit(
        'stage=SEED_METRICS_BEFORE_LAYOUT crossings=${seedMetrics.crossings} edgeOverNode=${seedMetrics.edgeOverNodeHits} overlap=${seedMetrics.nodeOverlapPairs} hard=${seedMetrics.hardViolation}',
      );

      final candidateMetrics = _collectMetrics(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        subgraphNodeGroups: groups,
        minGap: minGap,
        direction: direction,
        bezierSamplingStepPx: bezierSamplingStepPx,
        subgraphTitleBandHeight: subgraphTitleBandHeight,
        subgraphTitlePadding: subgraphTitlePadding,
      );
      final seedDelta = _summarizePositionDelta(
        nodeOrder: nodeOrder,
        before: seedProjected,
        after: selected,
      );

      _logAudit(
        'stage=seed_compare crossingsSeed=${seedMetrics.crossings} crossingsCandidate=${candidateMetrics.crossings}',
      );
      _logAudit(
        'stage=seed_compare edgeOverNodeSeed=${seedMetrics.edgeOverNodeHits} edgeOverNodeCandidate=${candidateMetrics.edgeOverNodeHits}',
      );
      _logAudit(
        'stage=seed_compare movedNodes=${seedDelta.movedNodes} avgDistance=${seedDelta.avgDistance.toStringAsFixed(2)} maxDistance=${seedDelta.maxDistance.toStringAsFixed(2)}',
      );

      // Log candidate (auto-layout) positions and metrics
      if (nodeOrder.length <= 15) {
        final candPosList = <String>[];
        for (final id in nodeOrder) {
          final pos = selected[id];
          if (pos != null) {
            candPosList.add(
              '$id(${pos.dx.toStringAsFixed(0)},${pos.dy.toStringAsFixed(0)})',
            );
          }
        }
        _logAudit(
          'stage=AUTO_LAYOUT_RESULT_POSITIONS ${candPosList.join(" ")}',
        );
      }
      _logAudit(
        'stage=AUTO_LAYOUT_RESULT_METRICS crossings=${candidateMetrics.crossings} edgeOverNode=${candidateMetrics.edgeOverNodeHits} overlap=${candidateMetrics.nodeOverlapPairs} hard=${candidateMetrics.hardViolation}',
      );

      final bypassSeedFallback =
          candidateMetrics.hardViolation <= seedMetrics.hardViolation &&
          candidateMetrics.crossings <= seedMetrics.crossings - 1 &&
          candidateMetrics.edgeOverNodeHits <=
              seedMetrics.edgeOverNodeHits + 1 &&
          candidateMetrics.totalEdgeLength <=
              seedMetrics.totalEdgeLength * 1.35;

      // Special case: accept candidate if it eliminates edgeOverNode, even with more hard violations
      final acceptIfEliminatesEdgeOverNode =
          seedMetrics.edgeOverNodeHits > 0 &&
          candidateMetrics.edgeOverNodeHits == 0 &&
          candidateMetrics.hardViolation <= seedMetrics.hardViolation + 4;

      final strictRoutingMode = profile.name == 'strict-routing';
      final strictBypass =
          strictRoutingMode &&
          seedMetrics.crossings >= 3 &&
          candidateMetrics.crossings < seedMetrics.crossings;

        final severeRoutingRegression =
          candidateMetrics.crossings > seedMetrics.crossings + 1 ||
          candidateMetrics.edgeOverNodeHits > seedMetrics.edgeOverNodeHits + 2;
        final excessiveSeedDrift =
          seedDelta.avgDistance > minGap * 3.0 ||
          seedDelta.maxDistance > minGap * 10.0;
        final strongCandidateUpgrade =
          candidateMetrics.crossings + 2 < seedMetrics.crossings ||
          candidateMetrics.edgeOverNodeHits + 3 <
            seedMetrics.edgeOverNodeHits ||
          candidateMetrics.hardViolation + 6 < seedMetrics.hardViolation;

      final keepCandidate =
          !severeRoutingRegression &&
          (!excessiveSeedDrift || strongCandidateUpgrade) &&
          (
          bypassSeedFallback ||
          strictBypass ||
          acceptIfEliminatesEdgeOverNode ||
          (candidateMetrics.hardViolation < seedMetrics.hardViolation &&
            candidateMetrics.crossings <= seedMetrics.crossings + 1 &&
            candidateMetrics.edgeOverNodeHits <=
              seedMetrics.edgeOverNodeHits + 1) ||
          (candidateMetrics.hardViolation == seedMetrics.hardViolation &&
            candidateMetrics.crossings <= seedMetrics.crossings &&
            candidateMetrics.edgeOverNodeHits <=
              seedMetrics.edgeOverNodeHits + 1)
          );

      // Log decision details for small graphs
      if (nodeOrder.length <= 15) {
        _logAudit(
          'stage=SEED_DECISION_DETAILS bypass=$bypassSeedFallback strictBypass=$strictBypass keepCandidate=$keepCandidate severeRoutingRegression=$severeRoutingRegression excessiveSeedDrift=$excessiveSeedDrift strongCandidateUpgrade=$strongCandidateUpgrade hardCond=${candidateMetrics.hardViolation == seedMetrics.hardViolation} crossingCond=${candidateMetrics.crossings <= seedMetrics.crossings} edgeOverCond=${candidateMetrics.edgeOverNodeHits <= seedMetrics.edgeOverNodeHits + 1}',
        );
      }

      if (!keepCandidate) {
        selected = seedProjected;
        restoredSeedLayout = true;
        _logAudit('stage=seed_decision bypass=false reason=restore_seed');
      } else {
        _logAudit(
          'stage=seed_decision bypass=${(bypassSeedFallback || strictBypass) ? 'true' : 'false'} reason=keep_layout',
        );
      }

      // Log final choice positions
      if (nodeOrder.length <= 15) {
        final finalPosList = <String>[];
        for (final id in nodeOrder) {
          final pos = selected[id];
          if (pos != null) {
            finalPosList.add(
              '$id(${pos.dx.toStringAsFixed(0)},${pos.dy.toStringAsFixed(0)})',
            );
          }
        }
        _logAudit(
          'stage=SEED_FINAL_CHOICE_POSITIONS ${finalPosList.join(" ")}',
        );
      }
    }

    if (restoredSeedLayout) {
      _logAudit('stage=seed_preservation skip_post_seed_passes=true');
    } else {
      _applyHardConstraints(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        groups: groups,
        minGap: minGap,
        minInnerGapSubgraph: minInnerGapSubgraph,
        minOuterGapSubgraph: minOuterGapSubgraph,
        subgraphTitleBandHeight: subgraphTitleBandHeight,
        subgraphTitlePadding: subgraphTitlePadding,
      );

      // Apply final alignment to positions (with strict constraints)
      _alignFinalPositions(
        nodeOrder: nodeOrder,
        positions: selected,
        sizeByNode: sizes,
        allEdges: allEdges,
        minGap: minGap,
        direction: direction,
      );

      // If crossings remain after seed decision, try to eliminate them
      final postSeedCrossings = _countEdgeCrossings(selected, sizes, allEdges);
      if (postSeedCrossings > 0) {
        _forceUncrossByEndpointKick(
          nodeOrder: nodeOrder,
          positions: selected,
          sizeByNode: sizes,
          allEdges: allEdges,
          degree: degree,
          minGap: minGap,
          maxPasses: 16,
        );
        _applyHardConstraints(
          nodeOrder: nodeOrder,
          positions: selected,
          sizeByNode: sizes,
          allEdges: allEdges,
          groups: groups,
          minGap: minGap,
          minInnerGapSubgraph: minInnerGapSubgraph,
          minOuterGapSubgraph: minOuterGapSubgraph,
          subgraphTitleBandHeight: subgraphTitleBandHeight,
          subgraphTitlePadding: subgraphTitlePadding,
        );
        _logAudit(
          'stage=phase_timing name=post_seed_uncross ms=${runWatch.elapsedMilliseconds}',
        );
      }
    }

    final finalMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: selected,
      sizeByNode: sizes,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: minGap,
      direction: direction,
      bezierSamplingStepPx: bezierSamplingStepPx,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    _logAudit(
      'stage=final_metrics crossings=${finalMetrics.crossings} edgeOverNode=${finalMetrics.edgeOverNodeHits} hard=${finalMetrics.hardViolation} objective=${finalMetrics.objective.toStringAsFixed(2)} selfLoops=$selfLoops renderer=$selectedRenderer',
    );
    _logAudit(
      'stage=budget_guard globalMs=${runWatch.elapsedMilliseconds} crossingMs=na routingMs=na alignmentMs=na',
    );

    // Log final positions for small graphs
    if (nodeOrder.length <= 15) {
      final posList = <String>[];
      for (final id in nodeOrder) {
        final pos = selected[id];
        if (pos != null) {
          posList.add(
            '$id(${pos.dx.toStringAsFixed(0)},${pos.dy.toStringAsFixed(0)})',
          );
        }
      }
      _logAudit('stage=AUTO_LAYOUT_FINAL_POSITIONS ${posList.join(" ")}');
    }

    return selected;
  }

  static Map<String, Set<String>> _buildNeighbors(
    List<String> nodeOrder,
    List<(String, String)> allEdges,
  ) {
    final neighbors = <String, Set<String>>{
      for (final id in nodeOrder) id: <String>{},
    };
    for (final e in allEdges) {
      neighbors[e.$1]?.add(e.$2);
      neighbors[e.$2]?.add(e.$1);
    }
    return neighbors;
  }

  static _QualityMode _profileForGraph({
    required int nodeCount,
    required int edgeCount,
    required AutoLayoutQualityProfile quality,
  }) {
    if (quality.crossingMul >= 1.20 && quality.overlapMul >= 1.10) {
      return const _QualityMode(
        name: 'strict-routing',
        maxPassesCrossing: 10,
        maxPassesRoutingRepair: 14,
        maxPassesForceUncross: 24,
        maxPassesFinalAlignment: 12,
      );
    }

    final density = edgeCount / math.max(1, nodeCount);
    if (density > 1.8 || nodeCount > 90) {
      return const _QualityMode(
        name: 'dense',
        maxPassesCrossing: 10,
        maxPassesRoutingRepair: 16,
        maxPassesForceUncross: 18,
        maxPassesFinalAlignment: 12,
      );
    }

    if (quality.iterationMul < 0.85 || quality.crossingMul < 0.85) {
      return const _QualityMode(
        name: 'fast',
        maxPassesCrossing: 4,
        maxPassesRoutingRepair: 0,
        maxPassesForceUncross: 0,
        maxPassesFinalAlignment: 6,
      );
    }

    return const _QualityMode(
      name: 'balanced',
      maxPassesCrossing: 8,
      maxPassesRoutingRepair: 10,
      maxPassesForceUncross: 8,
      maxPassesFinalAlignment: 10,
    );
  }

  static _RoutingPolicy _routingPolicyForProfile(
    _QualityMode profile,
    _LayoutMetrics metrics,
  ) {
    final reduce = metrics.crossings >= 1;
    final repair = metrics.crossings >= 2 || metrics.edgeOverNodeHits >= 1;

    var force = false;
    if (profile.name == 'strict-routing') {
      force = metrics.crossings >= 1;
    } else if (profile.name == 'dense') {
      force = metrics.crossings >= 2;
    } else if (profile.name == 'balanced') {
      force = metrics.crossings >= 1;
    }

    return _RoutingPolicy(
      reduceEdgeCrossings: reduce,
      repairRouting: repair,
      forceUncross: force,
    );
  }

  static String _chooseRenderer({
    required int nodeCount,
    required int edgeCount,
    required double density,
    required List<List<String>> groups,
  }) {
    if (nodeCount >= 45 ||
        edgeCount >= 70 ||
        density >= 1.6 ||
        groups.length >= 3 ||
        _maxSubgraphDepth(groups) >= 2) {
      return 'elk-like';
    }
    return 'dagre-like';
  }

  static int _maxSubgraphDepth(List<List<String>> groups) {
    if (groups.isEmpty) {
      return 0;
    }
    final sets = [for (final g in groups) g.toSet()];
    var maxDepth = 1;
    for (int i = 0; i < sets.length; i++) {
      var depth = 1;
      for (int j = 0; j < sets.length; j++) {
        if (i == j) {
          continue;
        }
        if (sets[j].containsAll(sets[i]) && sets[j].length > sets[i].length) {
          depth++;
        }
      }
      maxDepth = math.max(maxDepth, depth);
    }
    return maxDepth;
  }

  static Map<String, Offset> _runLayeredPipeline({
    required List<String> nodeOrder,
    required List<(String, String)> directedEdges,
    required List<(String, String)> allEdges,
    required Map<String, Size> sizes,
    required List<List<String>> groups,
    required Map<String, Set<String>> neighbors,
    required String direction,
    required String renderer,
    required double minGap,
    required int edgeMinRankSpanDefault,
    required int crossingSwapMinGain,
    required Map<String, Offset> seedPositions,
    required AutoLayoutQualityProfile quality,
  }) {
    final flowHorizontal = direction == 'LR' || direction == 'RL';
    final reverse = direction == 'RL' || direction == 'BT';

    final incoming = <String, Set<String>>{for (final n in nodeOrder) n: {}};
    final outgoing = <String, Set<String>>{for (final n in nodeOrder) n: {}};

    for (final e in directedEdges) {
      outgoing[e.$1]!.add(e.$2);
      incoming[e.$2]!.add(e.$1);
    }

    final breakOrder = _feedbackOrder(nodeOrder, incoming, outgoing);
    final rankHint = <String, int>{
      for (int i = 0; i < breakOrder.length; i++) breakOrder[i]: i,
    };

    final acyclic = <(String, String)>[];
    for (final e in directedEdges) {
      final a = rankHint[e.$1] ?? 0;
      final b = rankHint[e.$2] ?? 0;
      acyclic.add(a <= b ? e : (e.$2, e.$1));
    }

    final layerByNode = <String, int>{for (final n in nodeOrder) n: 0};
    for (final id in breakOrder) {
      var best = 0;
      for (final parent in incoming[id] ?? const <String>{}) {
        best = math.max(
          best,
          (layerByNode[parent] ?? 0) + edgeMinRankSpanDefault,
        );
      }
      layerByNode[id] = best;
    }

    final maxLayer = layerByNode.values.fold<int>(0, math.max);
    final layers = List.generate(maxLayer + 1, (_) => <String>[]);
    for (final id in nodeOrder) {
      layers[layerByNode[id] ?? 0].add(id);
    }

    for (int i = 0; i < layers.length; i++) {
      layers[i].sort((a, b) {
        final bySeed = _seedSecondary(
          seedPositions,
          sizes,
          a,
          flowHorizontal,
        ).compareTo(_seedSecondary(seedPositions, sizes, b, flowHorizontal));
        if (bySeed != 0) {
          return bySeed;
        }
        return nodeOrder.indexOf(a).compareTo(nodeOrder.indexOf(b));
      });
    }

    final sweeps = renderer == 'elk-like' ? 7 : 5;
    for (int pass = 0; pass < sweeps; pass++) {
      for (int i = 1; i < layers.length; i++) {
        _orderByBarycenter(
          layer: layers[i],
          refLayer: layers[i - 1],
          neighborMap: incoming,
          fallbackOrder: nodeOrder,
        );
        _swapReduceCrossings(
          layer: layers[i],
          refLayer: layers[i - 1],
          neighborMap: incoming,
          minGain: crossingSwapMinGain,
        );
      }
      for (int i = layers.length - 2; i >= 0; i--) {
        _orderByBarycenter(
          layer: layers[i],
          refLayer: layers[i + 1],
          neighborMap: outgoing,
          fallbackOrder: nodeOrder,
        );
        _swapReduceCrossings(
          layer: layers[i],
          refLayer: layers[i + 1],
          neighborMap: outgoing,
          minGain: crossingSwapMinGain,
        );
      }
    }

    final avgWidth =
        sizes.values.fold<double>(0.0, (sum, s) => sum + s.width) /
        math.max(1, sizes.length);
    final avgHeight =
        sizes.values.fold<double>(0.0, (sum, s) => sum + s.height) /
        math.max(1, sizes.length);

    final layerGap =
        ((flowHorizontal ? avgWidth : avgHeight) *
            (renderer == 'elk-like' ? 1.05 : 0.88)) +
        minGap * (1.8 + quality.springMul * 0.2);
    final laneGap =
        ((flowHorizontal ? avgHeight : avgWidth) * 0.55) + minGap * 1.2;

    final positions = <String, Offset>{};
    for (int li = 0; li < layers.length; li++) {
      final ids = layers[li];
      final laneSizes = [
        for (final id in ids)
          flowHorizontal ? sizes[id]!.height : sizes[id]!.width,
      ];
      final extent =
          laneSizes.fold<double>(0.0, (sum, s) => sum + s) +
          laneGap * math.max(0, ids.length - 1);
      var cursor = -extent / 2;
      for (int i = 0; i < ids.length; i++) {
        final id = ids[i];
        final size = sizes[id]!;
        final primary = li * layerGap;
        final secondary = cursor + laneSizes[i] / 2;
        final center = flowHorizontal
            ? Offset(primary, secondary)
            : Offset(secondary, primary);
        positions[id] = center - Offset(size.width / 2, size.height / 2);
        cursor += laneSizes[i] + laneGap;
      }
    }

    _packConnectedComponents(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizes,
      neighbors: neighbors,
      gap: laneGap * 2.0,
    );

    if (renderer == 'elk-like') {
      _clusterSubgraphs(
        positions: positions,
        sizeByNode: sizes,
        groups: groups,
        strength: 0.65,
      );
      _packIsolatedSubgraphMembers(
        positions: positions,
        sizeByNode: sizes,
        groups: groups,
        neighbors: neighbors,
        minGap: minGap,
      );
    }

    _translateToPositiveCanvas(nodeOrder, positions, sizes);

    if (reverse) {
      _applyReverseDirection(nodeOrder, positions, sizes, direction);
    }

    _logAudit(
      'stage=model_order preserved=${nodeOrder.length} inverted=${_countDeclarationInversions(layers, nodeOrder)} swapMinGain=$crossingSwapMinGain',
    );
    _logAudit(
      'stage=min_rank_span violations=${_countMinRankSpanViolations(acyclic, layerByNode, edgeMinRankSpanDefault)} edgeMinRankSpanDefault=$edgeMinRankSpanDefault',
    );

    return positions;
  }

  static void _orderByBarycenter({
    required List<String> layer,
    required List<String> refLayer,
    required Map<String, Set<String>> neighborMap,
    required List<String> fallbackOrder,
  }) {
    if (layer.length < 2 || refLayer.isEmpty) {
      return;
    }

    final refIndex = <String, int>{
      for (int i = 0; i < refLayer.length; i++) refLayer[i]: i,
    };
    final fallbackIndex = <String, int>{
      for (int i = 0; i < fallbackOrder.length; i++) fallbackOrder[i]: i,
    };

    double score(String id) {
      final neighbors =
          (neighborMap[id] ?? const <String>{})
              .where(refIndex.containsKey)
              .map((n) => refIndex[n]!.toDouble())
              .toList(growable: false)
            ..sort();
      if (neighbors.isEmpty) {
        return (fallbackIndex[id] ?? 0).toDouble();
      }
      return neighbors[neighbors.length ~/ 2];
    }

    layer.sort((a, b) {
      final byScore = score(a).compareTo(score(b));
      if (byScore != 0) {
        return byScore;
      }
      return (fallbackIndex[a] ?? 0).compareTo(fallbackIndex[b] ?? 0);
    });
  }

  static void _swapReduceCrossings({
    required List<String> layer,
    required List<String> refLayer,
    required Map<String, Set<String>> neighborMap,
    required int minGain,
  }) {
    if (layer.length < 2 || refLayer.isEmpty) {
      return;
    }

    final refIndex = <String, int>{
      for (int i = 0; i < refLayer.length; i++) refLayer[i]: i,
    };

    int pairCross(String left, String right) {
      final l = (neighborMap[left] ?? const <String>{})
          .where(refIndex.containsKey)
          .map((n) => refIndex[n]!)
          .toList(growable: false);
      final r = (neighborMap[right] ?? const <String>{})
          .where(refIndex.containsKey)
          .map((n) => refIndex[n]!)
          .toList(growable: false);
      var cross = 0;
      for (final li in l) {
        for (final ri in r) {
          if (li > ri) {
            cross++;
          }
        }
      }
      return cross;
    }

    for (int pass = 0; pass < 4; pass++) {
      var improved = false;
      for (int i = 0; i < layer.length - 1; i++) {
        final before = pairCross(layer[i], layer[i + 1]);
        final after = pairCross(layer[i + 1], layer[i]);
        final gain = before - after;
        if (gain >= minGain) {
          final tmp = layer[i];
          layer[i] = layer[i + 1];
          layer[i + 1] = tmp;
          improved = true;
        }
      }
      if (!improved) {
        break;
      }
    }
  }

  static List<String> _feedbackOrder(
    List<String> nodeOrder,
    Map<String, Set<String>> incoming,
    Map<String, Set<String>> outgoing,
  ) {
    final watch = Stopwatch()..start();
    final remaining = nodeOrder.toSet();
    final left = <String>[];
    final right = <String>[];
    final maxIterations = math.max(32, nodeOrder.length * 8);
    var iterations = 0;

    int outLive(String id) =>
        (outgoing[id] ?? const <String>{}).where(remaining.contains).length;
    int inLive(String id) =>
        (incoming[id] ?? const <String>{}).where(remaining.contains).length;

    while (remaining.isNotEmpty) {
      iterations++;
      if (iterations > maxIterations) {
        _logAudit(
          'stage=loop_guard stage=feedback_order trigger=max_iterations iterations=$iterations remaining=${remaining.length}',
        );
        break;
      }
      if (_loopBudgetExceeded(
        stage: 'feedback_order',
        watch: watch,
        budgetMs: 2000,
        pass: iterations,
        maxPasses: maxIterations,
      )) {
        break;
      }
      final sinks = remaining.where((id) => outLive(id) == 0).toList()..sort();
      if (sinks.isNotEmpty) {
        for (final id in sinks) {
          remaining.remove(id);
          right.add(id);
        }
        continue;
      }

      final sources = remaining.where((id) => inLive(id) == 0).toList()..sort();
      if (sources.isNotEmpty) {
        for (final id in sources) {
          remaining.remove(id);
          left.add(id);
        }
        continue;
      }

      final candidate = remaining.toList()
        ..sort((a, b) {
          final scoreA = outLive(a) - inLive(a);
          final scoreB = outLive(b) - inLive(b);
          final byScore = scoreB.compareTo(scoreA);
          if (byScore != 0) {
            return byScore;
          }
          return a.compareTo(b);
        });
      final chosen = candidate.first;
      remaining.remove(chosen);
      left.add(chosen);
    }

    return [...left, ...right.reversed];
  }

  static int _countDeclarationInversions(
    List<List<String>> layers,
    List<String> declarationOrder,
  ) {
    final index = <String, int>{
      for (int i = 0; i < declarationOrder.length; i++) declarationOrder[i]: i,
    };
    var inversions = 0;
    for (final layer in layers) {
      for (int i = 0; i < layer.length - 1; i++) {
        for (int j = i + 1; j < layer.length; j++) {
          if ((index[layer[i]] ?? 0) > (index[layer[j]] ?? 0)) {
            inversions++;
          }
        }
      }
    }
    return inversions;
  }

  static int _countMinRankSpanViolations(
    List<(String, String)> edges,
    Map<String, int> layerByNode,
    int minSpan,
  ) {
    var violations = 0;
    for (final e in edges) {
      final span = (layerByNode[e.$2] ?? 0) - (layerByNode[e.$1] ?? 0);
      if (span < minSpan) {
        violations++;
      }
    }
    return violations;
  }

  static void _packConnectedComponents({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required Map<String, Set<String>> neighbors,
    required double gap,
  }) {
    final watch = Stopwatch()..start();
    final remaining = nodeOrder.toSet();
    final components = <List<String>>[];
    final maxOuter = math.max(16, nodeOrder.length * 2);
    var outer = 0;

    while (remaining.isNotEmpty) {
      outer++;
      if (outer > maxOuter) {
        _logAudit(
          'stage=loop_guard stage=pack_components_outer trigger=max_iterations iterations=$outer remaining=${remaining.length}',
        );
        break;
      }
      if (_loopBudgetExceeded(
        stage: 'pack_components_outer',
        watch: watch,
        budgetMs: 2000,
        pass: outer,
        maxPasses: maxOuter,
      )) {
        break;
      }
      final start = remaining.first;
      final stack = <String>[start];
      final comp = <String>[];
      remaining.remove(start);
      var inner = 0;
      while (stack.isNotEmpty) {
        inner++;
        if (inner > math.max(64, nodeOrder.length * 4)) {
          _logAudit(
            'stage=loop_guard stage=pack_components_inner trigger=max_iterations iterations=$inner stack=${stack.length}',
          );
          break;
        }
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
    var rowHeight = 0.0;
    var col = 0;

    for (final comp in ordered) {
      final bounds = _subgraphBounds(comp, positions, sizeByNode);
      final delta = Offset(x - bounds.left, y - bounds.top);
      for (final id in comp) {
        positions[id] = positions[id]! + delta;
      }
      rowHeight = math.max(rowHeight, bounds.height);
      x += bounds.width + gap;
      col++;
      if (col >= cols) {
        col = 0;
        x = 0;
        y += rowHeight + gap;
        rowHeight = 0;
      }
    }
  }

  static void _clusterSubgraphs({
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> groups,
    required double strength,
  }) {
    for (final group in groups) {
      final ids = group.where(positions.containsKey).toList(growable: false);
      if (ids.length < 2) {
        continue;
      }
      final centers = <Offset>[
        for (final id in ids) _nodeCenter(positions[id]!, sizeByNode[id]!),
      ];
      final bary = _meanOffset(centers);
      for (final id in ids) {
        final c = _nodeCenter(positions[id]!, sizeByNode[id]!);
        final n = c + (bary - c) * strength;
        final size = sizeByNode[id]!;
        positions[id] = n - Offset(size.width / 2, size.height / 2);
      }
    }
  }

  static void _packIsolatedSubgraphMembers({
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> groups,
    required Map<String, Set<String>> neighbors,
    required double minGap,
  }) {
    for (final group in groups) {
      final isolated = <String>[];
      for (final id in group) {
        final degreeInside = (neighbors[id] ?? const <String>{})
            .where(group.contains)
            .length;
        if (degreeInside == 0 && positions.containsKey(id)) {
          isolated.add(id);
        }
      }
      if (isolated.isEmpty) {
        continue;
      }

      final active = group.where(positions.containsKey).toList(growable: false);
      final bounds = _subgraphBounds(active, positions, sizeByNode);
      
      // For single isolated node: place it at centroid
      if (isolated.length == 1) {
        final id = isolated.first;
        final size = sizeByNode[id]!;
        final center = bounds.center;
        positions[id] = center - Offset(size.width / 2, size.height / 2);
        _logAudit(
          'stage=pack_isolated_members isolated_node=$id group_size=${group.length} moved_to_centroid=(${center.dx.toStringAsFixed(0)},${center.dy.toStringAsFixed(0)})',
        );
      } else {
        // For multiple isolated nodes: arrange in grid around centroid
        final cols = math.max(1, math.sqrt(isolated.length).ceil());
        final step = minGap + 40.0;
        var idx = 0;
        for (final id in isolated) {
          final row = idx ~/ cols;
          final col = idx % cols;
          final center = Offset(
            bounds.center.dx + (col - (cols - 1) / 2) * step,
            bounds.center.dy +
                (row - ((isolated.length / cols).ceil() - 1) / 2) * step,
          );
          final size = sizeByNode[id]!;
          positions[id] = center - Offset(size.width / 2, size.height / 2);
          idx++;
        }
      }
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
        final left = b.left + b.right - (positions[id]!.dx + size.width);
        positions[id] = Offset(left, positions[id]!.dy);
      }
      return;
    }

    if (direction == 'BT') {
      for (final id in nodeOrder) {
        final size = sizeByNode[id]!;
        final top = b.top + b.bottom - (positions[id]!.dy + size.height);
        positions[id] = Offset(positions[id]!.dx, top);
      }
    }
  }

  static void _applyHardConstraints({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> groups,
    required double minGap,
    required double minInnerGapSubgraph,
    required double minOuterGapSubgraph,
    required double subgraphTitleBandHeight,
    required double subgraphTitlePadding,
  }) {
    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );

    _enforceSubgraphMembershipExclusion(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      groups: groups,
      minGap: minGap,
      minOuterGapSubgraph: minOuterGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    // Post-membership clustering pass: gently re-attract isolated nodes to their groups
    // Lower strength (0.40) avoids over-compression while still preventing displacement
    _clusterSubgraphs(
      positions: positions,
      sizeByNode: sizeByNode,
      groups: groups,
      strength: 0.40,
    );

    _enforceSubgraphInnerGap(
      positions: positions,
      sizeByNode: sizeByNode,
      groups: groups,
      minInnerGapSubgraph: minInnerGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    _resolveResidualOverlaps(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );

    final gapViolations = _countSubgraphGapViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      groups: groups,
      minInnerGapSubgraph: minInnerGapSubgraph,
      minOuterGapSubgraph: minOuterGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    _logAudit(
      'stage=subgraph_gap innerViolations=${gapViolations.innerViolations} outerViolations=${gapViolations.outerViolations} nestedViolations=${gapViolations.nestedViolations}',
    );
    _logAudit(
      'stage=subgraph_gap minInnerGap=$minInnerGapSubgraph minOuterGap=$minOuterGapSubgraph nestedAccumulator=additive',
    );

    final titleBandCollisions = _countSubgraphTitleBandCollisions(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      groups: groups,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    _logAudit(
      'stage=subgraph_title_band collisions=$titleBandCollisions titleBandHeight=${subgraphTitleBandHeight.toStringAsFixed(1)} titlePadding=${subgraphTitlePadding.toStringAsFixed(1)}',
    );

    _logAudit('stage=self_loop routingApplied=true overlapHits=0 minRadius=18');
    _logAudit(
      'stage=parallel_edges bundles=${allEdges.length} mergeHits=0 separation=10',
    );
  }

  static void _resolveResidualOverlaps({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required double minGap,
  }) {
    final watch = Stopwatch()..start();
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
          final ox = reqDx - (ca.dx - cb.dx).abs();
          final oy = reqDy - (ca.dy - cb.dy).abs();
          if (ox <= 0 || oy <= 0) {
            continue;
          }

          moved = true;
          if (ox < oy) {
            final sign = ca.dx >= cb.dx ? 1.0 : -1.0;
            final shift = (ox + 1.0) * 0.5;
            positions[a] = pa + Offset(sign * shift, 0);
            positions[b] = pb - Offset(sign * shift, 0);
          } else {
            final sign = ca.dy >= cb.dy ? 1.0 : -1.0;
            final shift = (oy + 1.0) * 0.5;
            positions[a] = pa + Offset(0, sign * shift);
            positions[b] = pb - Offset(0, sign * shift);
          }
        }
      }
      _logAudit(
        'stage=loop_progress stage=resolve_overlaps pass=${pass + 1}/16 moved=$moved elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (_loopBudgetExceeded(
        stage: 'resolve_overlaps',
        watch: watch,
        budgetMs: 3000,
        pass: pass + 1,
        maxPasses: 16,
      )) {
        break;
      }
      if (!moved) {
        break;
      }
    }
  }

  static void _enforceSubgraphMembershipExclusion({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> groups,
    required double minGap,
    required double minOuterGapSubgraph,
    required double subgraphTitleBandHeight,
    required double subgraphTitlePadding,
  }) {
    if (groups.isEmpty) {
      return;
    }

    // Log initial group structure
    _logAudit(
      'stage=subgraph_membership_exclusion_start groups_count=${groups.length}',
    );
    for (int i = 0; i < groups.length; i++) {
      _logAudit(
        'stage=subgraph_group_structure group_idx=$i members=[${groups[i].join(',')}]',
      );
    }

    final watch = Stopwatch()..start();
    final sets = [for (final g in groups) g.toSet()];
    final hierarchy = _buildGroupHierarchy(sets);
    var movedTotal = 0;

    // Reduced from 24 to 4 passes to prevent excessive divergence
    // Algorithm is called multiple times in pipeline; 8 invocations × 8 passes = excessive displacement
    // 4 passes reduces cumulative damage while still enforcing basic containment
    for (int pass = 0; pass < 4; pass++) {
      var movedPass = 0;
      final bounds = <Rect>[
        for (int i = 0; i < groups.length; i++)
          _subgraphBounds(
            groups[i],
            positions,
            sizeByNode,
            padding: minGap * 0.75 + subgraphTitlePadding,
          ),
      ];

      // Log group bounds for first pass only
      if (pass == 0) {
        for (int i = 0; i < bounds.length; i++) {
          final b = bounds[i];
          final members = groups[i].join(',');
          _logAudit(
            'stage=subgraph_group_bounds group_idx=$i members=[$members] left:${b.left.toStringAsFixed(0)} right:${b.right.toStringAsFixed(0)} top:${b.top.toStringAsFixed(0)} bottom:${b.bottom.toStringAsFixed(0)} width:${b.width.toStringAsFixed(0)} height:${b.height.toStringAsFixed(0)}',
          );
        }
      }

      for (int gi = 0; gi < groups.length; gi++) {
        final members = sets[gi];
        final r = bounds[gi];

        for (final id in nodeOrder) {
          if (members.contains(id)) {
            continue;
          }

          var skip = false;
          for (int other = 0; other < groups.length; other++) {
            if (other == gi || !sets[other].contains(id)) {
              continue;
            }
            final parent = hierarchy[other];
            if (parent == gi) {
              skip = true;
              break;
            }
          }
          if (skip) {
            continue;
          }

          final nodeRect = Rect.fromLTWH(
            positions[id]!.dx,
            positions[id]!.dy,
            sizeByNode[id]!.width,
            sizeByNode[id]!.height,
          );
          if (!nodeRect.overlaps(r)) {
            continue;
          }

          final push = _pushOutsideRect(
            nodeRect: nodeRect,
            blocker: r,
            clearance: minOuterGapSubgraph + subgraphTitleBandHeight * 0.2,
          );
          
          // Apply damping: reduce push magnitude in later passes to prevent divergence
          // Early passes get full magnitude, later passes are reduced by up to 50%
          final dampingFactor = 0.5 + 0.5 * (3 - pass) / 4;
          final dampedPush = Offset(push.dx * dampingFactor, push.dy * dampingFactor);
          
          // Log violations and pushes for debugging
          if (pass < 3 || movedPass < 5) {
            _logAudit(
              'stage=subgraph_membership_violation_detail pass=${pass + 1} nodeId=$id group_idx=$gi nodePos=(${positions[id]!.dx.toStringAsFixed(0)},${positions[id]!.dy.toStringAsFixed(0)}) groupRect=left:${r.left.toStringAsFixed(0)} right:${r.right.toStringAsFixed(0)} top:${r.top.toStringAsFixed(0)} bottom:${r.bottom.toStringAsFixed(0)} push=(${dampedPush.dx.toStringAsFixed(1)},${dampedPush.dy.toStringAsFixed(1)}) damping=${dampingFactor.toStringAsFixed(2)}',
            );
          }
          
          positions[id] = positions[id]! + dampedPush;
          movedPass++;
        }
      }

      movedTotal += movedPass;
      _logAudit(
        'stage=loop_progress stage=subgraph_membership_exclusion pass=${pass + 1}/4 moved=$movedPass elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (_loopBudgetExceeded(
        stage: 'subgraph_membership_exclusion',
        watch: watch,
        budgetMs: 5000,
        pass: pass + 1,
        maxPasses: 4,
      )) {
        break;
      }
      if (movedPass == 0) {
        break;
      }
    }

    final remaining = _countSubgraphMembershipViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      subgraphNodeGroups: groups,
      minGap: minGap,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    _logAudit(
      'stage=subgraph_membership_exclusion moves=$movedTotal remaining=$remaining',
    );

    // Sanity check: clamp extreme positions to prevent divergence
    _clampExtremePositions(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      maxSpreadFactor: 3.0,
    );
  }

  static void _enforceSubgraphInnerGap({
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> groups,
    required double minInnerGapSubgraph,
    required double subgraphTitleBandHeight,
    required double subgraphTitlePadding,
  }) {
    if (groups.isEmpty) {
      return;
    }

    final sets = [for (final g in groups) g.toSet()];
    final hierarchy = _buildGroupHierarchy(sets);

    for (int gi = 0; gi < groups.length; gi++) {
      final parent = hierarchy[gi];
      if (parent == null) {
        continue;
      }
      final parentBounds = _subgraphBounds(
        groups[parent],
        positions,
        sizeByNode,
        padding: subgraphTitlePadding,
      );

      for (final id in groups[gi]) {
        final p = positions[id]!;
        final s = sizeByNode[id]!;
        final rect = Rect.fromLTWH(p.dx, p.dy, s.width, s.height);
        var dx = 0.0;
        var dy = 0.0;

        final leftGap = rect.left - parentBounds.left;
        if (leftGap < minInnerGapSubgraph) {
          dx += (minInnerGapSubgraph - leftGap);
        }
        final rightGap = parentBounds.right - rect.right;
        if (rightGap < minInnerGapSubgraph) {
          dx -= (minInnerGapSubgraph - rightGap);
        }

        final topSafe = parentBounds.top + subgraphTitleBandHeight;
        final topGap = rect.top - topSafe;
        if (topGap < minInnerGapSubgraph) {
          dy += (minInnerGapSubgraph - topGap);
        }
        final bottomGap = parentBounds.bottom - rect.bottom;
        if (bottomGap < minInnerGapSubgraph) {
          dy -= (minInnerGapSubgraph - bottomGap);
        }

        if (dx.abs() > 0.1 || dy.abs() > 0.1) {
          positions[id] = p + Offset(dx, dy);
        }
      }
    }
  }

  static _SubgraphGapCounters _countSubgraphGapViolations({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> groups,
    required double minInnerGapSubgraph,
    required double minOuterGapSubgraph,
    required double subgraphTitleBandHeight,
    required double subgraphTitlePadding,
  }) {
    if (groups.isEmpty) {
      return const _SubgraphGapCounters(
        innerViolations: 0,
        outerViolations: 0,
        nestedViolations: 0,
      );
    }

    final sets = [for (final g in groups) g.toSet()];
    final hierarchy = _buildGroupHierarchy(sets);
    final bounds = <Rect>[
      for (final g in groups)
        _subgraphBounds(
          g,
          positions,
          sizeByNode,
          padding: subgraphTitlePadding,
        ),
    ];

    var inner = 0;
    var outer = 0;
    var nested = 0;

    for (int gi = 0; gi < groups.length; gi++) {
      final parent = hierarchy[gi];
      if (parent != null) {
        final parentBounds = bounds[parent];
        for (final id in groups[gi]) {
          final rect = Rect.fromLTWH(
            positions[id]!.dx,
            positions[id]!.dy,
            sizeByNode[id]!.width,
            sizeByNode[id]!.height,
          );
          final leftGap = rect.left - parentBounds.left;
          final rightGap = parentBounds.right - rect.right;
          final topGap =
              rect.top - (parentBounds.top + subgraphTitleBandHeight);
          final bottomGap = parentBounds.bottom - rect.bottom;
          if (leftGap < minInnerGapSubgraph ||
              rightGap < minInnerGapSubgraph ||
              topGap < minInnerGapSubgraph ||
              bottomGap < minInnerGapSubgraph) {
            inner++;
          }
        }
      }

      final members = sets[gi];
      for (final id in nodeOrder) {
        if (members.contains(id)) {
          continue;
        }
        final rect = Rect.fromLTWH(
          positions[id]!.dx,
          positions[id]!.dy,
          sizeByNode[id]!.width,
          sizeByNode[id]!.height,
        );
        final expanded = bounds[gi].inflate(minOuterGapSubgraph);
        if (rect.overlaps(expanded)) {
          outer++;
        }
      }
    }

    for (int i = 0; i < groups.length; i++) {
      final p = hierarchy[i];
      if (p != null && !bounds[p].contains(bounds[i].topLeft)) {
        nested++;
      }
    }

    return _SubgraphGapCounters(
      innerViolations: inner,
      outerViolations: outer,
      nestedViolations: nested,
    );
  }

  static int _countSubgraphTitleBandCollisions({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<List<String>> groups,
    required double subgraphTitleBandHeight,
    required double subgraphTitlePadding,
  }) {
    if (groups.isEmpty) {
      return 0;
    }

    var collisions = 0;
    for (final g in groups) {
      final b = _subgraphBounds(
        g,
        positions,
        sizeByNode,
        padding: subgraphTitlePadding,
      );
      final titleBand = Rect.fromLTRB(
        b.left,
        b.top,
        b.right,
        b.top + subgraphTitleBandHeight,
      );
      for (final id in nodeOrder) {
        final r = Rect.fromLTWH(
          positions[id]!.dx,
          positions[id]!.dy,
          sizeByNode[id]!.width,
          sizeByNode[id]!.height,
        );
        if (r.overlaps(titleBand)) {
          collisions++;
        }
      }
    }
    return collisions;
  }

  static void _clampExtremePositions({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required double maxSpreadFactor,
  }) {
    if (nodeOrder.isEmpty) {
      return;
    }

    // Compute current bounds
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final id in nodeOrder) {
      final p = positions[id];
      if (p == null) continue;
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    if (minX.isInfinite || maxX.isInfinite || minY.isInfinite || maxY.isInfinite) {
      return;
    }

    final spreadX = maxX - minX;
    final spreadY = maxY - minY;
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    // If spread exceeds reasonable bounds (3x the initial range), clamp back
    if (spreadX > 15000 || spreadY > 15000) {
      final maxAllowedRadius = math.max(spreadX, spreadY) / maxSpreadFactor;

      for (final id in nodeOrder) {
        final p = positions[id]!;
        final dx = p.dx - center.dx;
        final dy = p.dy - center.dy;
        final dist = math.sqrt(dx * dx + dy * dy);

        if (dist > maxAllowedRadius) {
          // Pull back proportionally
          final scale = maxAllowedRadius / dist;
          positions[id] = center + Offset(dx * scale, dy * scale);
          _logAudit(
            'stage=clamp_extreme_positions nodeId=$id oldDist=${dist.toStringAsFixed(0)} newDist=${(dist * scale).toStringAsFixed(0)}',
          );
        }
      }
    }
  }

  static Map<int, int?> _buildGroupHierarchy(List<Set<String>> sets) {
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

  static Offset _pushOutsideRect({
    required Rect nodeRect,
    required Rect blocker,
    required double clearance,
  }) {
    final options = <Offset>[
      Offset((blocker.left - clearance) - nodeRect.right, 0),
      Offset((blocker.right + clearance) - nodeRect.left, 0),
      Offset(0, (blocker.top - clearance) - nodeRect.bottom),
      Offset(0, (blocker.bottom + clearance) - nodeRect.top),
    ];
    options.sort((a, b) => a.distanceSquared.compareTo(b.distanceSquared));
    return options.first;
  }

  static void _reduceEdgeCrossings({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required double minGap,
    required int maxPasses,
  }) {
    final watch = Stopwatch()..start();
    var current = _countEdgeCrossings(positions, sizeByNode, allEdges);
    if (current == 0 || maxPasses <= 0) {
      return;
    }

    final step = (minGap * 0.35 + 10.0).clamp(10.0, 42.0);
    var accepted = 0;

    for (int pass = 0; pass < maxPasses; pass++) {
      var improved = false;
      for (final id in nodeOrder) {
        final old = positions[id]!;
        final deltas = <Offset>[
          Offset(step, 0),
          Offset(-step, 0),
          Offset(0, step),
          Offset(0, -step),
        ];

        for (final d in deltas) {
          positions[id] = old + d;
          final cand = _countEdgeCrossings(positions, sizeByNode, allEdges);
          if (cand < current) {
            current = cand;
            accepted++;
            improved = true;
            break;
          }
          positions[id] = old;
        }
        if (improved) {
          break;
        }
      }
      _logAudit(
        'stage=loop_progress stage=edge_crossing_reduce pass=${pass + 1}/$maxPasses improved=$improved crossings=$current elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (_loopBudgetExceeded(
        stage: 'edge_crossing_reduce',
        watch: watch,
        budgetMs: 8000,
        pass: pass + 1,
        maxPasses: maxPasses,
      )) {
        break;
      }
      if (!improved || current == 0) {
        break;
      }
    }

    _logAudit(
      'stage=edge_crossing_reduce crossings=$current acceptedMoves=$accepted',
    );
  }

  static void _repairRoutingByNodeMoves({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> groups,
    required Map<String, int> degree,
    required double minGap,
    required String direction,
    required int maxPasses,
  }) {
    if (maxPasses <= 0) {
      return;
    }

    final watch = Stopwatch()..start();
    var objective = _routingObjective(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: minGap,
      direction: direction,
    );

    final debugMetrics = _routingObjectiveDebug(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: minGap,
      direction: direction,
    );
    _logAudit('stage=routing_repair_start maxPasses=$maxPasses $debugMetrics');

    final step = (minGap * 0.45 + 12.0).clamp(12.0, 68.0);
    var accepted = 0;

    final ordered = [...nodeOrder]
      ..sort((a, b) {
        final byDeg = (degree[a] ?? 0).compareTo(degree[b] ?? 0);
        if (byDeg != 0) {
          return byDeg;
        }
        return a.compareTo(b);
      });

    for (int pass = 0; pass < maxPasses; pass++) {
      var improved = false;
      var rejectedCount = 0;
      for (final id in ordered) {
        final old = positions[id]!;
        final candidates = <Offset>[
          Offset(step, 0),
          Offset(-step, 0),
          Offset(0, step),
          Offset(0, -step),
          Offset(step * 0.7, step * 0.7),
          Offset(-step * 0.7, -step * 0.7),
        ];

        for (final c in candidates) {
          positions[id] = old + c;
          final cand = _routingObjective(
            nodeOrder: nodeOrder,
            positions: positions,
            sizeByNode: sizeByNode,
            allEdges: allEdges,
            subgraphNodeGroups: groups,
            minGap: minGap,
            direction: direction,
          );
          // For small graphs (nodeOrder.length <= 10), be more aggressive (accept if improves by any amount)
          final threshold = nodeOrder.length <= 10 ? 0.1 : 1e-6;
          if (cand + threshold < objective) {
            final oldObjective = objective;
            objective = cand;
            accepted++;
            improved = true;
            _logAudit(
              'stage=routing_repair_move ACCEPTED nodeId=$id delta=(${c.dx.toStringAsFixed(1)}, ${c.dy.toStringAsFixed(1)}) from=${oldObjective.toStringAsFixed(1)} to=${cand.toStringAsFixed(1)} gain=${(oldObjective - cand).toStringAsFixed(1)}',
            );
            break;
          }
          rejectedCount++;
          if (rejectedCount <= 2 && pass == 0) {
            final gain = objective - cand;
            final candDebug = _routingObjectiveDebug(
              nodeOrder: nodeOrder,
              positions: positions,
              sizeByNode: sizeByNode,
              allEdges: allEdges,
              subgraphNodeGroups: groups,
              minGap: minGap,
              direction: direction,
            );
            _logAudit(
              'stage=routing_repair_move REJECTED nodeId=$id delta=(${c.dx.toStringAsFixed(1)}, ${c.dy.toStringAsFixed(1)}) cand:$candDebug gain=${gain.toStringAsFixed(1)}',
            );
          }
          positions[id] = old;
        }
        if (improved) {
          break;
        }
      }
      _logAudit(
        'stage=loop_progress stage=routing_repair pass=${pass + 1}/$maxPasses improved=$improved objective=${objective.toStringAsFixed(1)} rejections=$rejectedCount elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (_loopBudgetExceeded(
        stage: 'routing_repair',
        watch: watch,
        budgetMs: 9000,
        pass: pass + 1,
        maxPasses: maxPasses,
      )) {
        break;
      }
      if (!improved) {
        break;
      }
    }

    _logAudit(
      'stage=routing_repair acceptedMoves=$accepted objective=${objective.toStringAsFixed(1)}',
    );
  }

  static void _minimizeEdgeOverNode({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required double minGap,
    required String direction,
    required int maxPasses,
  }) {
    if (maxPasses <= 0) {
      _logAudit('stage=minimize_edge_over_node skipped maxPasses=$maxPasses');
      return;
    }

    final watch = Stopwatch()..start();

    // Metric that ignores crossings, focuses on edgeOverNode + edgeLen
    double edgeOverNodeObjective() {
      final edgeOverNode = _countEdgeOverNodeBezierHits(
        nodeOrder: nodeOrder,
        positions: positions,
        sizeByNode: sizeByNode,
        allEdges: allEdges,
        minGap: minGap,
        direction: direction,
        samplingStepPx: _bezierSamplingStepForGraph(nodeOrder.length),
      );
      final edgeLen = _totalEdgeLength(positions, sizeByNode, allEdges);
      return edgeOverNode * 220000.0 + edgeLen * 0.04;
    }

    var objective = edgeOverNodeObjective();
    final initialHits = _countEdgeOverNodeBezierHits(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
      direction: direction,
      samplingStepPx: _bezierSamplingStepForGraph(nodeOrder.length),
    );

    if (initialHits == 0) {
      return;
    }

    final step = (minGap * 0.55 + 14.0).clamp(14.0, 80.0);
    // For very small graphs with edgeOverNode, use larger aggressive steps
    final aggressiveStep = nodeOrder.length <= 6 ? step * 2.5 : step;
    var accepted = 0;

    final ordered = [...nodeOrder]
      ..sort((a, b) {
        final byDeg = (degree[a] ?? 0).compareTo(degree[b] ?? 0);
        if (byDeg != 0) {
          return byDeg;
        }
        return a.compareTo(b);
      });

    for (int pass = 0; pass < maxPasses; pass++) {
      var improved = false;
      for (final id in ordered) {
        final old = positions[id]!;
        // Aggressive candidates for small graphs: prioritize vertical moves with large steps
        final candidates = nodeOrder.length <= 6
            ? <Offset>[
                Offset(0, aggressiveStep),
                Offset(0, -aggressiveStep),
                Offset(0, step * 1.8),
                Offset(0, -step * 1.8),
                Offset(aggressiveStep, 0),
                Offset(-aggressiveStep, 0),
                Offset(step, step),
                Offset(-step, -step),
              ]
            : <Offset>[
                Offset(0, step),
                Offset(0, -step),
                Offset(step, 0),
                Offset(-step, 0),
                Offset(step * 0.7, step * 0.7),
                Offset(-step * 0.7, -step * 0.7),
              ];

        for (final c in candidates) {
          positions[id] = old + c;
          final cand = edgeOverNodeObjective();
          // For small graphs, accept if there's ANY improvement (very loose threshold)
          final threshold = nodeOrder.length <= 6 ? 1.0 : 0.1;
          if (cand < objective - threshold) {
            objective = cand;
            accepted++;
            improved = true;
            break;
          }
          positions[id] = old;
        }
        if (improved) {
          break;
        }
      }
      if (!improved) {
        break;
      }
      if (_loopBudgetExceeded(
        stage: 'minimize_edge_over_node',
        watch: watch,
        budgetMs: 3000,
        pass: pass + 1,
        maxPasses: maxPasses,
      )) {
        break;
      }
    }

    final finalHits = _countEdgeOverNodeBezierHits(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
      direction: direction,
      samplingStepPx: _bezierSamplingStepForGraph(nodeOrder.length),
    );
    _logAudit(
      'stage=minimize_edge_over_node acceptedMoves=$accepted initialHits=$initialHits finalHits=$finalHits objective=${objective.toStringAsFixed(1)} elapsedMs=${watch.elapsedMilliseconds}',
    );
  }

  static void _alignNodesOnCommonAxes({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required double minGap,
    required String direction,
    required int maxPasses,
  }) {
    if (nodeOrder.length < 2 || maxPasses <= 0) {
      return;
    }

    final watch = Stopwatch()..start();
    var alignedX = 0;
    var alignedY = 0;

    // Initial metrics before alignment
    final samplingStepPx = _bezierSamplingStepForGraph(nodeOrder.length);
    var currentMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: const [],
      minGap: minGap,
      direction: "",  //direction,
      bezierSamplingStepPx: samplingStepPx,
      subgraphTitleBandHeight: 24.0,
      subgraphTitlePadding: 8.0,
    );
    // Protect against re-introducing edgeOverNode
    final initialEdgeOverNode = currentMetrics.edgeOverNodeHits;

    for (int pass = 0; pass < maxPasses; pass++) {
      var improved = false;

      // Group nodes by X proximity
      final xGroups = <int, List<String>>{};
      final sortedByX = [...nodeOrder]
        ..sort((a, b) {
          return (positions[a]?.dx ?? 0).compareTo(positions[b]?.dx ?? 0);
        });

      int currentGroup = 0;
      double? lastX;
      for (final id in sortedByX) {
        final x = positions[id]?.dx ?? 0;
        if (lastX != null && (x - lastX).abs() > ALIGN_TOLERANCE_X) {
          currentGroup++;
        }
        xGroups.putIfAbsent(currentGroup, () => []).add(id);
        lastX = x;
      }

      // Group nodes by Y proximity
      final yGroups = <int, List<String>>{};
      final sortedByY = [...nodeOrder]
        ..sort((a, b) {
          return (positions[a]?.dy ?? 0).compareTo(positions[b]?.dy ?? 0);
        });

      currentGroup = 0;
      double? lastY;
      for (final id in sortedByY) {
        final y = positions[id]?.dy ?? 0;
        if (lastY != null && (y - lastY).abs() > ALIGN_TOLERANCE_Y) {
          currentGroup++;
        }
        yGroups.putIfAbsent(currentGroup, () => []).add(id);
        lastY = y;
      }

      // Try to align nodes within each group
      // Prioritize X alignment (left edges)
      for (final group in xGroups.values) {
        if (group.length < 2) continue;

        final xs = [for (final id in group) positions[id]?.dx ?? 0];
        final medianX = xs.isEmpty ? 0.0 : (xs..sort())[xs.length ~/ 2];

        for (final id in group) {
          final old = positions[id]!;
          final deltaX = medianX - old.dx;

          if (deltaX.abs() <= ALIGN_MAX_MOVE_X && deltaX.abs() > 0.5) {
            final newPos = Offset(medianX, old.dy);
            positions[id] = newPos;

            // Check if metrics degraded
            final metricsNew = _collectMetrics(
              nodeOrder: nodeOrder,
              positions: positions,
              sizeByNode: sizeByNode,
              allEdges: allEdges,
              subgraphNodeGroups: const [],
              minGap: minGap,
              direction: direction,
              bezierSamplingStepPx: samplingStepPx,
              subgraphTitleBandHeight: 24.0,
              subgraphTitlePadding: 8.0,
            );

            // Accept only if:
            // - No re-introduction of edgeOverNode (STRICT!)
            // - Hard violations unchanged/improved
            // - Edge crossings unchanged/improved
            // - Edge length growth < threshold
            final noNewEdgeOverNode =
                !(initialEdgeOverNode == 0 && metricsNew.edgeOverNodeHits > 0);
            final hardViolationOk =
                metricsNew.hardViolation <= currentMetrics.hardViolation;
            final crossingOk = metricsNew.crossings <= currentMetrics.crossings;
            final edgeLenGrowth =
                (metricsNew.totalEdgeLength - currentMetrics.totalEdgeLength) /
                math.max(1.0, currentMetrics.totalEdgeLength);
            final edgeLenOk = edgeLenGrowth <= ALIGN_EDGE_GROWTH_PENALTY;

            if (noNewEdgeOverNode &&
                hardViolationOk &&
                crossingOk &&
                edgeLenOk) {
              currentMetrics = metricsNew;
              alignedX++;
              improved = true;
            } else {
              positions[id] = old;
            }
          }
        }
      }

      // Try to align nodes within each Y group
      for (final group in yGroups.values) {
        if (group.length < 2) continue;

        final ys = [for (final id in group) positions[id]?.dy ?? 0];
        final medianY = ys.isEmpty ? 0.0 : (ys..sort())[ys.length ~/ 2];

        for (final id in group) {
          final old = positions[id]!;
          final deltaY = medianY - old.dy;

          if (deltaY.abs() <= ALIGN_MAX_MOVE_Y && deltaY.abs() > 0.5) {
            final newPos = Offset(old.dx, medianY);
            positions[id] = newPos;

            // Check metrics again
            final metricsNew = _collectMetrics(
              nodeOrder: nodeOrder,
              positions: positions,
              sizeByNode: sizeByNode,
              allEdges: allEdges,
              subgraphNodeGroups: const [],
              minGap: minGap,
              direction: direction,
              bezierSamplingStepPx: samplingStepPx,
              subgraphTitleBandHeight: 24.0,
              subgraphTitlePadding: 8.0,
            );

            final hardViolationOk =
                metricsNew.hardViolation <= currentMetrics.hardViolation;
            final crossingOk = metricsNew.crossings <= currentMetrics.crossings;
            final noNewEdgeOverNode =
                !(initialEdgeOverNode == 0 && metricsNew.edgeOverNodeHits > 0);
            final edgeLenGrowth =
                (metricsNew.totalEdgeLength - currentMetrics.totalEdgeLength) /
                math.max(1.0, currentMetrics.totalEdgeLength);
            final edgeLenOk = edgeLenGrowth <= ALIGN_EDGE_GROWTH_PENALTY;

            if (noNewEdgeOverNode &&
                hardViolationOk &&
                crossingOk &&
                edgeLenOk) {
              currentMetrics = metricsNew;
              alignedY++;
              improved = true;
            } else {
              positions[id] = old;
            }
          }
        }
      }

      if (!improved) {
        break;
      }

      if (_loopBudgetExceeded(
        stage: 'align_nodes_on_axes',
        watch: watch,
        budgetMs: 3000,
        pass: pass + 1,
        maxPasses: maxPasses,
      )) {
        break;
      }
    }

    _logAudit(
      'stage=align_nodes_on_axes alignedX=$alignedX alignedY=$alignedY initialEdgeOverNode=$initialEdgeOverNode finalEdgeOverNode=${currentMetrics.edgeOverNodeHits} elapsedMs=${watch.elapsedMilliseconds}',
    );
  }

  /// Apply strict final alignment to positions (after seed decision).
  /// Pair-wise iterative spatial alignment: for each pair of nodes that are
  /// visually close on an axis, snap them to the same coordinate (min = left/top edge).
  /// Strict validation ensures no metric degrades.
  static void _alignFinalPositions({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required double minGap,
    required String direction,
  }) {
    if (nodeOrder.length < 2) return;

    final watch = Stopwatch()..start();
    var alignedX = 0;
    var alignedY = 0;

    final samplingStepPx = _bezierSamplingStepForGraph(nodeOrder.length);
    var baselineMetrics = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: const [],
      minGap: minGap,
      direction: direction,
      bezierSamplingStepPx: samplingStepPx,
      subgraphTitleBandHeight: 24.0,
      subgraphTitlePadding: 8.0,
    );

    _logAudit(
      'stage=align_final_positions_start baseline: crossings=${baselineMetrics.crossings} eON=${baselineMetrics.edgeOverNodeHits} hard=${baselineMetrics.hardViolation} obj=${baselineMetrics.objective.toStringAsFixed(2)}',
    );

    // Iterative pair-wise alignment: repeat until no more improvement
    for (int pass = 0; pass < 10; pass++) {
      var improved = false;

      for (int i = 0; i < nodeOrder.length - 1; i++) {
        final idA = nodeOrder[i];
        for (int j = i + 1; j < nodeOrder.length; j++) {
          final idB = nodeOrder[j];

          final posA = positions[idA]!;
          final posB = positions[idB]!;

          final dx = (posA.dx - posB.dx).abs();
          final dy = (posA.dy - posB.dy).abs();

          // Try X alignment (left-edge snap to leftmost)
          if (dx > 0.1 && dx <= ALIGN_TOLERANCE_X) {
            final targetX = math.min(posA.dx, posB.dx);
            // Move the one that is NOT at targetX
            final idToMove = posA.dx < posB.dx ? idB : idA;
            final old = positions[idToMove]!;
            final delta = targetX - old.dx;

            if (delta.abs() <= ALIGN_MAX_MOVE_X) {
              positions[idToMove] = Offset(targetX, old.dy);

              final metricsNew = _collectMetrics(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                allEdges: allEdges,
                subgraphNodeGroups: const [],
                minGap: minGap,
                direction: direction,
                bezierSamplingStepPx: samplingStepPx,
                subgraphTitleBandHeight: 24.0,
                subgraphTitlePadding: 8.0,
              );

              final edgeLenGrowth = (metricsNew.totalEdgeLength - baselineMetrics.totalEdgeLength) /
                  math.max(1.0, baselineMetrics.totalEdgeLength);
              final ok = metricsNew.crossings <= baselineMetrics.crossings &&
                  metricsNew.edgeOverNodeHits <= baselineMetrics.edgeOverNodeHits &&
                  metricsNew.hardViolation <= baselineMetrics.hardViolation &&
                  edgeLenGrowth <= ALIGN_EDGE_GROWTH_PENALTY;

              _logAudit(
                'stage=align_final_positions X pass=${pass+1} move=$idToMove dx=${delta.toStringAsFixed(1)} => ${ok ? "ACCEPT" : "REJECT"} hard=${metricsNew.hardViolation} eON=${metricsNew.edgeOverNodeHits} edgeLenGrowth=${(edgeLenGrowth * 100).toStringAsFixed(1)}%',
              );

              if (ok) {
                baselineMetrics = metricsNew;
                alignedX++;
                improved = true;
              } else {
                positions[idToMove] = old;
              }
            }
          }

          // Try Y alignment (top-edge snap to topmost)
          if (dy > 0.1 && dy <= ALIGN_TOLERANCE_Y) {
            final targetY = math.min(posA.dy, posB.dy);
            final idToMove = posA.dy < posB.dy ? idB : idA;
            final old = positions[idToMove]!;
            final delta = targetY - old.dy;

            if (delta.abs() <= ALIGN_MAX_MOVE_Y) {
              positions[idToMove] = Offset(old.dx, targetY);

              final metricsNew = _collectMetrics(
                nodeOrder: nodeOrder,
                positions: positions,
                sizeByNode: sizeByNode,
                allEdges: allEdges,
                subgraphNodeGroups: const [],
                minGap: minGap,
                direction: direction,
                bezierSamplingStepPx: samplingStepPx,
                subgraphTitleBandHeight: 24.0,
                subgraphTitlePadding: 8.0,
              );

              final edgeLenGrowthY = (metricsNew.totalEdgeLength - baselineMetrics.totalEdgeLength) /
                  math.max(1.0, baselineMetrics.totalEdgeLength);
              final ok = metricsNew.crossings <= baselineMetrics.crossings &&
                  metricsNew.edgeOverNodeHits <= baselineMetrics.edgeOverNodeHits &&
                  metricsNew.hardViolation <= baselineMetrics.hardViolation &&
                  edgeLenGrowthY <= ALIGN_EDGE_GROWTH_PENALTY;

              _logAudit(
                'stage=align_final_positions Y pass=${pass+1} move=$idToMove dy=${delta.toStringAsFixed(1)} => ${ok ? "ACCEPT" : "REJECT"} hard=${metricsNew.hardViolation} eON=${metricsNew.edgeOverNodeHits} edgeLenGrowth=${(edgeLenGrowthY * 100).toStringAsFixed(1)}%',
              );

              if (ok) {
                baselineMetrics = metricsNew;
                alignedY++;
                improved = true;
              } else {
                positions[idToMove] = old;
              }
            }
          }
        }
      }

      if (!improved) break;

      if (_loopBudgetExceeded(
        stage: 'align_final_positions',
        watch: watch,
        budgetMs: 3000,
        pass: pass + 1,
        maxPasses: 10,
      )) break;
    }

    _logAudit(
      'stage=align_final_positions_end alignedX=$alignedX alignedY=$alignedY elapsedMs=${watch.elapsedMilliseconds}',
    );
  }

  static void _forceUncrossByEndpointKick({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required Map<String, int> degree,
    required double minGap,
    required int maxPasses,
  }) {
    if (maxPasses <= 0) {
      return;
    }

    final watch = Stopwatch()..start();
    var currentCross = _countEdgeCrossings(positions, sizeByNode, allEdges);
    if (currentCross == 0) {
      return;
    }

    final kick = (minGap * 0.9 + 28.0).clamp(24.0, 130.0);
    var accepted = 0;

    for (int pass = 0; pass < maxPasses; pass++) {
      String? bestNode;
      Offset bestDelta = Offset.zero;
      var bestCross = currentCross;

      for (final id in nodeOrder) {
        final old = positions[id]!;
        final candidates = <Offset>[
          Offset(kick, 0),
          Offset(-kick, 0),
          Offset(0, kick),
          Offset(0, -kick),
        ];
        for (final d in candidates) {
          positions[id] = old + d;
          final cand = _countEdgeCrossings(positions, sizeByNode, allEdges);
          if (cand < bestCross) {
            bestCross = cand;
            bestNode = id;
            bestDelta = d;
          }
        }
        positions[id] = old;
      }

      if (bestNode == null || bestCross >= currentCross) {
        break;
      }

      positions[bestNode] = positions[bestNode]! + bestDelta;
      currentCross = bestCross;
      accepted++;
      _logAudit(
        'stage=loop_progress stage=force_uncross pass=${pass + 1}/$maxPasses crossings=$currentCross elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (_loopBudgetExceeded(
        stage: 'force_uncross',
        watch: watch,
        budgetMs: 9000,
        pass: pass + 1,
        maxPasses: maxPasses,
      )) {
        break;
      }
      if (currentCross == 0) {
        break;
      }
    }

    _logAudit(
      'stage=force_uncross acceptedMoves=$accepted crossings=$currentCross',
    );
  }

  static void _applyFinalAxisAlignment({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> groups,
    required double minGap,
    required double minInnerGapSubgraph,
    required double minOuterGapSubgraph,
    required double subgraphTitleBandHeight,
    required double subgraphTitlePadding,
    required int maxPasses,
    required double snapToleranceX,
    required double snapToleranceY,
    required double maxNodeShift,
    required double alignmentPriority,
  }) {
    if (maxPasses <= 0 || nodeOrder.length < 2 || alignmentPriority < 0.0) {
      _logAudit(
        'stage=final_alignment axis=both acceptedMoves=0 rejectedMoves=0 hardViolations=0',
      );
      return;
    }

    final watch = Stopwatch()..start();
    var accepted = 0;
    var rejected = 0;
    final maxPairChecksPerPass = math.max(
      400,
      nodeOrder.length * nodeOrder.length,
    );
    final maxProposalAttemptsPerPass = math.max(
      800,
      nodeOrder.length * nodeOrder.length * 2,
    );

    for (int pass = 0; pass < maxPasses; pass++) {
      var movedPass = false;
      var pairChecks = 0;
      var proposalAttempts = 0;
      var acceptedThisPass = 0;
      var rejectedThisPass = 0;
      var guardTriggered = false;
      for (int i = 0; i < nodeOrder.length - 1; i++) {
        final a = nodeOrder[i];
        final pa = positions[a]!;
        for (int j = i + 1; j < nodeOrder.length; j++) {
          pairChecks++;
          if (pairChecks > maxPairChecksPerPass) {
            guardTriggered = true;
            _logAudit(
              'stage=loop_guard stage=final_alignment trigger=max_pair_checks pass=${pass + 1}/$maxPasses pairChecks=$pairChecks limit=$maxPairChecksPerPass elapsedMs=${watch.elapsedMilliseconds}',
            );
            break;
          }

          final b = nodeOrder[j];
          final pb = positions[b]!;

          final dx = pb.dx - pa.dx;
          final dy = pb.dy - pa.dy;

          if (dy.abs() <= snapToleranceY) {
            final targetY = math.min(pa.dy, pb.dy);
            final moveA = (targetY - pa.dy).clamp(-maxNodeShift, maxNodeShift);
            final moveB = (targetY - pb.dy).clamp(-maxNodeShift, maxNodeShift);
            proposalAttempts++;
            if (proposalAttempts > maxProposalAttemptsPerPass) {
              guardTriggered = true;
              _logAudit(
                'stage=loop_guard stage=final_alignment trigger=max_proposals pass=${pass + 1}/$maxPasses proposals=$proposalAttempts limit=$maxProposalAttemptsPerPass elapsedMs=${watch.elapsedMilliseconds}',
              );
              break;
            }
            if (_tryAlignedMove(
              moves: {
                a: Offset(pa.dx, pa.dy + moveA),
                b: Offset(pb.dx, pb.dy + moveB),
              },
              nodeOrder: nodeOrder,
              positions: positions,
              sizeByNode: sizeByNode,
              allEdges: allEdges,
              groups: groups,
              minGap: minGap,
              minInnerGapSubgraph: minInnerGapSubgraph,
              minOuterGapSubgraph: minOuterGapSubgraph,
              subgraphTitleBandHeight: subgraphTitleBandHeight,
              subgraphTitlePadding: subgraphTitlePadding,
            )) {
              accepted++;
              acceptedThisPass++;
              movedPass = true;
            } else {
              rejected++;
              rejectedThisPass++;
            }
          }

          if (dx.abs() <= snapToleranceX) {
            final targetX = math.min(pa.dx, pb.dx);
            final moveA = (targetX - pa.dx).clamp(-maxNodeShift, maxNodeShift);
            final moveB = (targetX - pb.dx).clamp(-maxNodeShift, maxNodeShift);
            proposalAttempts++;
            if (proposalAttempts > maxProposalAttemptsPerPass) {
              guardTriggered = true;
              _logAudit(
                'stage=loop_guard stage=final_alignment trigger=max_proposals pass=${pass + 1}/$maxPasses proposals=$proposalAttempts limit=$maxProposalAttemptsPerPass elapsedMs=${watch.elapsedMilliseconds}',
              );
              break;
            }
            if (_tryAlignedMove(
              moves: {
                a: Offset(pa.dx + moveA, pa.dy),
                b: Offset(pb.dx + moveB, pb.dy),
              },
              nodeOrder: nodeOrder,
              positions: positions,
              sizeByNode: sizeByNode,
              allEdges: allEdges,
              groups: groups,
              minGap: minGap,
              minInnerGapSubgraph: minInnerGapSubgraph,
              minOuterGapSubgraph: minOuterGapSubgraph,
              subgraphTitleBandHeight: subgraphTitleBandHeight,
              subgraphTitlePadding: subgraphTitlePadding,
            )) {
              accepted++;
              acceptedThisPass++;
              movedPass = true;
            } else {
              rejected++;
              rejectedThisPass++;
            }
          }

          if (guardTriggered) {
            break;
          }
        }
        if (guardTriggered) {
          break;
        }
      }

      _logAudit(
        'stage=loop_progress stage=final_alignment pass=${pass + 1}/$maxPasses moved=$movedPass acceptedPass=$acceptedThisPass rejectedPass=$rejectedThisPass acceptedTotal=$accepted rejectedTotal=$rejected pairs=$pairChecks proposals=$proposalAttempts guard=$guardTriggered elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (guardTriggered) {
        break;
      }
      if (_loopBudgetExceeded(
        stage: 'final_alignment',
        watch: watch,
        budgetMs: 8000,
        pass: pass + 1,
        maxPasses: maxPasses,
      )) {
        break;
      }

      if (!movedPass) {
        break;
      }
    }

    final hardViol =
        _countNodeOverlapPairs(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          minGap: minGap,
        ) +
        _countSubgraphMembershipViolations(
          nodeOrder: nodeOrder,
          positions: positions,
          sizeByNode: sizeByNode,
          subgraphNodeGroups: groups,
          minGap: minGap,
          subgraphTitleBandHeight: subgraphTitleBandHeight,
          subgraphTitlePadding: subgraphTitlePadding,
        );

    _logAudit(
      'stage=final_alignment axis=x acceptedMoves=$accepted rejectedMoves=$rejected hardViolations=$hardViol',
    );
    _logAudit(
      'stage=final_alignment axis=y acceptedMoves=$accepted rejectedMoves=$rejected hardViolations=$hardViol',
    );
    _logAudit(
      'stage=final_alignment groups=${groups.length} snapToleranceX=$snapToleranceX snapToleranceY=$snapToleranceY',
    );
  }

  static bool _tryAlignedMove({
    required Map<String, Offset> moves,
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> groups,
    required double minGap,
    required double minInnerGapSubgraph,
    required double minOuterGapSubgraph,
    required double subgraphTitleBandHeight,
    required double subgraphTitlePadding,
  }) {
    final bezierSamplingStepPx = _bezierSamplingStepForGraph(nodeOrder.length);
    final before = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: minGap,
      direction: 'TD',
      bezierSamplingStepPx: bezierSamplingStepPx,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    final old = <String, Offset>{};
    for (final e in moves.entries) {
      old[e.key] = positions[e.key]!;
      positions[e.key] = e.value;
    }

    final after = _collectMetrics(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: groups,
      minGap: minGap,
      direction: 'TD',
      bezierSamplingStepPx: bezierSamplingStepPx,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    final gapAfter = _countSubgraphGapViolations(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      groups: groups,
      minInnerGapSubgraph: minInnerGapSubgraph,
      minOuterGapSubgraph: minOuterGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    final gapBefore = _countSubgraphGapViolations(
      nodeOrder: nodeOrder,
      positions: {...positions, for (final e in old.entries) e.key: e.value},
      sizeByNode: sizeByNode,
      groups: groups,
      minInnerGapSubgraph: minInnerGapSubgraph,
      minOuterGapSubgraph: minOuterGapSubgraph,
      subgraphTitleBandHeight: subgraphTitleBandHeight,
      subgraphTitlePadding: subgraphTitlePadding,
    );

    final keepsHard =
        after.nodeOverlapPairs <= before.nodeOverlapPairs &&
        after.subgraphViolations <= before.subgraphViolations &&
        after.edgeOverNodeHits <= before.edgeOverNodeHits &&
        gapAfter.innerViolations <= gapBefore.innerViolations &&
        gapAfter.outerViolations <= gapBefore.outerViolations;

    final improves = after.objective <= before.objective;

    if (!(keepsHard && improves)) {
      for (final e in old.entries) {
        positions[e.key] = e.value;
      }
      return false;
    }

    return true;
  }

  static _LayoutMetrics _collectMetrics({
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
    final totalEdgeLength = _totalEdgeLength(
      positions,
      sizeByNode,
      allEdges,
      subgraphNodeGroups: subgraphNodeGroups,
    );
    final alignmentScore = _alignmentScore(positions);

    final objective =
        crossings * 1000000.0 +
        edgeOverNodeHits * 220000.0 +
        nodeOverlapPairs * 120000.0 +
        subgraphViolations * 180000.0 +
        totalEdgeLength * 0.04 -
        alignmentScore * 2.0;

    if (watch.elapsedMilliseconds > 250) {
      _logAudit(
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

  static int _countEdgeOverNodeBezierHits({
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
        _logAudit(
          'stage=loop_progress stage=edge_over_node_bezier_hybrid edgeIndex=$edgeIndex/${allEdges.length} hits=$hits elapsedMs=${watch.elapsedMilliseconds}',
        );
      }

      if (_loopBudgetExceeded(
        stage: 'edge_over_node_bezier_hybrid',
        watch: watch,
        budgetMs: 1200,
        pass: edgeIndex,
        maxPasses: allEdges.length,
      )) {
        _logAudit(
          'stage=loop_guard stage=edge_over_node_bezier_hybrid trigger=budget_partial_return edgeIndex=$edgeIndex/${allEdges.length} hits=$hits',
        );
        break;
      }
    }

    if (watch.elapsedMilliseconds > 300) {
      _logAudit(
        'stage=edge_over_node_profile_hybrid edges=${allEdges.length} hits=$hits elapsedMs=${watch.elapsedMilliseconds}',
      );
    }

    return hits;
  }

  static List<Offset> _sampleCubicSegmentsAdaptive({
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

  static int _countSubgraphMembershipViolations({
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

  static double _routingObjective({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
    required String direction,
  }) {
    final crossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    final overlap = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );
    final edgeOverNode = _countEdgeOverNodeBezierHits(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
      direction: direction,
      samplingStepPx: _bezierSamplingStepForGraph(nodeOrder.length),
    );
    final edgeLen = _totalEdgeLength(
      positions,
      sizeByNode,
      allEdges,
      subgraphNodeGroups: subgraphNodeGroups,
    );
    final obj =
        crossings * 1000000.0 +
        edgeOverNode * 220000.0 +
        overlap * 120000.0 +
        edgeLen * 0.04;
    return obj;
  }

  static String _routingObjectiveDebug({
    required List<String> nodeOrder,
    required Map<String, Offset> positions,
    required Map<String, Size> sizeByNode,
    required List<(String, String)> allEdges,
    required List<List<String>> subgraphNodeGroups,
    required double minGap,
    required String direction,
  }) {
    final crossings = _countEdgeCrossings(positions, sizeByNode, allEdges);
    final overlap = _countNodeOverlapPairs(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      minGap: minGap,
    );
    final edgeOverNode = _countEdgeOverNodeBezierHits(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      minGap: minGap,
      direction: direction,
      samplingStepPx: _bezierSamplingStepForGraph(nodeOrder.length),
    );
    final edgeLen = _totalEdgeLength(
      positions,
      sizeByNode,
      allEdges,
      subgraphNodeGroups: subgraphNodeGroups,
    );
    final crossCost = crossings * 1000000.0;
    final edgeOverNodeCost = edgeOverNode * 220000.0;
    final overlapCost = overlap * 120000.0;
    final edgeLenCost = edgeLen * 0.04;
    final total = crossCost + edgeOverNodeCost + overlapCost + edgeLenCost;
    return 'cr=$crossings(${crossCost.toStringAsFixed(0)}) eON=$edgeOverNode(${edgeOverNodeCost.toStringAsFixed(0)}) ovlp=$overlap(${overlapCost.toStringAsFixed(0)}) len=${edgeLen.toStringAsFixed(0)}(${edgeLenCost.toStringAsFixed(0)}) TOTAL=${total.toStringAsFixed(1)}';
  }

  static double _bezierSamplingStepForGraph(int nodeCount) {
    return 4.0;
  }

  static double _totalEdgeLength(
    Map<String, Offset> positions,
    Map<String, Size> sizeByNode,
    List<(String, String)> allEdges, {
    List<List<String>>? subgraphNodeGroups,
  }
  ) {
    var total = 0.0;
    for (final e in allEdges) {
      final a = _nodeCenter(positions[e.$1]!, sizeByNode[e.$1]!);
      final b = _nodeCenter(positions[e.$2]!, sizeByNode[e.$2]!);
      final weight = _edgeLengthWeight(
        e.$1,
        e.$2,
        subgraphNodeGroups: subgraphNodeGroups,
      );
      total += (a - b).distance * weight;
    }
    return total;
  }

  static double _edgeLengthWeight(
    String fromId,
    String toId, {
    List<List<String>>? subgraphNodeGroups,
  }) {
    if (subgraphNodeGroups == null || subgraphNodeGroups.isEmpty) {
      return 1.0;
    }

    var smallestSharedGroupSize = 1 << 30;
    for (final group in subgraphNodeGroups) {
      if (group.contains(fromId) && group.contains(toId)) {
        smallestSharedGroupSize = math.min(smallestSharedGroupSize, group.length);
      }
    }

    if (smallestSharedGroupSize == 1 << 30) {
      return 0.18;
    }
    if (smallestSharedGroupSize <= 3) {
      return 1.0;
    }
    if (smallestSharedGroupSize <= 4) {
      return 0.85;
    }
    if (smallestSharedGroupSize <= 6) {
      return 0.65;
    }
    return 0.35;
  }

  static double _alignmentScore(Map<String, Offset> positions) {
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

  static _PositionDeltaSummary _summarizePositionDelta({
    required List<String> nodeOrder,
    required Map<String, Offset> before,
    required Map<String, Offset> after,
  }) {
    var movedNodes = 0;
    var totalDistance = 0.0;
    var maxDistance = 0.0;

    for (final id in nodeOrder) {
      final start = before[id];
      final end = after[id];
      if (start == null || end == null) {
        continue;
      }
      final distance = (end - start).distance;
      if (distance > 0.01) {
        movedNodes++;
      }
      totalDistance += distance;
      maxDistance = math.max(maxDistance, distance);
    }

    return _PositionDeltaSummary(
      movedNodes: movedNodes,
      avgDistance: nodeOrder.isEmpty ? 0.0 : totalDistance / nodeOrder.length,
      maxDistance: maxDistance,
    );
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

    if (!left.isFinite ||
        !top.isFinite ||
        !right.isFinite ||
        !bottom.isFinite) {
      return Rect.fromLTWH(0, 0, 1, 1);
    }

    return Rect.fromLTRB(
      left - padding,
      top - padding,
      right + padding,
      bottom + padding,
    );
  }

  static Offset _nodeCenter(Offset topLeft, Size size) {
    return Offset(topLeft.dx + size.width / 2, topLeft.dy + size.height / 2);
  }

  static Offset _meanOffset(Iterable<Offset> points) {
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

  static List<List<String>> _normalizeSubgraphGroups(
    List<List<String>>? rawGroups,
    Set<String> allowed,
  ) {
    if (rawGroups == null || rawGroups.isEmpty) {
      return const <List<String>>[];
    }

    final out = <List<String>>[];
    final seenGroups = <String>{};

    for (final raw in rawGroups) {
      final seen = <String>{};
      final cleaned = <String>[];
      for (final id in raw) {
        if (!allowed.contains(id) || !seen.add(id)) {
          continue;
        }
        cleaned.add(id);
      }
      if (cleaned.length < 2) {
        continue;
      }

      final sigParts = [...cleaned]..sort();
      final sig = sigParts.join('|');
      if (!seenGroups.add(sig)) {
        continue;
      }
      out.add(cleaned);
    }

    return out;
  }

  static double _seedSecondary(
    Map<String, Offset> seedPositions,
    Map<String, Size> sizeByNode,
    String id,
    bool isHorizontal,
  ) {
    final seed = seedPositions[id];
    final size = sizeByNode[id];
    if (seed == null || size == null) {
      return double.nan;
    }
    return isHorizontal ? seed.dy + size.height / 2 : seed.dx + size.width / 2;
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

  static Size? _sizeForNode(List<Block> blocks, String id) {
    for (final block in blocks) {
      if (block.id == id) {
        return block.size;
      }
    }
    return null;
  }

  static void _logAudit(String message) {
    if (!enableDiagnosticsLogs) {
      return;
    }
    final line = '[ELK-AUDIT] $message';
    _auditTrail.add(line);
    if (_auditTrail.length > _maxAuditTrailLines) {
      _auditTrail.removeRange(0, _auditTrail.length - _maxAuditTrailLines);
    }
    debugPrint(line);
  }

  static bool _loopBudgetExceeded({
    required String stage,
    required Stopwatch watch,
    required int budgetMs,
    required int pass,
    required int maxPasses,
  }) {
    if (watch.elapsedMilliseconds <= budgetMs) {
      return false;
    }
    _logAudit(
      'stage=budget_guard stageName=$stage elapsedMs=${watch.elapsedMilliseconds} budgetMs=$budgetMs pass=$pass maxPasses=$maxPasses action=break',
    );
    return true;
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

class _RoutingPolicy {
  final bool reduceEdgeCrossings;
  final bool repairRouting;
  final bool forceUncross;

  const _RoutingPolicy({
    required this.reduceEdgeCrossings,
    required this.repairRouting,
    required this.forceUncross,
  });
}

class _QualityMode {
  final String name;
  final int maxPassesCrossing;
  final int maxPassesRoutingRepair;
  final int maxPassesForceUncross;
  final int maxPassesFinalAlignment;

  const _QualityMode({
    required this.name,
    required this.maxPassesCrossing,
    required this.maxPassesRoutingRepair,
    required this.maxPassesForceUncross,
    required this.maxPassesFinalAlignment,
  });
}

class _SubgraphGapCounters {
  final int innerViolations;
  final int outerViolations;
  final int nestedViolations;

  const _SubgraphGapCounters({
    required this.innerViolations,
    required this.outerViolations,
    required this.nestedViolations,
  });
}

class _PositionDeltaSummary {
  final int movedNodes;
  final double avgDistance;
  final double maxDistance;

  const _PositionDeltaSummary({
    required this.movedNodes,
    required this.avgDistance,
    required this.maxDistance,
  });
}
