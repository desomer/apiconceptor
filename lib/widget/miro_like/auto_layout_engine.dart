import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/block_model.dart';

part 'auto_layout_engine_metrics.dart';

class AutoLayoutQualityProfile {
  // Kept for API compatibility with existing callers.
  // In the simplified engine, spacingMul is the primary active knob.
  final double
  iterationMul; // Ajuste le nombre d'iterations de l'ancien moteur
  final double
  repulsionMul; // Reglage de repulsion entre noeuds 
  final double
  springMul; // Reglage  de force de ressort sur les liens (compatibilite).
  final double
  overlapMul; // Poids historique de reduction des chevauchements (compatibilite).
  final double
  hpwlMul; // Poids historique de compaction de longueur de liens (compatibilite).
  final double
  crossingMul; // Poids historique de penalisation des croisements (compatibilite).
  final double
  spacingMul; // Parametre actif: echelle des espacements horizontal/vertical du layout en lignes.
  final int
  channelPitch; // Reglage historique d'espacement de canaux de routage (compatibilite).
  final double
  snapTargetWeight; // Reglage historique de priorite de snapping vers cibles (compatibilite).
  final double
  alignmentPriority; // Reglage historique de priorite d'alignement final (compatibilite).
  final double
  seededAlignmentPriority; // Reglage historique d'alignement depuis seed layout (compatibilite).

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
    return _collectDebugMetricsImpl(
      nodeOrder: nodeOrder,
      positions: positions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: subgraphNodeGroups,
      minGap: minGap,
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
      return <String, Offset>{};
    }

    final spacingFactor = quality.spacingMul.clamp(0.5, 4.0);
    final sizeByNode = <String, Size>{
      for (final id in nodeOrder)
        id: _sizeForNode(effectiveBlocks, id) ?? const Size(150, 100),
    };

    final maxWidth = sizeByNode.values.fold<double>(
      0,
      (maxVal, s) => math.max(maxVal, s.width),
    );
    final maxHeight = sizeByNode.values.fold<double>(
      0,
      (maxVal, s) => math.max(maxVal, s.height),
    );

    final horizontalGap = math.max(24.0, 80.0 * spacingFactor);
    final verticalGap = math.max(24.0, 70.0 * spacingFactor);

    final stepX = maxWidth + horizontalGap;
    final stepY = maxHeight + verticalGap;

    final cols = math.max(1, math.sqrt(nodeOrder.length).ceil());
    final rowCount = (nodeOrder.length / cols).ceil();

    final positions = <String, Offset>{};

    // Deterministic row-based placement: stable and fast.
    for (int i = 0; i < nodeOrder.length; i++) {
      final id = nodeOrder[i];
      final row = i ~/ cols;
      final col = i % cols;

      var x = col * stepX;
      var y = row * stepY;

      if (direction == 'RL') {
        x = (cols - 1 - col) * stepX;
      }
      if (direction == 'BT') {
        y = (rowCount - 1 - row) * stepY;
      }

      positions[id] = Offset(x, y);
    }

    _logAudit('stage=renderer_choice renderer=row-layout');
    _logAudit(
      'stage=model_order rows=$rowCount cols=$cols direction=$direction',
    );

    final selfLoops = edgeData.where((e) => e.fromId == e.toId).length;
    _logAudit('stage=self_loop routingApplied=true selfLoops=$selfLoops');

    return positions;
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
