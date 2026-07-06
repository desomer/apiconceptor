import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jsonschema/widget/miro_like/auto_layout_engine.dart';
import 'package:jsonschema/widget/miro_like/models/block_model.dart';

/// Graph corpus proposed for non-regression and tuning.
///
/// Included fixtures:
/// - sparse20: sparse graph with 20 nodes
/// - dense40: dense graph with 40 nodes
/// - hubGraph: star/hub heavy graph
/// - nestedSubgraphs: nested subgraph hierarchy fixture
/// - multiEdgesSelfLoops: repeated edges + self loops fixture
void main() {
  const quality = AutoLayoutQualityProfile(
    iterationMul: 1.0,
    repulsionMul: 1.0,
    springMul: 1.0,
    overlapMul: 1.0,
    hpwlMul: 1.0,
    crossingMul: 1.0,
    spacingMul: 1.0,
    channelPitch: 2,
    snapTargetWeight: 0.45,
    alignmentPriority: 1.0,
  );

  group('AutoLayoutEngine corpus', () {
    test('empty graph returns empty layout', () {
      final result = AutoLayoutEngine.computeMermaidAutoLayout(
        nodeOrder: const <String>[],
        edgeData: const <({String fromId, String toId, String label})>[],
        direction: 'TD',
        effectiveBlocks: const <Block>[],
        quality: quality,
      );

      expect(result, isEmpty);
    });

    test('sparse20 keeps zero hard violations', () {
      final fixture = _sparse20Fixture();
      final result = AutoLayoutEngine.computeMermaidAutoLayout(
        nodeOrder: fixture.nodeOrder,
        edgeData: fixture.edges,
        direction: 'TD',
        effectiveBlocks: fixture.blocks,
        quality: quality,
        subgraphNodeGroups: const <List<String>>[],
      );

      _expectFinitePositions(result, fixture.nodeOrder);

      final metrics = AutoLayoutEngine.collectDebugMetrics(
        nodeOrder: fixture.nodeOrder,
        positions: result,
        sizeByNode: fixture.sizeByNode,
        allEdges: fixture.allEdges,
        subgraphNodeGroups: const <List<String>>[],
        minGap: 24,
      );

      expect(metrics.hardViolation, equals(0));
      expect(metrics.nodeOverlapPairs, equals(0));
    });

    test(
      'dense40 uses row renderer and returns stable output',
      () {
        final fixture = _dense40Fixture();
        AutoLayoutEngine.clearAuditTrail();
        printOnFailure(
          '[dense40] nodes=${fixture.nodeOrder.length} edges=${fixture.allEdges.length}',
        );

        final swA = Stopwatch()..start();

        final resultA = AutoLayoutEngine.computeMermaidAutoLayout(
          nodeOrder: fixture.nodeOrder,
          edgeData: fixture.edges,
          direction: 'LR',
          effectiveBlocks: fixture.blocks,
          quality: quality,
        );
        swA.stop();
        printOnFailure('[dense40] compute A: ${swA.elapsedMilliseconds}ms');

        final logsA = AutoLayoutEngine.getAuditTrailSnapshot().join('\n');
        printOnFailure('[dense40] audit A tail:\n${_tailLines(logsA, 40)}');

        AutoLayoutEngine.clearAuditTrail();
        final swB = Stopwatch()..start();
        final resultB = AutoLayoutEngine.computeMermaidAutoLayout(
          nodeOrder: fixture.nodeOrder,
          edgeData: fixture.edges,
          direction: 'LR',
          effectiveBlocks: fixture.blocks,
          quality: quality,
        );
        swB.stop();
        printOnFailure('[dense40] compute B: ${swB.elapsedMilliseconds}ms');

        _expectFinitePositions(resultA, fixture.nodeOrder);
        _expectFinitePositions(resultB, fixture.nodeOrder);
        _expectDeterministic(resultA, resultB, fixture.nodeOrder);

        final logs = AutoLayoutEngine.getAuditTrailSnapshot().join('\n');
        expect(
          logs.contains('stage=renderer_choice renderer=row-layout'),
          isTrue,
        );
        expect(swA.elapsed.inSeconds, lessThan(25));
        expect(swB.elapsed.inSeconds, lessThan(25));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test('nestedSubgraphs returns coherent metrics', () {
      final fixture = _nestedSubgraphsFixture();

      final result = AutoLayoutEngine.computeMermaidAutoLayout(
        nodeOrder: fixture.nodeOrder,
        edgeData: fixture.edges,
        direction: 'TD',
        effectiveBlocks: fixture.blocks,
        quality: quality,
        subgraphNodeGroups: fixture.subgraphGroups,
      );

      _expectFinitePositions(result, fixture.nodeOrder);

      final metrics = AutoLayoutEngine.collectDebugMetrics(
        nodeOrder: fixture.nodeOrder,
        positions: result,
        sizeByNode: fixture.sizeByNode,
        allEdges: fixture.allEdges,
        subgraphNodeGroups: fixture.subgraphGroups,
        minGap: 24,
      );

      expect(metrics.subgraphViolations, greaterThanOrEqualTo(0));
      expect(
        metrics.hardViolation,
        equals(metrics.nodeOverlapPairs + metrics.subgraphViolations),
      );
    });

    test(
      'multiEdgesSelfLoops fixture runs and logs self loop routing stage',
      () {
        final fixture = _multiEdgesSelfLoopsFixture();
        AutoLayoutEngine.clearAuditTrail();

        final result = AutoLayoutEngine.computeMermaidAutoLayout(
          nodeOrder: fixture.nodeOrder,
          edgeData: fixture.edges,
          direction: 'BT',
          effectiveBlocks: fixture.blocks,
          quality: quality,
        );

        _expectFinitePositions(result, fixture.nodeOrder);

        final logs = AutoLayoutEngine.getAuditTrailSnapshot().join('\n');
        expect(logs.contains('stage=self_loop routingApplied=true'), isTrue);
      },
    );

    test('metrics are internally coherent across fixtures', () {
      final fixtures = <_TestFixture>[
        _sparse20Fixture(),
        _dense40Fixture(),
        _nestedSubgraphsFixture(),
        _multiEdgesSelfLoopsFixture(),
      ];

      for (final fixture in fixtures) {
        final result = AutoLayoutEngine.computeMermaidAutoLayout(
          nodeOrder: fixture.nodeOrder,
          edgeData: fixture.edges,
          direction: 'TD',
          effectiveBlocks: fixture.blocks,
          quality: quality,
          subgraphNodeGroups: fixture.subgraphGroups,
        );

        _expectFinitePositions(result, fixture.nodeOrder);

        final metrics = AutoLayoutEngine.collectDebugMetrics(
          nodeOrder: fixture.nodeOrder,
          positions: result,
          sizeByNode: fixture.sizeByNode,
          allEdges: fixture.allEdges,
          subgraphNodeGroups: fixture.subgraphGroups,
          minGap: 24,
        );

        expect(
          metrics.hardViolation,
          equals(metrics.nodeOverlapPairs + metrics.subgraphViolations),
          reason:
              'hardViolation mismatch on fixture ${fixture.nodeOrder.first}',
        );
        expect(metrics.crossings, greaterThanOrEqualTo(0));
        expect(metrics.edgeOverNodeHits, greaterThanOrEqualTo(0));
        expect(metrics.totalEdgeLength.isFinite, isTrue);
        expect(metrics.objective.isFinite, isTrue);
      }
    });

    test('pipeline logs are coherent with simplified engine stages', () {
      final fixture = _dense40Fixture();
      final strictQuality = AutoLayoutQualityProfile(
        iterationMul: 1.2,
        repulsionMul: 1.0,
        springMul: 1.0,
        overlapMul: 1.2,
        hpwlMul: 1.0,
        crossingMul: 1.3,
        spacingMul: 1.0,
        channelPitch: 2,
        snapTargetWeight: 0.45,
        alignmentPriority: 1.0,
      );

      final seedPositions = <String, Offset>{
        for (final b in fixture.blocks) b.id: b.position,
      };

      AutoLayoutEngine.clearAuditTrail();
      AutoLayoutEngine.computeMermaidAutoLayout(
        nodeOrder: fixture.nodeOrder,
        edgeData: fixture.edges,
        direction: 'LR',
        effectiveBlocks: fixture.blocks,
        quality: strictQuality,
        seedPositions: seedPositions,
        subgraphNodeGroups: _nestedSubgraphsFixture().subgraphGroups,
      );

      final logs = AutoLayoutEngine.getAuditTrailSnapshot().join('\n');
      expect(
        logs.contains('stage=renderer_choice renderer=row-layout'),
        isTrue,
      );
      expect(logs.contains('stage=model_order'), isTrue);
      expect(logs.contains('stage=self_loop routingApplied=true'), isTrue);
    });

    test('strict profile still returns coherent and aligned output', () {
      final fixtures = <_TestFixture>[
        _sparse20Fixture(),
        _hubGraphFixture(),
        _nestedSubgraphsFixture(),
      ];

      const strictQuality = AutoLayoutQualityProfile(
        iterationMul: 1.2,
        repulsionMul: 1.0,
        springMul: 1.0,
        overlapMul: 1.2,
        hpwlMul: 1.0,
        crossingMul: 1.3,
        spacingMul: 1.0,
        channelPitch: 2,
        snapTargetWeight: 0.45,
        alignmentPriority: 1.0,
      );

      for (final fixture in fixtures) {
        final result = AutoLayoutEngine.computeMermaidAutoLayout(
          nodeOrder: fixture.nodeOrder,
          edgeData: fixture.edges,
          direction: 'TD',
          effectiveBlocks: fixture.blocks,
          quality: strictQuality,
          subgraphNodeGroups: fixture.subgraphGroups,
        );

        _expectFinitePositions(result, fixture.nodeOrder);

        final metrics = AutoLayoutEngine.collectDebugMetrics(
          nodeOrder: fixture.nodeOrder,
          positions: result,
          sizeByNode: fixture.sizeByNode,
          allEdges: fixture.allEdges,
          subgraphNodeGroups: fixture.subgraphGroups,
          minGap: 24,
        );

        expect(metrics.nodeOverlapPairs, greaterThanOrEqualTo(0));
        expect(metrics.subgraphViolations, greaterThanOrEqualTo(0));
        expect(metrics.edgeOverNodeHits, greaterThanOrEqualTo(0));

        final alignedPairs = _countAlignedPairs(result, tolerance: 4);
        expect(
          alignedPairs,
          greaterThanOrEqualTo(fixture.nodeOrder.length ~/ 3),
          reason:
              'Expected visible row/column alignment for ${fixture.nodeOrder.first}',
        );
      }
    });

    test('objective lower bound remains coherent with weighted metrics', () {
      final fixtures = <_TestFixture>[
        _sparse20Fixture(),
        _dense40Fixture(),
        _hubGraphFixture(),
        _nestedSubgraphsFixture(),
        _multiEdgesSelfLoopsFixture(),
      ];

      for (final fixture in fixtures) {
        final result = AutoLayoutEngine.computeMermaidAutoLayout(
          nodeOrder: fixture.nodeOrder,
          edgeData: fixture.edges,
          direction: 'TD',
          effectiveBlocks: fixture.blocks,
          quality: quality,
          subgraphNodeGroups: fixture.subgraphGroups,
        );

        final metrics = AutoLayoutEngine.collectDebugMetrics(
          nodeOrder: fixture.nodeOrder,
          positions: result,
          sizeByNode: fixture.sizeByNode,
          allEdges: fixture.allEdges,
          subgraphNodeGroups: fixture.subgraphGroups,
          minGap: 24,
        );

        final lowerBound =
            metrics.crossings * 1000000.0 +
            metrics.edgeOverNodeHits * 220000.0 +
            metrics.nodeOverlapPairs * 120000.0 +
            metrics.subgraphViolations * 180000.0 -
            metrics.alignmentScore * 2.0;

        expect(
          metrics.objective,
          greaterThanOrEqualTo(lowerBound),
          reason: 'Objective coherence broken on ${fixture.nodeOrder.first}',
        );
      }
    });
  });
}

void _expectFinitePositions(
  Map<String, Offset> positions,
  List<String> nodeOrder,
) {
  expect(positions.length, equals(nodeOrder.length));
  for (final id in nodeOrder) {
    final p = positions[id];
    expect(p, isNotNull, reason: 'Missing position for node $id');
    expect(p!.dx.isFinite, isTrue, reason: 'dx is not finite for node $id');
    expect(p.dy.isFinite, isTrue, reason: 'dy is not finite for node $id');
  }
}

void _expectDeterministic(
  Map<String, Offset> a,
  Map<String, Offset> b,
  List<String> nodeOrder,
) {
  for (final id in nodeOrder) {
    final pa = a[id]!;
    final pb = b[id]!;
    expect((pa.dx - pb.dx).abs() < 1e-6, isTrue, reason: 'dx drift on $id');
    expect((pa.dy - pb.dy).abs() < 1e-6, isTrue, reason: 'dy drift on $id');
  }
}

_TestFixture _sparse20Fixture() {
  final nodes = List<String>.generate(20, (i) => 'n$i');
  final edges = <({String fromId, String toId, String label})>[
    for (int i = 0; i < 19; i++) (fromId: 'n$i', toId: 'n${i + 1}', label: ''),
    (fromId: 'n0', toId: 'n5', label: ''),
    (fromId: 'n2', toId: 'n8', label: ''),
    (fromId: 'n6', toId: 'n12', label: ''),
    (fromId: 'n9', toId: 'n15', label: ''),
    (fromId: 'n11', toId: 'n18', label: ''),
  ];
  return _fixtureFrom(nodes, edges);
}

_TestFixture _dense40Fixture() {
  final nodes = List<String>.generate(40, (i) => 'd$i');
  final edges = <({String fromId, String toId, String label})>[];

  for (int i = 0; i < nodes.length; i++) {
    final next = i + 1;
    if (next < nodes.length) {
      edges.add((fromId: nodes[i], toId: nodes[next], label: ''));
    }
    final longJump = i + 5;
    if (longJump < nodes.length) {
      edges.add((fromId: nodes[i], toId: nodes[longJump], label: ''));
    }
  }

  for (int i = 0; i < nodes.length - 8; i += 2) {
    edges.add((fromId: nodes[i], toId: nodes[i + 8], label: ''));
  }

  return _fixtureFrom(nodes, edges);
}

_TestFixture _hubGraphFixture() {
  final nodes = List<String>.generate(25, (i) => 'h$i');
  final center = nodes.first;
  final edges = <({String fromId, String toId, String label})>[];

  for (int i = 1; i < nodes.length; i++) {
    edges.add((fromId: center, toId: nodes[i], label: ''));
  }

  for (int i = 1; i < nodes.length - 1; i++) {
    edges.add((fromId: nodes[i], toId: nodes[i + 1], label: ''));
    if (i + 3 < nodes.length) {
      edges.add((fromId: nodes[i], toId: nodes[i + 3], label: ''));
    }
  }

  return _fixtureFrom(nodes, edges);
}

_TestFixture _nestedSubgraphsFixture() {
  final nodes = List<String>.generate(12, (i) => 'g$i');
  final edges = <({String fromId, String toId, String label})>[
    (fromId: 'g0', toId: 'g1', label: ''),
    (fromId: 'g1', toId: 'g2', label: ''),
    (fromId: 'g2', toId: 'g3', label: ''),
    (fromId: 'g3', toId: 'g4', label: ''),
    (fromId: 'g4', toId: 'g5', label: ''),
    (fromId: 'g6', toId: 'g7', label: ''),
    (fromId: 'g7', toId: 'g8', label: ''),
    (fromId: 'g8', toId: 'g9', label: ''),
    (fromId: 'g9', toId: 'g10', label: ''),
    (fromId: 'g10', toId: 'g11', label: ''),
    (fromId: 'g2', toId: 'g8', label: ''),
    (fromId: 'g3', toId: 'g9', label: ''),
  ];

  final fixture = _fixtureFrom(nodes, edges);
  return fixture.copyWith(
    subgraphGroups: const <List<String>>[
      <String>['g0', 'g1', 'g2', 'g3', 'g4', 'g5', 'g6', 'g7'],
      <String>['g2', 'g3', 'g4'],
      <String>['g8', 'g9', 'g10', 'g11'],
    ],
  );
}

_TestFixture _multiEdgesSelfLoopsFixture() {
  final nodes = <String>['m0', 'm1', 'm2', 'm3', 'm4', 'm5'];
  final edges = <({String fromId, String toId, String label})>[
    (fromId: 'm0', toId: 'm1', label: 'a'),
    (fromId: 'm0', toId: 'm1', label: 'b'),
    (fromId: 'm0', toId: 'm1', label: 'c'),
    (fromId: 'm1', toId: 'm2', label: ''),
    (fromId: 'm2', toId: 'm3', label: ''),
    (fromId: 'm3', toId: 'm4', label: ''),
    (fromId: 'm4', toId: 'm5', label: ''),
    (fromId: 'm5', toId: 'm0', label: ''),
    (fromId: 'm2', toId: 'm2', label: 'self'),
    (fromId: 'm4', toId: 'm4', label: 'self2'),
  ];
  return _fixtureFrom(nodes, edges);
}

_TestFixture _fixtureFrom(
  List<String> nodeOrder,
  List<({String fromId, String toId, String label})> edges,
) {
  final blocks = <Block>[];
  final sizeByNode = <String, Size>{};
  for (int i = 0; i < nodeOrder.length; i++) {
    final id = nodeOrder[i];
    final row = i ~/ 6;
    final col = i % 6;
    final size = const Size(140, 90);
    blocks.add(
      Block(
        id: id,
        title: id,
        position: Offset(col * 170.0, row * 120.0),
        size: size,
      ),
    );
    sizeByNode[id] = size;
  }

  final allEdgeSet = <String>{};
  final allEdges = <(String, String)>[];
  for (final e in edges) {
    if (e.fromId == e.toId) {
      continue;
    }
    final k = e.fromId.compareTo(e.toId) <= 0
        ? '${e.fromId}|${e.toId}'
        : '${e.toId}|${e.fromId}';
    if (allEdgeSet.add(k)) {
      allEdges.add((e.fromId, e.toId));
    }
  }

  return _TestFixture(
    nodeOrder: nodeOrder,
    edges: edges,
    blocks: blocks,
    sizeByNode: sizeByNode,
    allEdges: allEdges,
    subgraphGroups: const <List<String>>[],
  );
}

class _TestFixture {
  final List<String> nodeOrder;
  final List<({String fromId, String toId, String label})> edges;
  final List<Block> blocks;
  final Map<String, Size> sizeByNode;
  final List<(String, String)> allEdges;
  final List<List<String>> subgraphGroups;

  const _TestFixture({
    required this.nodeOrder,
    required this.edges,
    required this.blocks,
    required this.sizeByNode,
    required this.allEdges,
    required this.subgraphGroups,
  });

  _TestFixture copyWith({
    List<String>? nodeOrder,
    List<({String fromId, String toId, String label})>? edges,
    List<Block>? blocks,
    Map<String, Size>? sizeByNode,
    List<(String, String)>? allEdges,
    List<List<String>>? subgraphGroups,
  }) {
    return _TestFixture(
      nodeOrder: nodeOrder ?? this.nodeOrder,
      edges: edges ?? this.edges,
      blocks: blocks ?? this.blocks,
      sizeByNode: sizeByNode ?? this.sizeByNode,
      allEdges: allEdges ?? this.allEdges,
      subgraphGroups: subgraphGroups ?? this.subgraphGroups,
    );
  }
}

int _countAlignedPairs(Map<String, Offset> positions, {double tolerance = 4}) {
  final ids = positions.keys.toList(growable: false);
  var aligned = 0;
  for (int i = 0; i < ids.length - 1; i++) {
    final a = positions[ids[i]]!;
    for (int j = i + 1; j < ids.length; j++) {
      final b = positions[ids[j]]!;
      if ((a.dx - b.dx).abs() <= tolerance ||
          (a.dy - b.dy).abs() <= tolerance) {
        aligned++;
      }
    }
  }
  return aligned;
}

String _tailLines(String content, int maxLines) {
  final lines = content.split('\n');
  if (lines.length <= maxLines) {
    return content;
  }
  return lines.sublist(lines.length - maxLines).join('\n');
}
