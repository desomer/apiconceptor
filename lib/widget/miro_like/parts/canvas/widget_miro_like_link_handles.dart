part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateLinkHandleMethods on _MiroLikeWidgetState {
  static const double _anchorReassignDragThresholdCanvas = 42.0;

  double _outsideDistanceToRect(Offset point, Rect rect) {
    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : (point.dx > rect.right ? point.dx - rect.right : 0.0);
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : (point.dy > rect.bottom ? point.dy - rect.bottom : 0.0);
    return math.sqrt((dx * dx) + (dy * dy));
  }

  bool _tryReassignLinkEndpointFromDrag({
    required BlockLink link,
    required bool isSource,
    required Offset canvasPosition,
    required Offset globalPosition,
  }) {
    final currentEndpointId = isSource ? link.fromBlockId : link.toBlockId;
    final oppositeEndpointId = isSource ? link.toBlockId : link.fromBlockId;
    final previousMovedSide = isSource
        ? (link.sourceAnchorUnit == null
              ? null
              : _anchorSideUnit(link.sourceAnchorUnit!))
        : (link.targetAnchorUnit == null
              ? null
              : _anchorSideUnit(link.targetAnchorUnit!));
    final oppositeSide = isSource
        ? (link.targetAnchorUnit == null
              ? null
              : _anchorSideUnit(link.targetAnchorUnit!))
        : (link.sourceAnchorUnit == null
              ? null
              : _anchorSideUnit(link.sourceAnchorUnit!));

    final currentBlock = blocks
        .where((block) => block.id == currentEndpointId)
        .firstOrNull;
    if (currentBlock == null) {
      return false;
    }

    final currentRect = _blockRectCanvas(currentBlock);
    final outsideDistance = _outsideDistanceToRect(canvasPosition, currentRect);
    if (outsideDistance < _anchorReassignDragThresholdCanvas) {
      return false;
    }

    final modelPosition = _toModelPosition(globalPosition);
    final hitBlock = _findTopBlockAtModelPosition(modelPosition);
    if (hitBlock == null || hitBlock.isZone) {
      return false;
    }

    if (hitBlock.id == currentEndpointId || hitBlock.id == oppositeEndpointId) {
      return false;
    }

    final oppositeBlock = blocks
        .where((block) => block.id == oppositeEndpointId)
        .firstOrNull;
    if (oppositeBlock == null) {
      return false;
    }

    Offset? newMovedSide;

    if (isSource) {
      link.fromBlockId = hitBlock.id;
      link.sourceAnchorUnit = _calculateOptimalAnchorUnit(
        _blockRectCanvas(hitBlock),
        _blockRectCanvas(oppositeBlock),
      );
      link.sourceAnchorOrderKey = null;
      newMovedSide = link.sourceAnchorUnit == null
          ? null
          : _anchorSideUnit(link.sourceAnchorUnit!);
    } else {
      link.toBlockId = hitBlock.id;
      link.targetAnchorUnit = _calculateOptimalAnchorUnit(
        _blockRectCanvas(hitBlock),
        _blockRectCanvas(oppositeBlock),
      );
      link.targetAnchorOrderKey = null;
      newMovedSide = link.targetAnchorUnit == null
          ? null
          : _anchorSideUnit(link.targetAnchorUnit!);
    }

    if (previousMovedSide != null) {
      _recomputeAnchorOrderKeysForBlockSide(currentBlock, previousMovedSide);
    }
    if (newMovedSide != null) {
      _recomputeAnchorOrderKeysForBlockSide(hitBlock, newMovedSide);
    }
    if (oppositeSide != null) {
      _recomputeAnchorOrderKeysForBlockSide(oppositeBlock, oppositeSide);
    }

    _ensureBlockHasSpaceForAnchors(currentBlock);
    _ensureBlockHasSpaceForAnchors(hitBlock);
    _ensureBlockHasSpaceForAnchors(oppositeBlock);
    return true;
  }

  List<WebLink> _webLinksForLink(BlockLink link) {
    final raw = (link.webLinksJson ?? '').trim();
    if (raw.isEmpty) {
      return const <WebLink>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <WebLink>[];
      }
      return decoded
          .map(WebLink.fromJson)
          .whereType<WebLink>()
          .toList(growable: false);
    } catch (_) {
      return const <WebLink>[];
    }
  }

  Future<void> _openWebLinksForLink(BlockLink link) async {
    final webLinks = _webLinksForLink(link);
    if (webLinks.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    await openWebLinks(
      context,
      webLinks,
      backgroundColor: colorPropertiesPanelBg,
      titleColor: colorTextPrimary,
      subtitleColor: colorTextSecondary,
    );
  }

  (double, Offset)? _closestDistanceAndPointOnPath(
    Path path,
    Offset tapCanvas,
  ) {
    final metrics = path.computeMetrics();
    final iterator = metrics.iterator;
    if (!iterator.moveNext()) {
      return null;
    }

    var bestDistSq = double.infinity;
    var bestPoint = Offset.zero;

    do {
      final metric = iterator.current;
      if (metric.length <= 0) {
        continue;
      }

      final sampleCount = math.max(24, (metric.length / 10).round());
      for (var i = 0; i <= sampleCount; i++) {
        final t = i / sampleCount;
        final offsetOnPath = metric.length * t;
        final tangent = metric.getTangentForOffset(offsetOnPath);
        if (tangent == null) {
          continue;
        }

        final distSq = (tapCanvas - tangent.position).distanceSquared;
        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          bestPoint = tangent.position;
        }
      }
    } while (iterator.moveNext());

    if (!bestDistSq.isFinite) {
      return null;
    }
    return (bestDistSq, bestPoint);
  }

  bool _insertInflectionPointOnLink(Offset tapCanvas) {
    if (_isSequenceDiagramView) {
      return false;
    }

    final toleranceSq = _linkHitTolerance * _linkHitTolerance;

    for (var linkIndex = links.length - 1; linkIndex >= 0; linkIndex--) {
      final link = links[linkIndex];
      final path = _linkPathCanvas(link);
      if (path == null) {
        continue;
      }
      final points = _linkControlPointsCanvas(link);
      if (points == null || points.length < 2) {
        continue;
      }

      final closest = _closestDistanceAndPointOnPath(path, tapCanvas);
      if (closest == null) {
        continue;
      }
      final bestDistSq = closest.$1;
      final closestCanvasPoint = closest.$2;

      if (bestDistSq <= toleranceSq) {
        _pushUndoSnapshot();
        var bestSegIndex = 0;
        var bestSegDistSq = double.infinity;
        for (var seg = 0; seg < points.length - 1; seg++) {
          final a = points[seg];
          final b = points[seg + 1];
          final ab = b - a;
          final abLenSq = ab.distanceSquared;
          if (abLenSq == 0) {
            continue;
          }

          final ap = closestCanvasPoint - a;
          final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq).clamp(0.0, 1.0);
          final projection = a + ab * t;
          final distSq = (closestCanvasPoint - projection).distanceSquared;
          if (distSq < bestSegDistSq) {
            bestSegDistSq = distSq;
            bestSegIndex = seg;
          }
        }

        final insertIndex = bestSegIndex.clamp(0, link.inflectionPoints.length);
        final modelPoint = (closestCanvasPoint - canvasOffset) / zoomLevel;
        link.inflectionPoints.insert(insertIndex, modelPoint);
        selectedLink = link;
        selectedBlock = null;
        _markBoardChanged();
        return true;
      }
    }

    return false;
  }

  BlockLink? _findLinkAtCanvasPosition(Offset tapCanvas) {
    final toleranceSq = _linkHitTolerance * _linkHitTolerance;

    for (var linkIndex = links.length - 1; linkIndex >= 0; linkIndex--) {
      final link = links[linkIndex];
      final path = _linkPathCanvas(link);
      if (path == null) {
        continue;
      }

      final closest = _closestDistanceAndPointOnPath(path, tapCanvas);
      if (closest == null) {
        continue;
      }
      final bestDistSq = closest.$1;

      if (bestDistSq <= toleranceSq) {
        return link;
      }
    }

    return null;
  }

  List<Widget> _buildInflectionHandles() {
    final widgets = <Widget>[];
    final link = selectedLink;
    if (link == null || !links.contains(link)) {
      return widgets;
    }

    for (
      var pointIndex = 0;
      pointIndex < link.inflectionPoints.length;
      pointIndex++
    ) {
      final modelPoint = link.inflectionPoints[pointIndex];
      final canvasPoint = _modelToCanvas(modelPoint);

      widgets.add(
        InflectionHandleWidget(
          left: canvasPoint.dx - _inflectionHandleRadius,
          top: canvasPoint.dy - _inflectionHandleRadius,
          radius: _inflectionHandleRadius,
          color: colorInflectionPoint,
          borderColor: colorAnchorBorder,
          shadowColor: colorShadow2,
          onTapDown: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onSecondaryTapDown: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              if (pointIndex >= 0 &&
                  pointIndex < link.inflectionPoints.length) {
                _pushUndoSnapshot();
                link.inflectionPoints.removeAt(pointIndex);
                _markBoardChanged();
              }
            });
          },
          onPanStart: (_) {
            _pushUndoSnapshot();
          },
          onPanUpdate: (details) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              link.inflectionPoints[pointIndex] += details.delta / zoomLevel;
              _markBoardChanged();
            });
          },
        ),
      );
    }

    return widgets;
  }

  String _linkCommentContextId(BlockLink link) {
    return 'apm/link/${widget.query}/${link.id}';
  }

  String _blockCommentContextId(Block block) {
    return 'apm/block/${widget.query}/${block.id}';
  }

  Widget _buildLinkCommentBadge({
    required double size,
    required bool selected,
  }) {
    final iconSize = (size * 0.62).clamp(1.0, 20.0);
    // final bgColor = selected
    //     ? colorLinkSelected.withValues(alpha: 0.2)
    //     : const Color(0xFF0F172A).withValues(alpha: 0.88);
    // final borderColor = selected ? colorLinkSelected : Colors.white24;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        // decoration: BoxDecoration(
        //   color: bgColor,
        //   borderRadius: BorderRadius.circular(size / 2),
        //   border: Border.all(color: borderColor, width: 1),
        // ),
        child: Icon(
          Icons.add_comment_outlined,
          size: iconSize,
          color: Colors.white70,
        ),
      ),
    );
  }

  Offset? _linkLabelReferenceCanvas(BlockLink link) {
    final linkData = _resolveLinkAnchorsAndRects(link);
    if (linkData == null) return null;

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

    final iterator = path.computeMetrics().iterator;
    if (!iterator.moveNext()) return null;

    final metric = iterator.current;
    if (metric.length <= 0) return null;

    final offsetOnPath = (metric.length * link.labelPosition).clamp(
      0.0,
      metric.length,
    );
    final tangent = metric.getTangentForOffset(offsetOnPath);
    if (tangent == null) return null;

    final normal = Offset(-math.sin(tangent.angle), math.cos(tangent.angle));
    final baseCenter =
        tangent.position +
        (normal * (18.0 * zoomLevel)) +
        (link.labelOffset * zoomLevel);
    final tagCount = link.tagColorKeys
        .where((key) => kBlockTagColorMap.containsKey(key))
        .length;
    if (tagCount == 0) {
      return baseCenter;
    }

    final textScale = zoomLevel;
    final squareSize = (8.0 * textScale).clamp(4.0, 16.0);
    final gap = (2.0 * textScale).clamp(1.0, 6.0);
    final columns = math.min(3, tagCount);
    final tagWidth = (columns * squareSize) + ((columns - 1) * gap);
    final tagSpacing = (6.0 * textScale).clamp(3.0, 14.0);
    return baseCenter + Offset(-((tagWidth + tagSpacing) * 0.5), 0);
  }

  List<Widget> _buildLinkLabelHandles() {
    final widgets = <Widget>[];
    final textScale = zoomLevel;

    for (final link in links) {
      if (link.name.trim().isEmpty) {
        continue;
      }

      final labelCenter = _linkLabelReferenceCanvas(link);
      if (labelCenter == null) {
        continue;
      }

      final iconExtraWidth = link.labelIconKey == null ? 0.0 : 20.0 * textScale;
      final validTagCount = link.tagColorKeys
          .where((key) => kBlockTagColorMap.containsKey(key))
          .length;
      final tagWidth = validTagCount == 0
          ? 0.0
          : (() {
              final squareSize = (8.0 * textScale).clamp(4.0, 16.0);
              final gap = (2.0 * textScale).clamp(1.0, 6.0);
              final columns = math.min(3, validTagCount);
              return (columns * squareSize) + ((columns - 1) * gap);
            })();
      final tagSpacing = validTagCount == 0
          ? 0.0
          : (6.0 * textScale).clamp(3.0, 14.0);

      final width = math.max(
        30.0 * textScale,
        link.name.length * 6.0 * textScale +
            28.0 * textScale +
            iconExtraWidth +
            tagWidth +
            tagSpacing,
      );
      final height = 32.0 * textScale;

      final widthLabel = math.max(
        30.0 * textScale,
        link.name.length * 6.0 * textScale + 28.0 * textScale + iconExtraWidth,
        // + tagWidth +
        // tagSpacing,
      );

      widgets.add(
        LinkLabelHandleWidget(
          left: labelCenter.dx - width / 2,
          top: labelCenter.dy - height / 2,
          width: width,
          height: height,
          onTapDown: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onPanStart: (_) {
            _pushUndoSnapshot();
          },
          onPanUpdate: (details) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              link.labelOffset += Offset(
                details.delta.dx / zoomLevel,
                details.delta.dy / zoomLevel,
              );
              _markBoardChanged();
            });
          },
        ),
      );


      final badgeSize = (24.0 * textScale).clamp(0.0, 24.0);
      final badgeLeft =
          labelCenter.dx + (widthLabel / 2) + tagWidth + (10* textScale) - (badgeSize * 0.6);
      final badgeTop = labelCenter.dy + (badgeSize * 0.1);
      /*+ (height / 2)*/ //+ (badgeSize * 0.15);
      widgets.add(
        Positioned(
          left: badgeLeft,
          top: badgeTop,
          width: badgeSize,
          height: badgeSize,
          child: ThreadCommentCell(
            contextId: _linkCommentContextId(link),
            childOver: selectedLink == link
                ? _buildLinkCommentBadge(size: badgeSize, selected: false)
                : SizedBox.shrink(),
            childIfComment: _buildLinkCommentBadge(
              size: badgeSize,
              selected: true,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildLinkWebLinkBadges() {
    final widgets = <Widget>[];
    final textScale = zoomLevel;

    for (final link in links) {
      final webLinks = _webLinksForLink(link);
      if (webLinks.isEmpty || link.name.trim().isEmpty) {
        continue;
      }

      final labelCenter = _linkLabelReferenceCanvas(link);
      if (labelCenter == null) {
        continue;
      }

      final validTagCount = link.tagColorKeys
          .where((key) => kBlockTagColorMap.containsKey(key))
          .length;
      final tagWidth = validTagCount == 0
          ? 0.0
          : (() {
              final squareSize = (8.0 * textScale).clamp(4.0, 16.0);
              final gap = (2.0 * textScale).clamp(1.0, 6.0);
              final columns = math.min(3, validTagCount);
              return (columns * squareSize) + ((columns - 1) * gap);
            })();

      final iconExtraWidth = link.labelIconKey == null ? 0.0 : 20.0 * textScale;
      final labelWidth = math.max(
        30.0 * textScale,
        link.name.length * 6.0 * textScale + 28.0 * textScale + iconExtraWidth,
      );
      final labelHeight = 32.0 * textScale;
      final badgeSize = (24.0 * textScale).clamp(0.0, 26.0);
      final left =
          labelCenter.dx + labelWidth / 2 + tagWidth + (10* textScale) - (badgeSize * 0.6);
      final top = labelCenter.dy - labelHeight / 2 - badgeSize * 0.1;

      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: badgeSize,
          height: badgeSize,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(badgeSize / 2),
              onTap: () async {
                await _openWebLinksForLink(link);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  // border: Border.all(
                  //   color: const Color(0xFF64C8FF).withValues(alpha: 0.95),
                  // ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(90, 0, 0, 0),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.link,
                      size: badgeSize * 0.52,
                      color: Colors.white,
                    ),
                    if (webLinks.length > 1)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64C8FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${webLinks.length}',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: badgeSize * 0.28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildBlockCommentBadges() {
    final widgets = <Widget>[];
    final textScale = zoomLevel;
    final badgeSize = (24.0 * textScale).clamp(16.0, 28.0);

    for (final block in blocks) {
      if (block.isZone) {
        continue;
      }

      final isSelected =
          _selectedBlockIds.contains(block.id) || selectedBlock?.id == block.id;

      final rect = _blockRectCanvas(block);
      final left = rect.right - (badgeSize * 0.45);
      final top = rect.top - (badgeSize * 0.35);

      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: badgeSize,
          height: badgeSize,
          child: ThreadCommentCell(
            contextId: _blockCommentContextId(block),
            childOver: isSelected
                ? _buildLinkCommentBadge(size: badgeSize, selected: isSelected)
                : SizedBox.shrink(),
            childIfComment: _buildLinkCommentBadge(
              size: badgeSize,
              selected: true,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildAnchorHandles() {
    final widgets = <Widget>[];

    final effectiveRadius = (_anchorHandleRadius * zoomLevel).clamp(
      3.0,
      _anchorHandleRadius,
    );

    for (var linkIndex = 0; linkIndex < links.length; linkIndex++) {
      final link = links[linkIndex];
      final linkData = _resolveLinkAnchorsAndRects(link);
      if (linkData == null) {
        continue;
      }

      final fromAnchor = linkData.$1;
      final toAnchor = linkData.$2;
      final fromRect = linkData.$4;
      final toRect = linkData.$5;

      widgets.add(
        AnchorHandleWidget(
          left: fromAnchor.dx - effectiveRadius,
          top: fromAnchor.dy - effectiveRadius,
          radius: effectiveRadius,
          color: colorAnchorSourceHandle,
          onTapDown: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onSecondaryTapDown: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              if (linkIndex >= 0 && linkIndex < links.length) {
                _pushUndoSnapshot();
                links.removeAt(linkIndex);
                if (selectedLink == link) {
                  selectedLink = null;
                }
                _markBoardChanged();
              }
            });
          },
          onPanStart: (_) {
            _pushUndoSnapshot();
            _detachPreviewLinkId = null;
            _detachPreviewCanvasPosition = null;
          },
          onPanUpdate: (details) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              final canvasPosition = _toCanvasLocal(details.globalPosition);

              if (_isSequenceDiagramView) {
                _detachPreviewLinkId = null;
                _detachPreviewCanvasPosition = null;
                final laneYCanvas = math.max(
                  fromRect.bottom + (8.0 * zoomLevel),
                  canvasPosition.dy,
                );
                final laneYModel = (laneYCanvas - canvasOffset.dy) / zoomLevel;
                _setSequenceLinkLaneY(link, laneYModel);
                _markBoardChanged();
                return;
              }

              final reassigned = _tryReassignLinkEndpointFromDrag(
                link: link,
                isSource: true,
                canvasPosition: canvasPosition,
                globalPosition: details.globalPosition,
              );
              if (reassigned) {
                _detachPreviewLinkId = null;
                _detachPreviewCanvasPosition = null;
                _markBoardChanged();
                return;
              }

              final sourceBlock = blocks
                  .where((b) => b.id == link.fromBlockId)
                  .firstOrNull;
              if (sourceBlock == null) {
                _detachPreviewLinkId = null;
                _detachPreviewCanvasPosition = null;
                return;
              }
              final activeSourceRect = _blockRectCanvas(sourceBlock);
              final sourceOutsideDistance = _outsideDistanceToRect(
                canvasPosition,
                activeSourceRect,
              );
              _detachPreviewLinkId =
                  sourceOutsideDistance >= _anchorReassignDragThresholdCanvas
                  ? link.id
                  : null;
              _detachPreviewIsSource = true;
              _detachPreviewCanvasPosition =
                  sourceOutsideDistance >= _anchorReassignDragThresholdCanvas
                  ? canvasPosition
                  : null;
              if (sourceOutsideDistance >= _anchorReassignDragThresholdCanvas) {
                return;
              }

              final snappedSide = _anchorSideUnit(
                _anchorUnitFromCanvasPoint(activeSourceRect, canvasPosition),
              );
              link.sourceAnchorUnit = snappedSide;
              final rawKey = _anchorOrderKeyFromCanvasPoint(
                activeSourceRect,
                snappedSide,
                canvasPosition,
              );
              link.sourceAnchorOrderKey = _stabilizeDraggedOrderKey(
                rawKey: rawKey,
                previousKey: link.sourceAnchorOrderKey,
              );
              final fromIndex = blocks.indexWhere(
                (b) => b.id == link.fromBlockId,
              );
              if (fromIndex != -1) {
                _ensureBlockHasSpaceForAnchors(blocks[fromIndex]);
              }
              _markBoardChanged();
            });
          },
          onPanEnd: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              _detachPreviewLinkId = null;
              _detachPreviewCanvasPosition = null;
            });
          },
        ),
      );

      widgets.add(
        AnchorHandleWidget(
          left: toAnchor.dx - effectiveRadius,
          top: toAnchor.dy - effectiveRadius,
          radius: effectiveRadius,
          color: colorAnchorTargetHandle,
          onTapDown: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onSecondaryTapDown: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              if (linkIndex >= 0 && linkIndex < links.length) {
                _pushUndoSnapshot();
                links.removeAt(linkIndex);
                if (selectedLink == link) {
                  selectedLink = null;
                }
                _markBoardChanged();
              }
            });
          },
          onPanStart: (_) {
            _pushUndoSnapshot();
            _detachPreviewLinkId = null;
            _detachPreviewCanvasPosition = null;
          },
          onPanUpdate: (details) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              final canvasPosition = _toCanvasLocal(details.globalPosition);

              if (_isSequenceDiagramView) {
                _detachPreviewLinkId = null;
                _detachPreviewCanvasPosition = null;
                final laneYCanvas = math.max(
                  toRect.bottom + (8.0 * zoomLevel),
                  canvasPosition.dy,
                );
                final laneYModel = (laneYCanvas - canvasOffset.dy) / zoomLevel;
                _setSequenceLinkLaneY(link, laneYModel);
                _markBoardChanged();
                return;
              }

              final reassigned = _tryReassignLinkEndpointFromDrag(
                link: link,
                isSource: false,
                canvasPosition: canvasPosition,
                globalPosition: details.globalPosition,
              );
              if (reassigned) {
                _detachPreviewLinkId = null;
                _detachPreviewCanvasPosition = null;
                _markBoardChanged();
                return;
              }

              final targetBlock = blocks
                  .where((b) => b.id == link.toBlockId)
                  .firstOrNull;
              if (targetBlock == null) {
                _detachPreviewLinkId = null;
                _detachPreviewCanvasPosition = null;
                return;
              }
              final activeTargetRect = _blockRectCanvas(targetBlock);
              final targetOutsideDistance = _outsideDistanceToRect(
                canvasPosition,
                activeTargetRect,
              );
              _detachPreviewLinkId =
                  targetOutsideDistance >= _anchorReassignDragThresholdCanvas
                  ? link.id
                  : null;
              _detachPreviewIsSource = false;
              _detachPreviewCanvasPosition =
                  targetOutsideDistance >= _anchorReassignDragThresholdCanvas
                  ? canvasPosition
                  : null;
              if (targetOutsideDistance >= _anchorReassignDragThresholdCanvas) {
                return;
              }

              final snappedSide = _anchorSideUnit(
                _anchorUnitFromCanvasPoint(activeTargetRect, canvasPosition),
              );
              link.targetAnchorUnit = snappedSide;
              final rawKey = _anchorOrderKeyFromCanvasPoint(
                activeTargetRect,
                snappedSide,
                canvasPosition,
              );
              link.targetAnchorOrderKey = _stabilizeDraggedOrderKey(
                rawKey: rawKey,
                previousKey: link.targetAnchorOrderKey,
              );
              final toIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
              if (toIndex != -1) {
                _ensureBlockHasSpaceForAnchors(blocks[toIndex]);
              }
              _markBoardChanged();
            });
          },
          onPanEnd: (_) {
            // ignore: invalid_use_of_protected_member
            setState(() {
              _detachPreviewLinkId = null;
              _detachPreviewCanvasPosition = null;
            });
          },
        ),
      );
    }

    return widgets;
  }
}
