part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateAnchorMethods on _MiroLikeWidgetState {
  Offset _chooseAnchorUnitTowardRect(
    Rect fromRect,
    Rect toRect, {
    required Map<Offset, int> sideUsage,
    bool isHub = false,
  }) {
    final delta = toRect.center - fromRect.center;
    final horizontalPreferred = delta.dx.abs() >= delta.dy.abs();
    final candidates = <Offset>[
      const Offset(-1, 0),
      const Offset(1, 0),
      const Offset(0, -1),
      const Offset(0, 1),
    ];

    double anchorScore(Offset unit) {
      final borderPoint = _borderPointFromUnit(fromRect, unit);
      final approach = (toRect.center - borderPoint).distance;
      final baseSideLoad = (sideUsage[unit] ?? 0);
      final sideLoad = isHub
          ? baseSideLoad * 6.0 + (baseSideLoad > 0 ? 8.0 : 0.0)
          : baseSideLoad * 16.0;
      final axisMismatch = horizontalPreferred
          ? (unit.dx.abs() > 0 ? 0.0 : 26.0)
          : (unit.dy.abs() > 0 ? 0.0 : 26.0);
      final flowBias = horizontalPreferred
          ? (delta.dx >= 0
                ? (unit.dx > 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dx < 0 ? (isHub ? 16.0 : 18.0) : 10.0))
                : (unit.dx < 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dx > 0 ? (isHub ? 16.0 : 18.0) : 10.0)))
          : (delta.dy >= 0
                ? (unit.dy > 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dy < 0 ? (isHub ? 16.0 : 18.0) : 10.0))
                : (unit.dy < 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dy > 0 ? (isHub ? 16.0 : 18.0) : 10.0)));
      return approach + axisMismatch + flowBias + sideLoad;
    }

    var bestUnit = candidates.first;
    var bestScore = double.infinity;
    for (final candidate in candidates) {
      final score = anchorScore(candidate);
      if (score < bestScore) {
        bestScore = score;
        bestUnit = candidate;
      }
    }

    return bestUnit;
  }

  Offset _calculateOptimalAnchorUnit(Rect fromRect, Rect toRect) {
    final fromCenter = fromRect.center;
    final toCenter = toRect.center;
    final direction = toCenter - fromCenter;

    if (direction.distanceSquared == 0) {
      return const Offset(1, 0);
    }

    final normalized = direction / direction.distance;
    final absX = normalized.dx.abs();
    final absY = normalized.dy.abs();

    if (absX >= absY) {
      return Offset(normalized.dx >= 0 ? 1 : -1, 0);
    } else {
      return Offset(0, normalized.dy >= 0 ? 1 : -1);
    }
  }

  void _updateLinksAnchorsForBlock(Block block) {
    final connectedBlockIds = <String>{};
    final dirtyAnchorSideKeys = <String>{};

    void markDirtySide(String blockId, Offset side) {
      dirtyAnchorSideKeys.add(
        '$blockId|${side.dx.toStringAsFixed(0)}|${side.dy.toStringAsFixed(0)}',
      );
    }

    for (var link in links) {
      if (link.fromBlockId == block.id) {
        connectedBlockIds.add(link.toBlockId);
      }
      if (link.toBlockId == block.id) {
        connectedBlockIds.add(link.fromBlockId);
      }
    }

    final blockIdsToUpdate = {block.id, ...connectedBlockIds};

    for (var blockId in blockIdsToUpdate) {
      for (var link in links) {
        if (link.autoLayoutLock) {
          continue;
        }

        final isSource = link.fromBlockId == blockId;
        final isTarget = link.toBlockId == blockId;

        if (isSource && !link.isSourceAnchorLocked) {
          final sourceIndex = blocks.indexWhere(
            (b) => b.id == link.fromBlockId,
          );
          final targetIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
          if (sourceIndex != -1 && targetIndex != -1) {
            final sourceRect = _blockRectCanvas(blocks[sourceIndex]);
            final targetRect = _blockRectCanvas(blocks[targetIndex]);
            final previousSourceSide = link.sourceAnchorUnit == null
                ? null
                : _anchorSideUnit(link.sourceAnchorUnit!);
            final newAnchor = _calculateOptimalAnchorUnit(
              sourceRect,
              targetRect,
            );
            link.sourceAnchorUnit = newAnchor;
            final newSourceSide = _anchorSideUnit(newAnchor);
            if (previousSourceSide == null ||
                previousSourceSide != newSourceSide) {
              markDirtySide(link.fromBlockId, newSourceSide);
              if (link.targetAnchorUnit != null) {
                markDirtySide(
                  link.toBlockId,
                  _anchorSideUnit(link.targetAnchorUnit!),
                );
              }
            }
          }
        }

        if (isTarget && !link.isTargetAnchorLocked) {
          final sourceIndex = blocks.indexWhere(
            (b) => b.id == link.fromBlockId,
          );
          final targetIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
          if (sourceIndex != -1 && targetIndex != -1) {
            final sourceRect = _blockRectCanvas(blocks[sourceIndex]);
            final targetRect = _blockRectCanvas(blocks[targetIndex]);
            final previousTargetSide = link.targetAnchorUnit == null
                ? null
                : _anchorSideUnit(link.targetAnchorUnit!);
            final newAnchor = _calculateOptimalAnchorUnit(
              targetRect,
              sourceRect,
            );
            link.targetAnchorUnit = newAnchor;
            final newTargetSide = _anchorSideUnit(newAnchor);
            if (previousTargetSide == null ||
                previousTargetSide != newTargetSide) {
              markDirtySide(link.toBlockId, newTargetSide);
              if (link.sourceAnchorUnit != null) {
                markDirtySide(
                  link.fromBlockId,
                  _anchorSideUnit(link.sourceAnchorUnit!),
                );
              }
            }
          }
        }
      }

      final blockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        _ensureBlockHasSpaceForAnchors(blocks[blockIndex]);
      }
    }

    for (final dirtyKey in dirtyAnchorSideKeys) {
      final parts = dirtyKey.split('|');
      if (parts.length != 3) {
        continue;
      }
      final blockId = parts[0];
      final side = Offset(
        double.tryParse(parts[1]) ?? 0,
        double.tryParse(parts[2]) ?? 0,
      );
      final anchorBlockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (anchorBlockIndex == -1) {
        continue;
      }
      _recomputeAnchorOrderKeysForBlockSide(blocks[anchorBlockIndex], side);
    }
  }

  void _recomputeAnchorOrderKeysForBlockSide(Block block, Offset side) {
    final sideAnchors =
        <({BlockLink link, bool isSource, double sortKey, int linkIndex})>[];

    double orderKeyFromOtherBlockCenter(Offset otherCenter) {
      if (side.dx.abs() >= side.dy.abs()) {
        return otherCenter.dy;
      }
      return otherCenter.dx;
    }

    for (int i = 0; i < links.length; i++) {
      final link = links[i];
      if (link.fromBlockId == block.id && link.sourceAnchorUnit != null) {
        final currentSide = _anchorSideUnit(link.sourceAnchorUnit!);
        if (currentSide == side) {
          final otherIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
          if (otherIndex == -1) {
            continue;
          }
          sideAnchors.add((
            link: link,
            isSource: true,
            sortKey: orderKeyFromOtherBlockCenter(
              _blockRectCanvas(blocks[otherIndex]).center,
            ),
            linkIndex: i,
          ));
        }
      }

      if (link.toBlockId == block.id && link.targetAnchorUnit != null) {
        final currentSide = _anchorSideUnit(link.targetAnchorUnit!);
        if (currentSide == side) {
          final otherIndex = blocks.indexWhere((b) => b.id == link.fromBlockId);
          if (otherIndex == -1) {
            continue;
          }
          sideAnchors.add((
            link: link,
            isSource: false,
            sortKey: orderKeyFromOtherBlockCenter(
              _blockRectCanvas(blocks[otherIndex]).center,
            ),
            linkIndex: i,
          ));
        }
      }
    }

    sideAnchors.sort((a, b) {
      final bySortKey = a.sortKey.compareTo(b.sortKey);
      if (bySortKey != 0) {
        return bySortKey;
      }
      return a.linkIndex.compareTo(b.linkIndex);
    });

    for (int i = 0; i < sideAnchors.length; i++) {
      final entry = sideAnchors[i];
      final orderKey = i.toDouble();
      if (entry.isSource) {
        entry.link.sourceAnchorOrderKey = orderKey;
      } else {
        entry.link.targetAnchorOrderKey = orderKey;
      }
    }
  }

  Offset _getBlockCenter(Block block) {
    return Offset(
      block.position.dx + block.size.width / 2,
      block.position.dy + block.size.height / 2,
    );
  }

  Offset _pointOnRectBorderTowards(Rect rect, Offset target) {
    final center = rect.center;
    final vector = target - center;
    if (vector.distanceSquared == 0) {
      return center;
    }

    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final scale =
        1 / math.max(vector.dx.abs() / halfW, vector.dy.abs() / halfH);
    return center + vector * scale;
  }

  Offset _normalizeAnchorUnit(Offset unit) {
    if (unit.distanceSquared == 0) {
      return const Offset(1, 0);
    }

    final maxAbs = math.max(unit.dx.abs(), unit.dy.abs());
    if (maxAbs == 0) {
      return const Offset(1, 0);
    }
    return unit / maxAbs;
  }

  Offset _borderPointFromUnit(
    Rect rect,
    Offset unit, {
    Offset spacingOffset = Offset.zero,
  }) {
    final normalized = _normalizeAnchorUnit(unit);
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final center = rect.center;
    return Offset(
      center.dx + normalized.dx * halfW + spacingOffset.dx,
      center.dy + normalized.dy * halfH + spacingOffset.dy,
    );
  }

  double _anchorOrderKeyFromCanvasPoint(
    Rect rect,
    Offset anchorUnit,
    Offset canvasPoint,
  ) {
    final side = _anchorSideUnit(anchorUnit);
    if (side.dx != 0) {
      return canvasPoint.dy - rect.center.dy;
    }
    if (side.dy != 0) {
      return canvasPoint.dx - rect.center.dx;
    }
    return 0;
  }

  double _stabilizeDraggedOrderKey({
    required double rawKey,
    required double? previousKey,
  }) {
    final spacingDistance = anchorSpacingDistance * zoomLevel;
    if (spacingDistance <= 0) {
      return rawKey;
    }

    final hysteresis = spacingDistance * 0.35;
    if (previousKey != null && (rawKey - previousKey).abs() < hysteresis) {
      return previousKey;
    }
    return rawKey;
  }

  Offset _anchorSideUnit(Offset unit) {
    final normalized = _normalizeAnchorUnit(unit);
    if (normalized.dx.abs() >= normalized.dy.abs()) {
      return Offset(normalized.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, normalized.dy >= 0 ? 1 : -1);
  }

  double _requiredCanvasExtentForAnchorCount(int count) {
    if (count <= 0) {
      return 0;
    }

    final spacingDistance = anchorSpacingDistance * zoomLevel;
    final sidePadding = anchorBorderMarginDistance * zoomLevel;
    return (count - 1) * spacingDistance + (2 * sidePadding);
  }

  void _ensureBlockHasSpaceForAnchors(Block block) {
    if (block.isZone || _isSequenceDiagramView) {
      return;
    }

    int leftCount = 0;
    int rightCount = 0;
    int topCount = 0;
    int bottomCount = 0;

    for (final link in links) {
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

  double _anchorOrderKeyForLinkSide(
    BlockLink link,
    String blockId,
    Offset anchorUnit,
    int linkIndex,
  ) {
    final side = _anchorSideUnit(anchorUnit);
    if (link.fromBlockId == blockId && link.sourceAnchorUnit != null) {
      if (_anchorSideUnit(link.sourceAnchorUnit!) == side) {
        return link.sourceAnchorOrderKey ?? linkIndex.toDouble();
      }
    }
    if (link.toBlockId == blockId && link.targetAnchorUnit != null) {
      if (_anchorSideUnit(link.targetAnchorUnit!) == side) {
        return link.targetAnchorOrderKey ?? linkIndex.toDouble();
      }
    }
    return linkIndex.toDouble();
  }

  Offset _getAnchorSpacingOffset(
    BlockLink currentLink,
    String blockId,
    Offset anchorUnit,
  ) {
    final side = _anchorSideUnit(anchorUnit);
    final spacingDistance = anchorSpacingDistance * zoomLevel;
    final blockIndex = blocks.indexWhere((b) => b.id == blockId);
    if (blockIndex == -1) {
      return Offset.zero;
    }
    final rect = _blockRectCanvas(blocks[blockIndex]);
    final currentLinkIndex = links.indexOf(currentLink);
    if (currentLinkIndex == -1) {
      return Offset.zero;
    }

    final sameSideEntries = <(int linkIndex, double key)>[];
    for (int i = 0; i < links.length; i++) {
      final link = links[i];
      final isSameSide =
          (link.fromBlockId == blockId &&
              link.sourceAnchorUnit != null &&
              _anchorSideUnit(link.sourceAnchorUnit!) == side) ||
          (link.toBlockId == blockId &&
              link.targetAnchorUnit != null &&
              _anchorSideUnit(link.targetAnchorUnit!) == side);
      if (!isSameSide) {
        continue;
      }
      sameSideEntries.add((
        i,
        _anchorOrderKeyForLinkSide(link, blockId, side, i),
      ));
    }
    if (sameSideEntries.isEmpty) {
      return Offset.zero;
    }

    sameSideEntries.sort((a, b) {
      final byKey = a.$2.compareTo(b.$2);
      if (byKey != 0) {
        return byKey;
      }
      return a.$1.compareTo(b.$1);
    });

    final rawKeys = sameSideEntries.map((e) => e.$2).toList(growable: false);
    final separatedKeys = List<double>.from(rawKeys);
    for (int i = 1; i < separatedKeys.length; i++) {
      final minNext = separatedKeys[i - 1] + spacingDistance;
      if (separatedKeys[i] < minNext) {
        separatedKeys[i] = minNext;
      }
    }

    final rawCenter = rawKeys.fold(0.0, (acc, v) => acc + v) / rawKeys.length;
    final separatedCenter =
        separatedKeys.fold(0.0, (acc, v) => acc + v) / separatedKeys.length;
    var centerOffset =
        separatedKeys[sameSideEntries.indexWhere(
          (e) => e.$1 == currentLinkIndex,
        )] +
        (rawCenter - separatedCenter);

    final edgeMargin = (_anchorHandleRadius * zoomLevel).clamp(
      3.0,
      _anchorHandleRadius,
    );
    final halfExtent = side.dx != 0 ? rect.height / 2 : rect.width / 2;
    final clampedCenterOffset = centerOffset
        .clamp(
          -math.max(0.0, halfExtent - edgeMargin),
          math.max(0.0, halfExtent - edgeMargin),
        )
        .toDouble();

    if (side.dx != 0) {
      return Offset(0, clampedCenterOffset);
    } else if (side.dy != 0) {
      return Offset(clampedCenterOffset, 0);
    }
    return Offset.zero;
  }

  List<Offset>? _linkControlPointsCanvas(BlockLink link) {
    final linkData = _resolveLinkAnchorsAndRects(link);
    if (linkData == null) {
      return null;
    }
    return [linkData.$1, ...linkData.$3, linkData.$2];
  }

  Offset _anchorUnitFromCanvasPoint(Rect rect, Offset canvasPoint) {
    final center = rect.center;
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    if (halfW == 0 || halfH == 0) {
      return const Offset(1, 0);
    }

    final normalized = Offset(
      (canvasPoint.dx - center.dx) / halfW,
      (canvasPoint.dy - center.dy) / halfH,
    );
    return _normalizeAnchorUnit(normalized);
  }

  (Offset, Offset, List<Offset>, Rect, Rect)? _resolveLinkAnchorsAndRects(
    BlockLink link,
  ) {
    final fromIndex = blocks.indexWhere((b) => b.id == link.fromBlockId);
    final toIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
    if (fromIndex == -1 || toIndex == -1) {
      return null;
    }

    final fromBlock = blocks[fromIndex];
    final toBlock = blocks[toIndex];
    final fromRect = _blockRectCanvas(fromBlock);
    final toRect = _blockRectCanvas(toBlock);
    final viaCanvas = link.inflectionPoints
        .map((point) => _modelToCanvas(point))
        .toList();

    final toBorderForSource = _pointOnRectBorderTowards(
      toRect,
      fromRect.center,
    );
    final fromBorderForTarget = _pointOnRectBorderTowards(
      fromRect,
      toRect.center,
    );
    final fromReference = viaCanvas.isNotEmpty
        ? viaCanvas.first
        : toBorderForSource;
    final toReference = viaCanvas.isNotEmpty
        ? viaCanvas.last
        : fromBorderForTarget;

    if (_isSequenceDiagramView) {
      final laneFromOrderKeysModel =
          link.sourceAnchorOrderKey ?? link.targetAnchorOrderKey;
      final defaultLaneCanvasY = laneFromOrderKeysModel != null
          ? (laneFromOrderKeysModel * zoomLevel) + canvasOffset.dy
          : math.max(
                  _sequenceLifelineStartCanvasY(fromBlock),
                  _sequenceLifelineStartCanvasY(toBlock),
                ) +
                (32.0 * zoomLevel);
      final sourceLaneCanvasY = viaCanvas.isNotEmpty
          ? viaCanvas.first.dy
          : defaultLaneCanvasY;
      final targetLaneCanvasY = viaCanvas.isNotEmpty
          ? viaCanvas.last.dy
          : defaultLaneCanvasY;

      final fromEdge = Offset(
        fromRect.center.dx,
        math.max(_sequenceLifelineStartCanvasY(fromBlock), sourceLaneCanvasY),
      );
      final toEdge = Offset(
        toRect.center.dx,
        math.max(_sequenceLifelineStartCanvasY(toBlock), targetLaneCanvasY),
      );
      return (fromEdge, toEdge, viaCanvas, fromRect, toRect);
    }

    final fromEdge = link.sourceAnchorUnit != null
        ? _borderPointFromUnit(
            fromRect,
            link.sourceAnchorUnit!,
            spacingOffset: _getAnchorSpacingOffset(
              link,
              link.fromBlockId,
              link.sourceAnchorUnit!,
            ),
          )
        : _pointOnRectBorderTowards(fromRect, fromReference);
    final toEdge = link.targetAnchorUnit != null
        ? _borderPointFromUnit(
            toRect,
            link.targetAnchorUnit!,
            spacingOffset: _getAnchorSpacingOffset(
              link,
              link.toBlockId,
              link.targetAnchorUnit!,
            ),
          )
        : _pointOnRectBorderTowards(toRect, toReference);

    return (fromEdge, toEdge, viaCanvas, fromRect, toRect);
  }

  Path? _linkPathCanvas(BlockLink link) {
    final linkData = _resolveLinkAnchorsAndRects(link);
    if (linkData == null) {
      return null;
    }

    final fromEdge = linkData.$1;
    final toEdge = linkData.$2;
    final viaCanvas = linkData.$3;
    final fromRect = linkData.$4;
    final toRect = linkData.$5;

    final startTangent = _outwardTangentForLinkEndpoint(
      link,
      isSource: true,
      rect: fromRect,
      edgePoint: fromEdge,
    );
    final targetOutward = _outwardTangentForLinkEndpoint(
      link,
      isSource: false,
      rect: toRect,
      edgePoint: toEdge,
    );
    final endTangent = Offset(-targetOutward.dx, -targetOutward.dy);

    final path = buildConnectorPath(
      fromEdge,
      toEdge,
      connectorType: link.connectorType,
      viaPoints: viaCanvas,
      startTangent: startTangent,
      endTangent: endTangent,
    );

    return path;
  }

  Offset _outwardTangentForLinkEndpoint(
    BlockLink link, {
    required bool isSource,
    required Rect rect,
    required Offset edgePoint,
  }) {
    if (_isSequenceDiagramView) {
      if (link.fromBlockId == link.toBlockId) {
        return const Offset(1, 0);
      }

      final ownId = isSource ? link.fromBlockId : link.toBlockId;
      final otherId = isSource ? link.toBlockId : link.fromBlockId;
      final ownIndex = blocks.indexWhere((b) => b.id == ownId);
      final otherIndex = blocks.indexWhere((b) => b.id == otherId);
      if (ownIndex != -1 && otherIndex != -1) {
        final ownCenterX = _blockRectCanvas(blocks[ownIndex]).center.dx;
        final otherCenterX = _blockRectCanvas(blocks[otherIndex]).center.dx;
        if ((ownCenterX - otherCenterX).abs() < 0.1) {
          return isSource ? const Offset(1, 0) : const Offset(-1, 0);
        }
        return ownCenterX <= otherCenterX
            ? const Offset(1, 0)
            : const Offset(-1, 0);
      }
      return isSource ? const Offset(1, 0) : const Offset(-1, 0);
    }

    final anchorUnit = isSource ? link.sourceAnchorUnit : link.targetAnchorUnit;
    if (anchorUnit != null) {
      return _anchorSideUnit(anchorUnit);
    }
    return axisNormalForBorderPoint(rect, edgePoint);
  }
}
