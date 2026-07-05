part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateAutoLayoutMethods on _MiroLikeWidgetState {
  static const String _auditLogFilePath = r'C:\apiconceptor_elk_audit.log';
  static const String _auditLogFileName = 'apiconceptor_elk_audit.log';

  Future<({String? path, String? error})> _writeAuditTrailToFile(
    List<String> trail,
  ) async {
    final content = '${trail.join('\n')}\n';
    final fallbackTempPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}$_auditLogFileName';
    const fallbackPublicPath = r'C:\Users\Public\apiconceptor_elk_audit.log';
    final candidates = <String>[
      _auditLogFilePath,
      fallbackPublicPath,
      fallbackTempPath,
    ];

    final errors = <String>[];
    for (final candidate in candidates) {
      try {
        await File(candidate).writeAsString(content, flush: true);
        if (candidate != _auditLogFilePath) {
          AutoLayoutEngine.debugLog(
            'stage=audit_file_fallback_used requested=$_auditLogFilePath actual=$candidate',
          );
        }
        return (path: candidate, error: null);
      } catch (e) {
        errors.add('$candidate -> $e');
      }
    }

    return (path: null, error: errors.join(' | '));
  }

  Future<void> _logNodePositionsForAutoLayoutDebug() async {
    if (_isSequenceDiagramView) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Snapshot de positions disponible en mode Flowchart uniquement.',
          ),
        ),
      );
      return;
    }

    final layoutBlocks = blocks.where((b) => !b.isZone).toList(growable: false);
    if (layoutBlocks.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aucun bloc a logger.')));
      return;
    }

    final nodeOrder = layoutBlocks.map((b) => b.id).toList(growable: false);
    final blockIds = nodeOrder.toSet();
    final layoutLinks = links
        .where(
          (l) =>
              blockIds.contains(l.fromBlockId) &&
              blockIds.contains(l.toBlockId),
        )
        .toList(growable: false);
    final edgeData = layoutLinks
        .map((l) => (fromId: l.fromBlockId, toId: l.toBlockId, label: l.name))
        .toList(growable: false);

    final effectiveSubgraphGroups = _inferAutoSubgraphNodeGroups(
      allowedNodeIds: blockIds,
    );
    final manualPositions = <String, Offset>{
      for (final block in layoutBlocks) block.id: block.position,
    };
    final sizeByNode = <String, Size>{
      for (final block in layoutBlocks) block.id: block.size,
    };
    final allEdges = [for (final e in edgeData) (e.fromId, e.toId)];

    AutoLayoutEngine.clearAuditTrail();
    AutoLayoutEngine.debugLog('stage=audit_file_reset path=$_auditLogFilePath');

    final predictedAuto = _computeMermaidAutoLayout(
      nodeOrder,
      edgeData,
      _mermaidLayoutDirection,
      layoutBlocks,
      seedPositions: manualPositions,
      subgraphNodeGroups: effectiveSubgraphGroups,
    );

    final avgWidth =
        sizeByNode.values.fold<double>(0.0, (s, z) => s + z.width) /
        math.max(1, sizeByNode.length);
    final avgHeight =
        sizeByNode.values.fold<double>(0.0, (s, z) => s + z.height) /
        math.max(1, sizeByNode.length);
    final quality = _placementQualityProfile();
    final spacing = _blockSpacingMultiplier().clamp(0.45, 2.2);
    final rawMinGap =
        (((avgWidth + avgHeight) * 0.06) + quality.channelPitch * 5.0) *
        (0.30 + spacing * 0.90);
    final minGap = rawMinGap.clamp(12.0, 220.0);
    final manualMetrics = AutoLayoutEngine.collectDebugMetrics(
      nodeOrder: nodeOrder,
      positions: manualPositions,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: effectiveSubgraphGroups,
      minGap: minGap,
    );
    final autoMetrics = AutoLayoutEngine.collectDebugMetrics(
      nodeOrder: nodeOrder,
      positions: predictedAuto,
      sizeByNode: sizeByNode,
      allEdges: allEdges,
      subgraphNodeGroups: effectiveSubgraphGroups,
      minGap: minGap,
    );

    final nodeDiffs = <Map<String, Object>>[];
    var movedNodes = 0;
    var maxDelta = 0.0;
    var sumDelta = 0.0;
    for (final id in nodeOrder) {
      final before = manualPositions[id];
      final after = predictedAuto[id];
      if (before == null || after == null) {
        continue;
      }
      final delta = after - before;
      final dist = delta.distance;
      if (dist > 0.01) {
        movedNodes++;
      }
      if (dist > maxDelta) {
        maxDelta = dist;
      }
      sumDelta += dist;

      nodeDiffs.add({
        'id': id,
        'before': {
          'x': double.parse(before.dx.toStringAsFixed(2)),
          'y': double.parse(before.dy.toStringAsFixed(2)),
        },
        'after': {
          'x': double.parse(after.dx.toStringAsFixed(2)),
          'y': double.parse(after.dy.toStringAsFixed(2)),
        },
        'delta': {
          'dx': double.parse(delta.dx.toStringAsFixed(2)),
          'dy': double.parse(delta.dy.toStringAsFixed(2)),
          'distance': double.parse(dist.toStringAsFixed(2)),
        },
      });
    }

    nodeDiffs.sort((a, b) {
      final da = (a['delta'] as Map<String, Object>)['distance'] as double;
      final db = (b['delta'] as Map<String, Object>)['distance'] as double;
      return db.compareTo(da);
    });

    final snapshot = <String, Object>{
      'type': 'manual_layout_snapshot',
      'timestamp': DateTime.now().toIso8601String(),
      'direction': _mermaidLayoutDirection,
      'quality': _placementQuality,
      'blockSpacingMode': _blockSpacingMode,
      'alignmentPriorityMode': _alignmentPriorityMode,
      'autoLayoutAnchorSideMode': _autoLayoutAnchorSideMode,
      'graph': {
        'nodes': nodeOrder.length,
        'links': allEdges.length,
        'subgraphGroups': effectiveSubgraphGroups.length,
        'minGap': double.parse(minGap.toStringAsFixed(2)),
      },
      'manualMetrics': manualMetrics.toJson(),
      'predictedAutoMetricsFromManualSeed': autoMetrics.toJson(),
      'metricDelta': {
        'crossings': autoMetrics.crossings - manualMetrics.crossings,
        'edgeOverNodeHits':
            autoMetrics.edgeOverNodeHits - manualMetrics.edgeOverNodeHits,
        'nodeOverlapPairs':
            autoMetrics.nodeOverlapPairs - manualMetrics.nodeOverlapPairs,
        'subgraphViolations':
            autoMetrics.subgraphViolations - manualMetrics.subgraphViolations,
        'totalEdgeLength': double.parse(
          (autoMetrics.totalEdgeLength - manualMetrics.totalEdgeLength)
              .toStringAsFixed(2),
        ),
        'alignmentScore': double.parse(
          (autoMetrics.alignmentScore - manualMetrics.alignmentScore)
              .toStringAsFixed(2),
        ),
        'objective': double.parse(
          (autoMetrics.objective - manualMetrics.objective).toStringAsFixed(2),
        ),
      },
      'positionDeltaSummary': {
        'movedNodes': movedNodes,
        'avgDistance': double.parse(
          (nodeOrder.isEmpty ? 0.0 : (sumDelta / nodeOrder.length))
              .toStringAsFixed(2),
        ),
        'maxDistance': double.parse(maxDelta.toStringAsFixed(2)),
      },
      'subgraphNodeGroups': [
        for (final g in effectiveSubgraphGroups) [...g]..sort(),
      ],
      'nodes': [
        for (final b in layoutBlocks)
          {
            'id': b.id,
            'x': double.parse(b.position.dx.toStringAsFixed(2)),
            'y': double.parse(b.position.dy.toStringAsFixed(2)),
            'width': double.parse(b.size.width.toStringAsFixed(2)),
            'height': double.parse(b.size.height.toStringAsFixed(2)),
          },
      ],
      'nodeDeltasManualVsAuto': nodeDiffs,
      'links': [
        for (final l in layoutLinks)
          {'from': l.fromBlockId, 'to': l.toBlockId, 'name': l.name},
      ],
    };

    final pretty = const JsonEncoder.withIndent('  ').convert(snapshot);
    for (final line in pretty.split('\n')) {
      AutoLayoutEngine.debugLog('stage=manual_snapshot $line');
    }
    final trail = AutoLayoutEngine.getAuditTrailSnapshot();
    final auditWrite = await _writeAuditTrailToFile(trail);
    if (auditWrite.path == null) {
      AutoLayoutEngine.debugLog(
        'stage=audit_file_write_failed path=$_auditLogFilePath error=${auditWrite.error}',
      );
    }
    await Clipboard.setData(ClipboardData(text: pretty));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          auditWrite.path != null
              ? 'Snapshot logge, copie et audit ecrit dans ${auditWrite.path}. nodes=${nodeOrder.length} moved=$movedNodes cross=${manualMetrics.crossings}->${autoMetrics.crossings}'
              : 'Snapshot logge et copie. Echec ecriture audit ($_auditLogFilePath). nodes=${nodeOrder.length} moved=$movedNodes cross=${manualMetrics.crossings}->${autoMetrics.crossings}',
        ),
      ),
    );
  }

  Map<String, Offset> _computeMermaidAutoLayout(
    List<String> nodeOrder,
    List<({String fromId, String toId, String label})> edgeData,
    String direction,
    List<Block>? layoutBlocks, {
    Map<String, Offset>? seedPositions,
    List<List<String>>? subgraphNodeGroups,
  }) {
    final effectiveBlocks = layoutBlocks ?? blocks;
    final quality = _placementQualityProfile();
    return AutoLayoutEngine.computeMermaidAutoLayout(
      nodeOrder: nodeOrder,
      edgeData: edgeData,
      direction: direction,
      effectiveBlocks: effectiveBlocks,
      quality: AutoLayoutQualityProfile(
        iterationMul: quality.iterationMul,
        repulsionMul: quality.repulsionMul,
        springMul: quality.springMul,
        overlapMul: quality.overlapMul,
        hpwlMul: quality.hpwlMul,
        crossingMul: quality.crossingMul,
        spacingMul: _blockSpacingMultiplier(),
        channelPitch: quality.channelPitch,
        snapTargetWeight: quality.snapTargetWeight,
        alignmentPriority: _alignmentPriorityMultiplier(),
      ),
      seedPositions: seedPositions,
      subgraphNodeGroups: subgraphNodeGroups,
    );
  }

  List<Offset> _routeLinkAroundObstacles({
    required Rect fromRect,
    required Rect toRect,
    required Offset sourceAnchor,
    required Offset targetAnchor,
    required List<Rect> obstacleRects,
  }) {
    final clearance = 24.0;
    final startEdge = _borderPointFromUnit(fromRect, sourceAnchor);
    final endEdge = _borderPointFromUnit(toRect, targetAnchor);
    final start = startEdge + _normalizeAnchorUnit(sourceAnchor) * clearance;
    final end = endEdge + _normalizeAnchorUnit(targetAnchor) * clearance;

    final inflatedObstacles = obstacleRects
        .map((rect) => rect.inflate(clearance))
        .toList(growable: false);
    if (_segmentIntersectsAnyRect(start, end, inflatedObstacles)) {
      // Fall back to routing around the obstacles.
    } else {
      return const [];
    }

    final xCoords = <double>{start.dx, end.dx};
    final yCoords = <double>{start.dy, end.dy};
    for (final rect in inflatedObstacles) {
      xCoords
        ..add(rect.left)
        ..add(rect.right)
        ..add(rect.center.dx);
      yCoords
        ..add(rect.top)
        ..add(rect.bottom)
        ..add(rect.center.dy);
    }

    final xs = xCoords.toList()..sort();
    final ys = yCoords.toList()..sort();
    if (xs.length < 2 || ys.length < 2) {
      return const [];
    }

    String keyFor(Offset point) =>
        '${point.dx.toStringAsFixed(2)}|${point.dy.toStringAsFixed(2)}';
    final nodeByKey = <String, Offset>{};
    final nodes = <Offset>[];

    for (final x in xs) {
      for (final y in ys) {
        final point = Offset(x, y);
        if (_pointInsideAnyRect(point, inflatedObstacles)) {
          continue;
        }
        final key = keyFor(point);
        nodeByKey[key] = point;
        nodes.add(point);
      }
    }

    final startKey = keyFor(start);
    final endKey = keyFor(end);
    nodeByKey[startKey] = start;
    nodeByKey[endKey] = end;
    if (!nodes.any((p) => p == start)) {
      nodes.add(start);
    }
    if (!nodes.any((p) => p == end)) {
      nodes.add(end);
    }

    final adjacency = <String, List<(String, double)>>{
      for (final point in nodes) keyFor(point): <(String, double)>[],
    };

    double segmentPenalty(Offset a, Offset b) {
      final length = (a - b).distance;
      final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      var penalty = 0.0;
      for (final rect in inflatedObstacles) {
        final distance = _distancePointToRect(midpoint, rect);
        if (distance < 0) {
          return double.infinity;
        }
        if (distance < 52.0) {
          penalty += (52.0 - distance) * 5.0;
        }
      }
      return length + penalty;
    }

    bool clearSegment(Offset a, Offset b) {
      for (final rect in inflatedObstacles) {
        if (_segmentIntersectsRect(a, b, rect)) {
          return false;
        }
      }
      return true;
    }

    for (int yIndex = 0; yIndex < ys.length; yIndex++) {
      for (int xIndex = 0; xIndex < xs.length - 1; xIndex++) {
        final left = Offset(xs[xIndex], ys[yIndex]);
        final right = Offset(xs[xIndex + 1], ys[yIndex]);
        final leftKey = keyFor(left);
        final rightKey = keyFor(right);
        if (nodeByKey[leftKey] == null || nodeByKey[rightKey] == null) {
          continue;
        }
        if (!clearSegment(left, right)) {
          continue;
        }
        final cost = segmentPenalty(left, right);
        if (!cost.isFinite) {
          continue;
        }
        adjacency[leftKey]!.add((rightKey, cost));
        adjacency[rightKey]!.add((leftKey, cost));
      }
    }

    for (int xIndex = 0; xIndex < xs.length; xIndex++) {
      for (int yIndex = 0; yIndex < ys.length - 1; yIndex++) {
        final top = Offset(xs[xIndex], ys[yIndex]);
        final bottom = Offset(xs[xIndex], ys[yIndex + 1]);
        final topKey = keyFor(top);
        final bottomKey = keyFor(bottom);
        if (nodeByKey[topKey] == null || nodeByKey[bottomKey] == null) {
          continue;
        }
        if (!clearSegment(top, bottom)) {
          continue;
        }
        final cost = segmentPenalty(top, bottom);
        if (!cost.isFinite) {
          continue;
        }
        adjacency[topKey]!.add((bottomKey, cost));
        adjacency[bottomKey]!.add((topKey, cost));
      }
    }

    final frontier = <(String, double)>[(startKey, 0.0)];
    final cameFrom = <String, String>{};
    final gScore = <String, double>{startKey: 0.0};

    double heuristic(String key) {
      final point = nodeByKey[key];
      if (point == null) {
        return double.infinity;
      }
      return (point - end).distance;
    }

    while (frontier.isNotEmpty) {
      frontier.sort((a, b) => a.$2.compareTo(b.$2));
      final current = frontier.removeAt(0).$1;
      if (current == endKey) {
        break;
      }

      for (final neighbor in adjacency[current] ?? const <(String, double)>[]) {
        final tentative = (gScore[current] ?? double.infinity) + neighbor.$2;
        if (tentative >= (gScore[neighbor.$1] ?? double.infinity)) {
          continue;
        }
        cameFrom[neighbor.$1] = current;
        gScore[neighbor.$1] = tentative;
        frontier.add((neighbor.$1, tentative + heuristic(neighbor.$1)));
      }
    }

    if (!cameFrom.containsKey(endKey)) {
      return const [];
    }

    final route = <Offset>[end];
    var currentKey = endKey;
    while (currentKey != startKey) {
      currentKey = cameFrom[currentKey]!;
      route.add(nodeByKey[currentKey]!);
    }
    route.add(start);
    final ordered = route.reversed.toList();
    final simplified = _simplifyRoutedPath(ordered);
    if (simplified.length <= 2) {
      return const [];
    }
    return simplified.sublist(1, simplified.length - 1);
  }

  bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    if (a.dx == b.dx) {
      final x = a.dx;
      if (x < rect.left || x > rect.right) {
        return false;
      }
      final minY = math.min(a.dy, b.dy);
      final maxY = math.max(a.dy, b.dy);
      return maxY > rect.top && minY < rect.bottom;
    }

    if (a.dy == b.dy) {
      final y = a.dy;
      if (y < rect.top || y > rect.bottom) {
        return false;
      }
      final minX = math.min(a.dx, b.dx);
      final maxX = math.max(a.dx, b.dx);
      return maxX > rect.left && minX < rect.right;
    }

    return false;
  }

  bool _pointInsideAnyRect(Offset point, List<Rect> rects) {
    for (final rect in rects) {
      if (rect.contains(point)) {
        return true;
      }
    }
    return false;
  }

  double _distancePointToRect(Offset point, Rect rect) {
    if (rect.contains(point)) {
      return -1;
    }
    final dx = math.max(
      0.0,
      math.max(rect.left - point.dx, point.dx - rect.right),
    );
    final dy = math.max(
      0.0,
      math.max(rect.top - point.dy, point.dy - rect.bottom),
    );
    return math.sqrt(dx * dx + dy * dy);
  }

  bool _segmentIntersectsAnyRect(Offset a, Offset b, List<Rect> rects) {
    for (final rect in rects) {
      if (_segmentIntersectsRect(a, b, rect)) {
        return true;
      }
    }
    return false;
  }

  List<Offset> _simplifyRoutedPath(List<Offset> points) {
    if (points.length <= 2) {
      return points;
    }

    final simplified = <Offset>[points.first];
    for (int i = 1; i < points.length - 1; i++) {
      final prev = simplified.last;
      final current = points[i];
      final next = points[i + 1];
      final sameX =
          (prev.dx - current.dx).abs() < 0.5 &&
          (current.dx - next.dx).abs() < 0.5;
      final sameY =
          (prev.dy - current.dy).abs() < 0.5 &&
          (current.dy - next.dy).abs() < 0.5;
      if (sameX || sameY) {
        continue;
      }

      final isColinear = _isColinear(prev, current, next, tolerance: 1.5);
      if (isColinear) {
        continue;
      }

      simplified.add(current);
    }
    simplified.add(points.last);
    return _mergeOscillatingSegments(simplified);
  }

  bool _isColinear(Offset a, Offset b, Offset c, {double tolerance = 0.5}) {
    final ab = b - a;
    final ac = c - a;
    if (ab.distanceSquared == 0 || ac.distanceSquared == 0) {
      return true;
    }

    final crossProduct = (ab.dx * ac.dy - ab.dy * ac.dx).abs();
    final combinedLength = ab.distance * ac.distance;
    if (combinedLength == 0) {
      return true;
    }

    return (crossProduct / combinedLength) < tolerance;
  }

  List<Offset> _mergeOscillatingSegments(List<Offset> points) {
    if (points.length <= 3) {
      return points;
    }

    final merged = <Offset>[points.first];
    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      if (merged.length < 2) {
        merged.add(current);
        continue;
      }

      final prev = merged.last;
      final prevPrev = merged[merged.length - 2];
      final distCurrentPrev = (current - prev).distance;
      final distPrevPrevPrev = (prev - prevPrev).distance;

      if (distCurrentPrev < 8.0 || distPrevPrevPrev < 8.0) {
        final dirPrevPrev = math.atan2(
          prev.dy - prevPrev.dy,
          prev.dx - prevPrev.dx,
        );
        final dirCurrent = math.atan2(
          current.dy - prev.dy,
          current.dx - prev.dx,
        );
        final angleDiff = (dirCurrent - dirPrevPrev).abs();
        final normalizedDiff = math.min(angleDiff, 2 * math.pi - angleDiff);

        if (normalizedDiff < 0.3 || normalizedDiff > math.pi - 0.3) {
          merged[merged.length - 1] = current;
          continue;
        }
      }

      merged.add(current);
    }

    return merged;
  }

  void _reorganizeGraphLayout() {
    final layoutBlocks = blocks.where((b) => !b.isZone).toList(growable: false);
    if (layoutBlocks.isEmpty) {
      return;
    }

    final layoutBlockIds = layoutBlocks.map((b) => b.id).toSet();
    final layoutLinks = links
        .where(
          (l) =>
              layoutBlockIds.contains(l.fromBlockId) &&
              layoutBlockIds.contains(l.toBlockId),
        )
        .toList(growable: false);

    _pushUndoSnapshot();
    // ignore: invalid_use_of_protected_member
    setState(() {
      final inferredSubgraphGroups = _inferAutoSubgraphNodeGroups(
        allowedNodeIds: layoutBlockIds,
      );
      _runAutoLayoutOnGraph(
        layoutBlocks,
        layoutLinks,
        _mermaidLayoutDirection,
        preserveCurrentPositions: true,
        subgraphNodeGroups: inferredSubgraphGroups,
      );
      _syncAutoSubgraphZones();
      _markBoardChanged();
    });
  }

  List<List<String>> _inferAutoSubgraphNodeGroups({
    Set<String>? allowedNodeIds,
  }) {
    final allowed = allowedNodeIds;
    final nodeBlocks = blocks
        .where((block) => !block.isZone)
        .toList(growable: false);
    final groups = <List<String>>[];
    final signatures = <String>{};

    for (final zone in blocks.where((block) => block.isZone)) {
      final descriptor = _autoSubgraphDescriptorFromZone(zone);
      List<String> cleaned;
      if (descriptor != null) {
        cleaned = descriptor.nodeIds
            .where((id) => allowed == null || allowed.contains(id))
            .toList(growable: false);
      } else if (zone.zoneType == BlockZoneType.subgraph) {
        final zoneRect = Rect.fromLTWH(
          zone.position.dx,
          zone.position.dy,
          zone.size.width,
          zone.size.height,
        );
        cleaned = nodeBlocks
            .where((node) => allowed == null || allowed.contains(node.id))
            .where((node) {
              final nodeRect = Rect.fromLTWH(
                node.position.dx,
                node.position.dy,
                node.size.width,
                node.size.height,
              );
              return zoneRect.overlaps(nodeRect);
            })
            .map((node) => node.id)
            .toList(growable: false);
      } else {
        continue;
      }

      if (cleaned.length < 2) {
        continue;
      }

      final signatureParts = [...cleaned]..sort();
      final signature = signatureParts.join('|');
      if (!signatures.add(signature)) {
        continue;
      }
      groups.add(cleaned);
    }

    return groups;
  }

  void _reorganizeSequenceLayout() {
    final participants = blocks.where((b) => !b.isZone).toList(growable: false);
    if (participants.isEmpty) {
      return;
    }

    final orderedParticipants = participants.toList(growable: false)
      ..sort((a, b) {
        final byX = a.position.dx.compareTo(b.position.dx);
        if (byX != 0) {
          return byX;
        }
        return a.position.dy.compareTo(b.position.dy);
      });

    final validParticipantIds = orderedParticipants.map((b) => b.id).toSet();
    final orderedLinks =
        links
            .where(
              (l) =>
                  validParticipantIds.contains(l.fromBlockId) &&
                  validParticipantIds.contains(l.toBlockId),
            )
            .toList(growable: true)
          ..sort((a, b) {
            final byLane = _sequenceLaneYModel(
              a,
            ).compareTo(_sequenceLaneYModel(b));
            if (byLane != 0) {
              return byLane;
            }
            return links.indexOf(a).compareTo(links.indexOf(b));
          });

    _pushUndoSnapshot();
    // ignore: invalid_use_of_protected_member
    setState(() {
      _applyCanonicalSequenceLayout(orderedParticipants, orderedLinks);
      _markBoardChanged();
    });
  }

  void _reorganizeCurrentLayout() {
    if (_isSequenceDiagramView) {
      _reorganizeSequenceLayout();
    } else {
      _reorganizeGraphLayout();
    }
  }

  void _setDiagramLayoutMode(_DiagramLayoutMode mode) {
    final useSequence = mode == _DiagramLayoutMode.sequence;
    if (_isSequenceDiagramView == useSequence) {
      return;
    }

    _pushUndoSnapshot();
    // ignore: invalid_use_of_protected_member
    setState(() {
      _isSequenceDiagramView = useSequence;
      if (_isSequenceDiagramView) {
        _normalizeSequenceMessageGeometryAndSpacing();
      }
      _markBoardChanged();
    });
  }

  void _applyAutoLayoutLinkGeometry(
    List<Block> targetBlocks,
    List<BlockLink> targetLinks,
  ) {
    final preserveAnchorSide = _autoLayoutAnchorSideMode == 'Conserver';
    final blockById = <String, Block>{
      for (final block in targetBlocks) block.id: block,
    };
    final rectById = <String, Rect>{
      for (final block in targetBlocks)
        block.id: Rect.fromLTWH(
          block.position.dx,
          block.position.dy,
          block.size.width,
          block.size.height,
        ),
    };

    final degreeByNode = <String, int>{
      for (final block in targetBlocks) block.id: 0,
    };
    for (final link in targetLinks) {
      degreeByNode[link.fromBlockId] =
          (degreeByNode[link.fromBlockId] ?? 0) + 1;
      degreeByNode[link.toBlockId] = (degreeByNode[link.toBlockId] ?? 0) + 1;
    }

    final hubThreshold = math.max(
      2,
      (targetLinks.length / targetBlocks.length).ceil(),
    );
    final hubs = <String>{
      for (final entry in degreeByNode.entries)
        if (entry.value >= hubThreshold) entry.key,
    };

    final sideUsageByBlock = <String, Map<Offset, int>>{};
    final sortedLinksForBlock = <String, List<BlockLink>>{
      for (final block in targetBlocks) block.id: <BlockLink>[],
    };

    for (final link in targetLinks) {
      sortedLinksForBlock[link.fromBlockId]!.add(link);
      sortedLinksForBlock[link.toBlockId]!.add(link);
    }

    for (final entry in sortedLinksForBlock.entries) {
      entry.value.sort((a, b) {
        final aOtherId = a.fromBlockId == entry.key
            ? a.toBlockId
            : a.fromBlockId;
        final bOtherId = b.fromBlockId == entry.key
            ? b.toBlockId
            : b.fromBlockId;
        return aOtherId.compareTo(bOtherId);
      });
    }

    double orderKeyForSide(Offset side, Offset otherCenter) {
      if (side.dx.abs() >= side.dy.abs()) {
        return otherCenter.dy;
      }
      return otherCenter.dx;
    }

    for (final link in targetLinks) {
      final preserveThisLink = preserveAnchorSide || link.autoLayoutLock;
      final fromBlock = blockById[link.fromBlockId];
      final toBlock = blockById[link.toBlockId];
      final fromRect = rectById[link.fromBlockId];
      final toRect = rectById[link.toBlockId];
      if (fromBlock == null ||
          toBlock == null ||
          fromRect == null ||
          toRect == null) {
        continue;
      }

      final sourceUsage = sideUsageByBlock.putIfAbsent(
        fromBlock.id,
        () => <Offset, int>{},
      );
      final targetUsage = sideUsageByBlock.putIfAbsent(
        toBlock.id,
        () => <Offset, int>{},
      );

      final isSourceHub = hubs.contains(fromBlock.id);
      final isTargetHub = hubs.contains(toBlock.id);

      final sourceAnchor =
          link.isSourceAnchorLocked && link.sourceAnchorUnit != null
          ? _normalizeAnchorUnit(link.sourceAnchorUnit!)
          : preserveThisLink && link.sourceAnchorUnit != null
          ? _anchorSideUnit(link.sourceAnchorUnit!)
          : _chooseAnchorUnitTowardRect(
              fromRect,
              toRect,
              sideUsage: sourceUsage,
              isHub: isSourceHub,
            );
      final targetAnchor =
          link.isTargetAnchorLocked && link.targetAnchorUnit != null
          ? _normalizeAnchorUnit(link.targetAnchorUnit!)
          : preserveThisLink && link.targetAnchorUnit != null
          ? _anchorSideUnit(link.targetAnchorUnit!)
          : _chooseAnchorUnitTowardRect(
              toRect,
              fromRect,
              sideUsage: targetUsage,
              isHub: isTargetHub,
            );

      final obstacleRects = <Rect>[
        for (final block in targetBlocks)
          if (block.id != fromBlock.id && block.id != toBlock.id)
            Rect.fromLTWH(
              block.position.dx,
              block.position.dy,
              block.size.width,
              block.size.height,
            ).inflate(20.0),
      ];

      final routedInflections = preserveThisLink
          ? List<Offset>.from(link.inflectionPoints)
          : _routeLinkAroundObstacles(
              fromRect: fromRect,
              toRect: toRect,
              sourceAnchor: sourceAnchor,
              targetAnchor: targetAnchor,
              obstacleRects: obstacleRects,
            );

      link.connectorType = ConnectorType.bezier;
      link.inflectionPoints
        ..clear()
        ..addAll(routedInflections);
      link.isSourceAnchorLocked = false;
      link.isTargetAnchorLocked = false;
      link.sourceAnchorUnit = sourceAnchor;
      link.targetAnchorUnit = targetAnchor;
      link.sourceAnchorOrderKey = orderKeyForSide(sourceAnchor, toRect.center);
      link.targetAnchorOrderKey = orderKeyForSide(
        targetAnchor,
        fromRect.center,
      );

      sourceUsage[sourceAnchor] = (sourceUsage[sourceAnchor] ?? 0) + 1;
      targetUsage[targetAnchor] = (targetUsage[targetAnchor] ?? 0) + 1;
    }

    _recomputeAutoLayoutAnchorOrderKeys(targetBlocks, targetLinks);
  }

  void _recomputeAutoLayoutAnchorOrderKeys(
    List<Block> targetBlocks,
    List<BlockLink> targetLinks,
  ) {
    final blockById = <String, Block>{
      for (final block in targetBlocks) block.id: block,
    };

    final groups =
        <
          String,
          List<
            ({BlockLink link, bool isSource, double projection, int tieBreak})
          >
        >{};

    void pushGroup(
      String blockId,
      Offset side,
      BlockLink link,
      bool isSource,
      double projection,
      int tieBreak,
    ) {
      final key =
          '$blockId|${side.dx.toStringAsFixed(0)}|${side.dy.toStringAsFixed(0)}';
      groups.putIfAbsent(
        key,
        () =>
            <
              ({BlockLink link, bool isSource, double projection, int tieBreak})
            >[],
      );
      groups[key]!.add((
        link: link,
        isSource: isSource,
        projection: projection,
        tieBreak: tieBreak,
      ));
    }

    double sideProjection(Offset side, Offset ownCenter, Offset otherCenter) {
      final delta = otherCenter - ownCenter;
      if (side.dx != 0) {
        return delta.dy;
      }
      return delta.dx;
    }

    Offset centerOf(Block block) {
      return Offset(
        block.position.dx + block.size.width / 2,
        block.position.dy + block.size.height / 2,
      );
    }

    for (int i = 0; i < targetLinks.length; i++) {
      final link = targetLinks[i];
      final fromBlock = blockById[link.fromBlockId];
      final toBlock = blockById[link.toBlockId];
      if (fromBlock == null || toBlock == null) {
        continue;
      }

      if (link.sourceAnchorUnit != null) {
        final side = _anchorSideUnit(link.sourceAnchorUnit!);
        final projection = sideProjection(
          side,
          centerOf(fromBlock),
          centerOf(toBlock),
        );
        pushGroup(link.fromBlockId, side, link, true, projection, i);
      }

      if (link.targetAnchorUnit != null) {
        final side = _anchorSideUnit(link.targetAnchorUnit!);
        final projection = sideProjection(
          side,
          centerOf(toBlock),
          centerOf(fromBlock),
        );
        pushGroup(link.toBlockId, side, link, false, projection, i);
      }
    }

    for (final entries in groups.values) {
      entries.sort((a, b) {
        final byProjection = a.projection.compareTo(b.projection);
        if (byProjection != 0) {
          return byProjection;
        }
        return a.tieBreak.compareTo(b.tieBreak);
      });

      for (int idx = 0; idx < entries.length; idx++) {
        final entry = entries[idx];
        final key = idx.toDouble();
        if (entry.isSource) {
          entry.link.sourceAnchorOrderKey = key;
        } else {
          entry.link.targetAnchorOrderKey = key;
        }
      }
    }
  }

  void _ensureBlockHasSpaceForAnchorsInGraph(
    Block block,
    List<BlockLink> graphLinks,
  ) {
    int leftCount = 0;
    int rightCount = 0;
    int topCount = 0;
    int bottomCount = 0;

    for (final link in graphLinks) {
      if (link.fromBlockId == block.id && link.sourceAnchorUnit != null) {
        final side = _anchorSideUnit(link.sourceAnchorUnit!);
        if (side.dx < 0) {
          leftCount++;
        } else if (side.dx > 0) {
          rightCount++;
        } else if (side.dy < 0) {
          topCount++;
        } else if (side.dy > 0) {
          bottomCount++;
        }
      }

      if (link.toBlockId == block.id && link.targetAnchorUnit != null) {
        final side = _anchorSideUnit(link.targetAnchorUnit!);
        if (side.dx < 0) {
          leftCount++;
        } else if (side.dx > 0) {
          rightCount++;
        } else if (side.dy < 0) {
          topCount++;
        } else if (side.dy > 0) {
          bottomCount++;
        }
      }
    }

    final maxVerticalAnchors = math.max(leftCount, rightCount);
    final maxHorizontalAnchors = math.max(topCount, bottomCount);

    final requiredCanvasHeight = _requiredCanvasExtentForAnchorCount(
      maxVerticalAnchors,
    );
    final requiredCanvasWidth = _requiredCanvasExtentForAnchorCount(
      maxHorizontalAnchors,
    );

    final requiredModelHeight = requiredCanvasHeight / zoomLevel;
    final requiredModelWidth = requiredCanvasWidth / zoomLevel;
    final newWidth = math.max(_minBlockWidth, requiredModelWidth);
    final newHeight = math.max(_minBlockHeight, requiredModelHeight);

    if (newWidth != block.size.width || newHeight != block.size.height) {
      block.size = Size(newWidth, newHeight);
    }
  }

  void _runAutoLayoutOnGraph(
    List<Block> targetBlocks,
    List<BlockLink> targetLinks,
    String direction, {
    bool preserveCurrentPositions = false,
    List<List<String>>? subgraphNodeGroups,
  }) {
    final layoutBlocks = targetBlocks
        .where((b) => !b.isZone)
        .toList(growable: false);
    if (layoutBlocks.isEmpty) {
      return;
    }

    final layoutBlockIds = layoutBlocks.map((b) => b.id).toSet();
    final layoutLinks = targetLinks
        .where(
          (l) =>
              layoutBlockIds.contains(l.fromBlockId) &&
              layoutBlockIds.contains(l.toBlockId),
        )
        .toList(growable: false);

    _applyAutoLayoutLinkGeometry(layoutBlocks, layoutLinks);
    for (final block in layoutBlocks) {
      _ensureBlockHasSpaceForAnchorsInGraph(block, layoutLinks);
    }

    final nodeOrder = layoutBlocks.map((b) => b.id).toList();
    final effectiveSubgraphGroups =
        subgraphNodeGroups ??
        _inferAutoSubgraphNodeGroups(allowedNodeIds: layoutBlockIds);
    AutoLayoutEngine.debugLog(
      'stage=subgraph_groups_input source=${subgraphNodeGroups == null ? 'inferred' : 'provided'} groups=${effectiveSubgraphGroups.length} nodes=${layoutBlocks.length} links=${layoutLinks.length}',
    );
    final edgeData = layoutLinks
        .map((l) => (fromId: l.fromBlockId, toId: l.toBlockId, label: l.name))
        .toList();
    final positions = _computeMermaidAutoLayout(
      nodeOrder,
      edgeData,
      direction,
      layoutBlocks,
      seedPositions: preserveCurrentPositions
          ? {for (final block in layoutBlocks) block.id: block.position}
          : null,
      subgraphNodeGroups: effectiveSubgraphGroups,
    );

    for (final block in layoutBlocks) {
      final position = positions[block.id];
      if (position != null) {
        block.position = position;
      }
    }

    _applyAutoLayoutLinkGeometry(layoutBlocks, layoutLinks);
    for (final block in layoutBlocks) {
      _ensureBlockHasSpaceForAnchorsInGraph(block, layoutLinks);
    }
  }
}
