part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateZoneMethods on _MiroLikeWidgetState {
  static const double _autoSubgraphPaddingX = 70.0;
  static const double _autoSubgraphPaddingTop = 64.0;
  static const double _autoSubgraphPaddingBottom = 44.0;
  static const double _autoSubgraphParentChildGapX = 28.0;
  static const double _autoSubgraphParentChildGapTop = 32.0;
  static const double _autoSubgraphParentChildGapBottom = 18.0;

  ({String id, String title, Set<String> nodeIds})?
  _autoSubgraphDescriptorFromZone(Block zone) {
    if (!zone.isZone) {
      return null;
    }
    final raw = (zone.propertiesJson ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final autoSubgraph = decoded['autoSubgraph'];
      if (autoSubgraph is! Map<String, dynamic>) {
        return null;
      }

      final id = (autoSubgraph['id']?.toString() ?? '').trim();
      if (id.isEmpty) {
        return null;
      }
      final title = (autoSubgraph['title']?.toString() ?? id).trim();
      final rawNodeIds = autoSubgraph['nodeIds'];
      if (rawNodeIds is! List) {
        return null;
      }

      final nodeIds = <String>{};
      for (final rawNodeId in rawNodeIds) {
        final nodeId = rawNodeId?.toString().trim() ?? '';
        if (nodeId.isNotEmpty) {
          nodeIds.add(nodeId);
        }
      }
      if (nodeIds.length < 2) {
        return null;
      }

      return (id: id, title: title, nodeIds: nodeIds);
    } catch (_) {
      return null;
    }
  }

  bool _isAutoSubgraphZone(Block zone) {
    return _autoSubgraphDescriptorFromZone(zone) != null;
  }

  void _setAutoSubgraphDescriptor({
    required Block zone,
    required String id,
    required String title,
    required Iterable<String> nodeIds,
  }) {
    zone.propertiesJson = jsonEncode({
      'autoSubgraph': {
        'id': id,
        'title': title,
        'nodeIds': nodeIds.toList(growable: false),
      },
    });
  }

  void _upsertAutoSubgraphZonesFromMermaid(
    List<MermaidFlowchartSubgraph> subgraphs,
  ) {
    blocks.removeWhere((block) => block.isZone && _isAutoSubgraphZone(block));

    final filtered = subgraphs
        .where((subgraph) => subgraph.nodeIds.toSet().length >= 2)
        .toList(growable: false);

    final firstNormalIndex = blocks.indexWhere((block) => !block.isZone);
    var insertIndex = firstNormalIndex < 0 ? blocks.length : firstNormalIndex;

    for (final subgraph in filtered) {
      final zone = Block(
        id: 'subgraph_zone_${subgraph.id}',
        title: subgraph.title,
        kind: BlockKind.zone,
        colorKey: 'teal',
        position: const Offset(0, 0),
        size: const Size(_minZoneWidth, _minZoneHeight),
      );
      _setAutoSubgraphDescriptor(
        zone: zone,
        id: subgraph.id,
        title: subgraph.title,
        nodeIds: subgraph.nodeIds,
      );
      blocks.insert(insertIndex, zone);
      insertIndex++;
    }

    _syncAutoSubgraphZones();
  }

  void _syncAutoSubgraphZones() {
    final nodesById = <String, Block>{
      for (final block in blocks)
        if (!block.isZone) block.id: block,
    };

    final autoDescriptorsByZone =
        <Block, ({String id, String title, Set<String> nodeIds})>{};
    for (final zone in blocks.where((block) => block.isZone)) {
      final descriptor = _autoSubgraphDescriptorFromZone(zone);
      if (descriptor != null) {
        autoDescriptorsByZone[zone] = descriptor;
      }
    }

    final autoZones = autoDescriptorsByZone.keys.toList(growable: false);
    final depthByZone = <Block, int>{};
    for (final zone in autoZones) {
      final descriptor = autoDescriptorsByZone[zone]!;
      var depth = 0;
      for (final other in autoZones) {
        if (identical(zone, other)) {
          continue;
        }
        final otherDescriptor = autoDescriptorsByZone[other]!;
        final isAncestor =
            otherDescriptor.nodeIds.length > descriptor.nodeIds.length &&
            otherDescriptor.nodeIds.containsAll(descriptor.nodeIds);
        if (isAncestor) {
          depth++;
        }
      }
      depthByZone[zone] = depth;
    }
    final maxDepth = depthByZone.values.fold<int>(0, math.max);

    final zonesToDelete = <Block>[];
    for (final zone in blocks.where((block) => block.isZone)) {
      final descriptor = autoDescriptorsByZone[zone];
      if (descriptor == null) {
        continue;
      }

      final members = descriptor.nodeIds
          .map((id) => nodesById[id])
          .whereType<Block>()
          .toList(growable: false);
      if (members.length < 2) {
        zonesToDelete.add(zone);
        continue;
      }

      var left = double.infinity;
      var top = double.infinity;
      var right = -double.infinity;
      var bottom = -double.infinity;

      for (final member in members) {
        left = math.min(left, member.position.dx);
        top = math.min(top, member.position.dy);
        right = math.max(right, member.position.dx + member.size.width);
        bottom = math.max(bottom, member.position.dy + member.size.height);
      }

      final depth = depthByZone[zone] ?? 0;
      final parentRing = (maxDepth - depth).clamp(0, maxDepth);
      final paddedX =
          _autoSubgraphPaddingX + parentRing * _autoSubgraphParentChildGapX;
      final paddedTop =
          _autoSubgraphPaddingTop + parentRing * _autoSubgraphParentChildGapTop;
      final paddedBottom =
          _autoSubgraphPaddingBottom +
          parentRing * _autoSubgraphParentChildGapBottom;

      zone.title = descriptor.title;
      zone.position = Offset(left - paddedX, top - paddedTop);
      zone.size = Size(
        math.max(_minZoneWidth, (right - left) + paddedX * 2),
        math.max(_minZoneHeight, (bottom - top) + paddedTop + paddedBottom),
      );
    }

    if (zonesToDelete.isNotEmpty) {
      blocks.removeWhere((block) => zonesToDelete.contains(block));
      if (selectedBlock != null && zonesToDelete.contains(selectedBlock)) {
        selectedBlock = null;
        _selectedBlockIds.clear();
      }
    }
  }

  void _resizeZoneFromHandle(
    Block zone,
    _ZoneResizeHandle handle,
    DragUpdateDetails details,
  ) {
    if (_isAutoSubgraphZone(zone)) {
      return;
    }

    final delta = Offset(
      details.delta.dx / zoomLevel,
      details.delta.dy / zoomLevel,
    );

    double left = zone.position.dx;
    double top = zone.position.dy;
    double right = zone.position.dx + zone.size.width;
    double bottom = zone.position.dy + zone.size.height;

    switch (handle) {
      case _ZoneResizeHandle.topLeft:
        left += delta.dx;
        top += delta.dy;
        break;
      case _ZoneResizeHandle.topRight:
        right += delta.dx;
        top += delta.dy;
        break;
      case _ZoneResizeHandle.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
        break;
      case _ZoneResizeHandle.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
        break;
    }

    if (right - left < _minZoneWidth) {
      if (handle == _ZoneResizeHandle.topLeft ||
          handle == _ZoneResizeHandle.bottomLeft) {
        left = right - _minZoneWidth;
      } else {
        right = left + _minZoneWidth;
      }
    }
    if (bottom - top < _minZoneHeight) {
      if (handle == _ZoneResizeHandle.topLeft ||
          handle == _ZoneResizeHandle.topRight) {
        top = bottom - _minZoneHeight;
      } else {
        bottom = top + _minZoneHeight;
      }
    }

    zone.position = Offset(left, top);
    zone.size = Size(right - left, bottom - top);
  }

  List<Widget> _buildZoneResizeHandles() {
    final zone = selectedBlock;
    if (zone == null ||
        !zone.isZone ||
        _selectedBlockIds.length != 1 ||
        _isAutoSubgraphZone(zone)) {
      return const [];
    }

    final rect = _blockRectCanvas(zone);
    final size = (_zoneHandleSize * zoomLevel).clamp(8.0, 20.0);
    final half = size / 2;

    Widget handle(Offset center, _ZoneResizeHandle type) {
      return Positioned(
        left: center.dx - half,
        top: center.dy - half,
        width: size,
        height: size,
        child: GestureDetector(
          onPanStart: (_) {
            _pushUndoSnapshot();
          },
          onPanUpdate: (details) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              _resizeZoneFromHandle(zone, type, details);
              _markBoardChanged();
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.95),
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      handle(rect.topLeft, _ZoneResizeHandle.topLeft),
      handle(rect.topRight, _ZoneResizeHandle.topRight),
      handle(rect.bottomLeft, _ZoneResizeHandle.bottomLeft),
      handle(rect.bottomRight, _ZoneResizeHandle.bottomRight),
    ];
  }
}
