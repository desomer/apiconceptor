part of '../../widget_miro_like.dart';

class _SequenceControlSnapshot {
  final int startIndex;
  final int endIndex;
  final int depth;
  final String openLine;
  final List<String> elseLines;
  final String endLine;
  final BlockLink sourceLink;
  final int sourceOpenLineIndex;
  final List<BlockLink> memberLinks;
  final List<int> memberBranchIndices;

  const _SequenceControlSnapshot({
    required this.startIndex,
    required this.endIndex,
    required this.depth,
    required this.openLine,
    required this.elseLines,
    required this.endLine,
    required this.sourceLink,
    required this.sourceOpenLineIndex,
    required this.memberLinks,
    required this.memberBranchIndices,
  });
}

class _SequenceOpenCapture {
  final int startIndex;
  final int depth;
  final String openLine;
  final BlockLink sourceLink;
  final int sourceOpenLineIndex;
  final List<String> elseLines = <String>[];
  final List<BlockLink> memberLinks = <BlockLink>[];
  final List<int> memberBranchIndices = <int>[];
  int currentBranchIndex = 0;

  _SequenceOpenCapture({
    required this.startIndex,
    required this.depth,
    required this.openLine,
    required this.sourceLink,
    required this.sourceOpenLineIndex,
  });
}

class _SequenceLayoutSlotMetrics {
  final int depthAtMessage;
  final int openCountBefore;
  final int elseCountBefore;
  final int elseCountAfter;
  final int endCountAfter;

  const _SequenceLayoutSlotMetrics({
    required this.depthAtMessage,
    required this.openCountBefore,
    required this.elseCountBefore,
    required this.elseCountAfter,
    required this.endCountAfter,
  });
}

class _SequenceNormalizeOpenCapture {
  final String kind;
  int currentBranchIndex;
  final List<int> branchMessageCounts;
  final List<(BlockLink link, bool isBefore, int lineIndex)> elseRefs;

  _SequenceNormalizeOpenCapture(this.kind)
    : currentBranchIndex = 0,
      branchMessageCounts = <int>[0],
      elseRefs = <(BlockLink link, bool isBefore, int lineIndex)>[];
}

extension _MiroLikeWidgetStateSequenceMethods on _MiroLikeWidgetState {
  bool _isAltControlOpenLine(String rawOpenLine) {
    final trimmed = rawOpenLine.trim().toLowerCase();
    return trimmed.startsWith('alt');
  }

  (BlockLink, int)? _findSequenceGroupClosingEndLine(
    SequenceControlGroupInfo target,
  ) {
    final sortedEntries = _buildSequenceMessageEntries()
      ..sort((a, b) => a.laneYCanvas.compareTo(b.laneYCanvas));

    final openStack = <(BlockLink link, int lineIndex)>[];
    for (final entry in sortedEntries) {
      for (
        var lineIndex = 0;
        lineIndex < entry.link.sequenceBeforeLines.length;
        lineIndex++
      ) {
        final trimmed = entry.link.sequenceBeforeLines[lineIndex].trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final openMatch = RegExp(
          r'^(alt|opt|loop)\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (openMatch != null) {
          openStack.add((entry.link, lineIndex));
        }
      }

      for (
        var afterIndex = 0;
        afterIndex < entry.link.sequenceAfterLines.length;
        afterIndex++
      ) {
        final trimmed = entry.link.sequenceAfterLines[afterIndex].trim();
        if (!RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed)) {
          continue;
        }
        if (openStack.isEmpty) {
          continue;
        }
        final open = openStack.removeLast();
        if (identical(open.$1, target.sourceLink) &&
            open.$2 == target.sourceOpenLineIndex) {
          return (entry.link, afterIndex);
        }
      }
    }

    return null;
  }

  (BlockLink, int)? _findSequenceGroupElseLine(
    SequenceControlGroupInfo target,
    int elseIndex,
  ) {
    if (elseIndex < 0) {
      return null;
    }

    final sortedEntries = _buildSequenceMessageEntries()
      ..sort((a, b) => a.laneYCanvas.compareTo(b.laneYCanvas));

    final openStack = <(BlockLink link, int lineIndex)>[];
    var remainingElse = elseIndex;
    for (final entry in sortedEntries) {
      for (
        var lineIndex = 0;
        lineIndex < entry.link.sequenceBeforeLines.length;
        lineIndex++
      ) {
        final trimmed = entry.link.sequenceBeforeLines[lineIndex].trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final openMatch = RegExp(
          r'^(alt|opt|loop)\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (openMatch != null) {
          openStack.add((entry.link, lineIndex));
          continue;
        }

        final elseMatch = RegExp(
          r'^else\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (elseMatch != null && openStack.isNotEmpty) {
          final open = openStack.last;
          final isTarget =
              identical(open.$1, target.sourceLink) &&
              open.$2 == target.sourceOpenLineIndex;
          if (!isTarget) {
            continue;
          }

          if (remainingElse == 0) {
            return (entry.link, lineIndex);
          }
          remainingElse--;
        }
      }

      for (
        var afterIndex = 0;
        afterIndex < entry.link.sequenceAfterLines.length;
        afterIndex++
      ) {
        final trimmed = entry.link.sequenceAfterLines[afterIndex].trim();
        if (!RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed)) {
          continue;
        }
        if (openStack.isEmpty) {
          continue;
        }
        openStack.removeLast();
      }
    }

    return null;
  }

  void _deleteSequenceGroup(SequenceControlGroupInfo group) {
    _pushUndoSnapshot();
    // ignore: invalid_use_of_protected_member
    setState(() {
      final closingEnd = _findSequenceGroupClosingEndLine(group);
      if (closingEnd != null) {
        final closeLink = closingEnd.$1;
        final closeLineIndex = closingEnd.$2;
        if (closeLineIndex >= 0 &&
            closeLineIndex < closeLink.sequenceAfterLines.length) {
          closeLink.sequenceAfterLines.removeAt(closeLineIndex);
        }
      }

      final openLineIndex = group.sourceOpenLineIndex;
      if (openLineIndex >= 0 &&
          openLineIndex < group.sourceLink.sequenceBeforeLines.length) {
        group.sourceLink.sequenceBeforeLines.removeAt(openLineIndex);
      }

      _selectedSequenceGroup = null;
      _markBoardChanged();
    });
  }

  void _addElseToSequenceGroup(SequenceControlGroupInfo group) {
    if (!_isSequenceDiagramView) {
      return;
    }
    if (group.kind.trim().toLowerCase() != 'alt') {
      return;
    }

    final closingEnd = _findSequenceGroupClosingEndLine(group);
    if (closingEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'ajouter else: fin de groupe introuvable.',
          ),
        ),
      );
      return;
    }

    _pushUndoSnapshot();
    // ignore: invalid_use_of_protected_member
    setState(() {
      final closeLink = closingEnd.$1;
      final closeLineIndex = closingEnd.$2;
      final insertionIndex = closeLineIndex.clamp(
        0,
        closeLink.sequenceAfterLines.length,
      );
      closeLink.sequenceAfterLines.insert(insertionIndex, 'else');

      if (_selectedSequenceGroup?.selectionKey == group.selectionKey) {
        _selectedSequenceGroup = SequenceControlGroupInfo(
          kind: group.kind,
          label: group.label,
          startYCanvas: group.startYCanvas,
          endYCanvas: group.endYCanvas,
          branchCount: group.branchCount + 1,
          sourceLink: group.sourceLink,
          sourceOpenLineIndex: group.sourceOpenLineIndex,
        );
      }

      _markBoardChanged();
    });
  }

  void _deleteSelectedSequenceMessages() {
    if (_selectedSequenceLinks.isEmpty) {
      return;
    }
    _pushUndoSnapshot();
    // ignore: invalid_use_of_protected_member
    setState(() {
      final toDelete = List<BlockLink>.from(_selectedSequenceLinks);
      for (final link in toDelete) {
        linkManager.deleteLink(links, link);
      }
      _selectedSequenceLinks.clear();
      if (selectedLink != null && !links.contains(selectedLink)) {
        selectedLink = null;
      }
      _selectedSequenceGroup = null;
      _markBoardChanged();
    });
  }

  void _createSequenceGroupFromSelection(
    String kind,
    String label,
    bool nested,
  ) {
    if (!_isSequenceDiagramView || _selectedSequenceLinks.isEmpty) {
      return;
    }

    if (!_isSelectedSequenceMessageRangeContiguous()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selection de messages non continue: impossible de creer un cadre.',
          ),
        ),
      );
      return;
    }

    final normalizedKind = kind.trim().toLowerCase();
    if (normalizedKind != 'alt' &&
        normalizedKind != 'opt' &&
        normalizedKind != 'loop') {
      return;
    }
    final normalizedLabel = label.trim();
    final openLine = normalizedLabel.isEmpty
        ? normalizedKind
        : '$normalizedKind $normalizedLabel';

    final selectedOrdered = _orderedSequenceLinks()
        .where((link) => _selectedSequenceLinks.contains(link))
        .toList(growable: true);
    if (selectedOrdered.isEmpty) {
      return;
    }

    _pushUndoSnapshot();
    // ignore: invalid_use_of_protected_member
    setState(() {
      final first = selectedOrdered.first;
      final last = selectedOrdered.last;

      int sourceOpenLineIndex;
      if (nested) {
        first.sequenceBeforeLines.add(openLine);
        last.sequenceAfterLines.insert(0, 'end');
        sourceOpenLineIndex = first.sequenceBeforeLines.length - 1;
      } else {
        first.sequenceBeforeLines.insert(0, openLine);
        last.sequenceAfterLines.add('end');
        sourceOpenLineIndex = 0;
      }

      _finalizeSequenceLayoutCommon();

      final entryByLink = <BlockLink, SequenceMessageEntry>{
        for (final entry in _buildSequenceMessageEntries()) entry.link: entry,
      };
      final firstEntry = entryByLink[first];
      final lastEntry = entryByLink[last];
      if (firstEntry != null && lastEntry != null) {
        _selectedSequenceGroup = SequenceControlGroupInfo(
          kind: normalizedKind,
          label: normalizedLabel,
          startYCanvas: firstEntry.topYCanvas,
          endYCanvas: lastEntry.bottomYCanvas,
          branchCount: 0,
          sourceLink: first,
          sourceOpenLineIndex: sourceOpenLineIndex,
        );
      }

      _markBoardChanged();
    });
  }

  bool _isSelectedSequenceMessageRangeContiguous() {
    final orderedAll = _orderedSequenceLinks();
    if (orderedAll.isEmpty || _selectedSequenceLinks.isEmpty) {
      return false;
    }

    final selectedIndices = <int>[];
    for (var i = 0; i < orderedAll.length; i++) {
      if (_selectedSequenceLinks.contains(orderedAll[i])) {
        selectedIndices.add(i);
      }
    }
    if (selectedIndices.isEmpty) {
      return false;
    }

    final minIndex = selectedIndices.reduce(math.min);
    final maxIndex = selectedIndices.reduce(math.max);
    return (maxIndex - minIndex + 1) == selectedIndices.length;
  }

  String? _sequenceGroupCreationValidationMessage() {
    if (!_isSequenceDiagramView || _selectedSequenceLinks.isEmpty) {
      return null;
    }
    if (_isSelectedSequenceMessageRangeContiguous()) {
      return null;
    }
    return 'Selection non continue: selectionnez des messages consecutifs pour creer un cadre.';
  }

  void _normalizeSequenceMessageGeometryAndSpacing() {
    if (!_isSequenceDiagramView) {
      return;
    }

    final sequenceLinks = _orderedSequenceLinks();
    for (final link in sequenceLinks) {
      final laneYModel = _sequenceLaneYModel(link);
      _setSequenceLinkLaneY(link, laneYModel);
    }

    _reorderSequenceMessagesByLane();
  }

  void _finalizeSequenceLayoutCommon() {
    _isSequenceDiagramView = true;
    _normalizeSequenceMessageGeometryAndSpacing();
  }

  void _setSequenceLinkLaneY(BlockLink link, double laneYModel) {
    final fromBlock = blocks.where((b) => b.id == link.fromBlockId).firstOrNull;
    final toBlock = blocks.where((b) => b.id == link.toBlockId).firstOrNull;
    if (fromBlock == null || toBlock == null) {
      return;
    }

    final fromCenterX = fromBlock.position.dx + (fromBlock.size.width / 2);

    if (link.fromBlockId == link.toBlockId) {
      final loopX = fromCenterX + _sequenceSelfLoopHorizontalOffset;
      final loopReturnY = laneYModel + _sequenceSelfLoopVerticalOffset;
      link.inflectionPoints
        ..clear()
        ..add(Offset(loopX, laneYModel))
        ..add(Offset(loopX, loopReturnY))
        ..add(Offset(fromCenterX, loopReturnY));
    } else {
      // For regular sequence messages, keep the geometry horizontal without
      // extra trajectory points. The lane is stored on anchor order keys.
      link.inflectionPoints.clear();
    }

    link.sourceAnchorUnit = const Offset(0, 1);
    link.targetAnchorUnit = const Offset(0, 1);
    link.sourceAnchorOrderKey = laneYModel;
    link.targetAnchorOrderKey = laneYModel;
    link.connectorType = ConnectorType.orthogonal;
  }

  void _syncSequenceMessagesForParticipant(String participantId) {
    if (!_isSequenceDiagramView) {
      return;
    }

    for (final link in links) {
      final touchesParticipant =
          link.fromBlockId == participantId || link.toBlockId == participantId;
      if (!touchesParticipant) {
        continue;
      }

      final laneYModel = _sequenceLaneYModel(link);
      _setSequenceLinkLaneY(link, laneYModel);
    }
  }

  List<BlockLink> _sequenceMessageLinks() {
    final participantIds = blocks
        .where((b) => !b.isZone)
        .map((b) => b.id)
        .toSet();
    return links
        .where(
          (l) =>
              participantIds.contains(l.fromBlockId) &&
              participantIds.contains(l.toBlockId),
        )
        .toList(growable: true);
  }

  List<BlockLink> _orderedSequenceLinks() {
    final ordered = _sequenceMessageLinks();
    ordered.sort((a, b) {
      final byLane = _sequenceLaneYModel(a).compareTo(_sequenceLaneYModel(b));
      if (byLane != 0) {
        return byLane;
      }
      return links.indexOf(a).compareTo(links.indexOf(b));
    });
    return ordered;
  }

  double _sequenceLaneYModel(BlockLink link) {
    if (link.inflectionPoints.isNotEmpty) {
      return link.inflectionPoints.first.dy;
    }

    final orderedLaneY = link.sourceAnchorOrderKey ?? link.targetAnchorOrderKey;
    if (orderedLaneY != null) {
      return orderedLaneY;
    }

    final fromBlock = blocks.where((b) => b.id == link.fromBlockId).firstOrNull;
    final toBlock = blocks.where((b) => b.id == link.toBlockId).firstOrNull;
    if (fromBlock == null || toBlock == null) {
      return _sequenceMessageStartY;
    }

    final fallbackCanvasY =
        math.max(
          _blockRectCanvas(fromBlock).bottom,
          _blockRectCanvas(toBlock).bottom,
        ) +
        (40.0 * zoomLevel);
    return (fallbackCanvasY - canvasOffset.dy) / zoomLevel;
  }

  double _sequenceMessageVisualHeightModel(BlockLink link) {
    if (link.inflectionPoints.isEmpty) {
      return 0.0;
    }

    final yValues = link.inflectionPoints
        .map((p) => p.dy)
        .toList(growable: false);
    final minY = yValues.reduce(math.min);
    final maxY = yValues.reduce(math.max);
    var r = math.max(0.0, maxY - minY);
    return r;
  }

  int _countSequenceOpenLines(List<String> lines) {
    var count = 0;
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (RegExp(
        r'^(alt|opt|loop)\b',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        count++;
      }
    }
    return count;
  }

  int _countSequenceElseLines(List<String> lines) {
    var count = 0;
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (RegExp(r'^else\b', caseSensitive: false).hasMatch(trimmed)) {
        count++;
      }
    }
    return count;
  }

  int _countSequenceEndLines(List<String> lines) {
    var count = 0;
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed)) {
        count++;
      }
    }
    return count;
  }

  double _sequenceMinGapBetweenMessages(BlockLink previous, BlockLink current) {
    final visualHeight = _sequenceMessageVisualHeightModel(previous);
    return _sequenceMessageStepY + visualHeight;
  }

  Map<BlockLink, _SequenceLayoutSlotMetrics> _sequenceLayoutMetricsByOrder(
    List<BlockLink> ordered,
  ) {
    final metricsByLink = <BlockLink, _SequenceLayoutSlotMetrics>{};
    var activeDepth = 0;

    for (final link in ordered) {
      final openCountBefore = _countSequenceOpenLines(link.sequenceBeforeLines);
      final elseCountBefore = _countSequenceElseLines(link.sequenceBeforeLines);
      final elseCountAfter = _countSequenceElseLines(link.sequenceAfterLines);
      final depthAtMessage = activeDepth + openCountBefore;
      final endCountAfter = _countSequenceEndLines(link.sequenceAfterLines);

      metricsByLink[link] = _SequenceLayoutSlotMetrics(
        depthAtMessage: depthAtMessage,
        openCountBefore: openCountBefore,
        elseCountBefore: elseCountBefore,
        elseCountAfter: elseCountAfter,
        endCountAfter: endCountAfter,
      );

      activeDepth = depthAtMessage - endCountAfter;
      if (activeDepth < 0) {
        activeDepth = 0;
      }
    }

    return metricsByLink;
  }

  double _minSequenceLaneCanvasY(BlockLink link) {
    final fromBlock = blocks.where((b) => b.id == link.fromBlockId).firstOrNull;
    final toBlock = blocks.where((b) => b.id == link.toBlockId).firstOrNull;
    if (fromBlock == null || toBlock == null) {
      return _sequenceMessageStartY * zoomLevel + canvasOffset.dy;
    }
    return math.max(
      _sequenceLifelineStartCanvasY(fromBlock),
      _sequenceLifelineStartCanvasY(toBlock),
    );
  }

  List<SequenceMessageEntry> _buildSequenceMessageEntries() {
    final entries = <SequenceMessageEntry>[];
    for (final link in _sequenceMessageLinks()) {
      final linkData = _resolveLinkAnchorsAndRects(link);
      if (linkData == null) {
        continue;
      }
      final fromEdge = linkData.$1;
      final toEdge = linkData.$2;
      final via = linkData.$3;
      final fromRect = linkData.$4;
      final toRect = linkData.$5;
      final laneYCanvas = via.isNotEmpty
          ? via.first.dy
          : math.max(fromEdge.dy, toEdge.dy);
      final xValues = <double>[fromEdge.dx, toEdge.dx, ...via.map((p) => p.dx)];
      final yValues = <double>[fromEdge.dy, toEdge.dy, ...via.map((p) => p.dy)];
      final leftXCanvas = xValues.reduce(math.min);
      final rightXCanvas = xValues.reduce(math.max);
      final concernedLeftCanvas = math.min(fromRect.left, toRect.left);
      final concernedRightCanvas = math.max(fromRect.right, toRect.right);
      final topYCanvas = yValues.reduce(math.min);
      final bottomYCanvas = yValues.reduce(math.max);

      entries.add(
        SequenceMessageEntry(
          link: link,
          laneYCanvas: laneYCanvas,
          leftXCanvas: leftXCanvas,
          rightXCanvas: rightXCanvas,
          concernedLeftCanvas: concernedLeftCanvas,
          concernedRightCanvas: concernedRightCanvas,
          startXCanvas: fromEdge.dx,
          endXCanvas: toEdge.dx,
          topYCanvas: topYCanvas,
          bottomYCanvas: bottomYCanvas,
        ),
      );
    }
    return entries;
  }

  List<SequenceControlGroupInfo> _buildSequenceControlGroupsForHitTest(
    List<SequenceMessageEntry> rawEntries,
  ) {
    final sortedEntries = List<SequenceMessageEntry>.from(rawEntries)
      ..sort((a, b) => a.laneYCanvas.compareTo(b.laneYCanvas));
    if (sortedEntries.isEmpty) {
      return const <SequenceControlGroupInfo>[];
    }

    final frames = <_SequenceControlFrame>[];
    final openFrames = <_OpenFrame>[];
    final lastY = sortedEntries.last.bottomYCanvas;

    (double left, double right) frameHorizontalSpan(
      int startIndex,
      int endIndex,
    ) {
      var minLeft = double.infinity;
      var maxRight = -double.infinity;
      for (var i = startIndex; i <= endIndex; i++) {
        final candidate = sortedEntries[i];
        final messageLeft = math.min(
          candidate.concernedLeftCanvas,
          math.min(
            candidate.leftXCanvas,
            math.min(candidate.startXCanvas, candidate.endXCanvas),
          ),
        );
        final messageRight = math.max(
          candidate.concernedRightCanvas,
          math.max(
            candidate.rightXCanvas,
            math.max(candidate.startXCanvas, candidate.endXCanvas),
          ),
        );
        minLeft = math.min(minLeft, messageLeft);
        maxRight = math.max(maxRight, messageRight);
      }
      if (!minLeft.isFinite || !maxRight.isFinite || maxRight <= minLeft) {
        minLeft = sortedEntries[startIndex].leftXCanvas;
        maxRight = sortedEntries[endIndex].rightXCanvas;
      }
      return (minLeft, maxRight + (_sequenceFrameRightGap * zoomLevel));
    }

    double separatorYForEntry(int index) {
      final current = sortedEntries[index];
      if (index == 0) {
        return current.topYCanvas;
      }
      final previous = sortedEntries[index - 1];
      return (previous.bottomYCanvas + current.topYCanvas) / 2;
    }

    for (var index = 0; index < sortedEntries.length; index++) {
      final entry = sortedEntries[index];
      final separatorY = separatorYForEntry(index);

      for (
        var lineIndex = 0;
        lineIndex < entry.link.sequenceBeforeLines.length;
        lineIndex++
      ) {
        final line = entry.link.sequenceBeforeLines[lineIndex];
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final openMatch = RegExp(
          r'^(alt|opt|loop)\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (openMatch != null) {
          openFrames.add(
            _OpenFrame(
              kind: (openMatch.group(1) ?? '').toLowerCase(),
              label: (openMatch.group(2) ?? '').trim(),
              startY: entry.topYCanvas,
              startEntryIndex: index,
              depth: openFrames.length,
              sourceLink: entry.link,
              sourceOpenLineIndex: lineIndex,
            ),
          );
          continue;
        }

        final elseMatch = RegExp(
          r'^else\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (elseMatch != null && openFrames.isNotEmpty) {
          final current = openFrames.last;
          if (current.kind == 'alt') {
            current.branches.add(
              _SequenceControlBranch(
                y: separatorY,
                label: (elseMatch.group(1) ?? '').trim(),
              ),
            );
          }
        }
      }

      for (final rawLine in entry.link.sequenceAfterLines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final elseMatch = RegExp(
          r'^else\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (elseMatch != null && openFrames.isNotEmpty) {
          final current = openFrames.last;
          if (current.kind == 'alt') {
            current.branches.add(
              _SequenceControlBranch(
                y: separatorY,
                label: (elseMatch.group(1) ?? '').trim(),
              ),
            );
          }
          continue;
        }

        if (RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed) &&
            openFrames.isNotEmpty) {
          final current = openFrames.removeLast();
          final span = frameHorizontalSpan(current.startEntryIndex, index);
          frames.add(
            _SequenceControlFrame(
              kind: current.kind,
              label: current.label,
              startY: current.startY,
              endY: entry.bottomYCanvas,
              leftCanvas: span.$1,
              rightCanvas: span.$2,
              depth: current.depth,
              startEntryIndex: current.startEntryIndex,
              endEntryIndex: index,
              branches: List<_SequenceControlBranch>.from(current.branches),
              sourceLink: current.sourceLink,
              sourceOpenLineIndex: current.sourceOpenLineIndex,
            ),
          );
        }
      }
    }

    while (openFrames.isNotEmpty) {
      final current = openFrames.removeLast();
      final span = frameHorizontalSpan(
        current.startEntryIndex,
        sortedEntries.length - 1,
      );
      frames.add(
        _SequenceControlFrame(
          kind: current.kind,
          label: current.label,
          startY: current.startY,
          endY: lastY,
          leftCanvas: span.$1,
          rightCanvas: span.$2,
          depth: current.depth,
          startEntryIndex: current.startEntryIndex,
          endEntryIndex: sortedEntries.length - 1,
          branches: List<_SequenceControlBranch>.from(current.branches),
          sourceLink: current.sourceLink,
          sourceOpenLineIndex: current.sourceOpenLineIndex,
        ),
      );
    }

    final resolvedFrames = _resolveSequenceControlFrameLayout(
      frames,
      sortedEntries: sortedEntries,
      zoomLevel: zoomLevel,
    );

    final result =
        resolvedFrames
            .map(
              (resolved) => SequenceControlGroupInfo(
                kind: resolved.frame.kind,
                label: resolved.frame.label,
                startYCanvas: resolved.top,
                endYCanvas: resolved.bottom,
                branchCount: resolved.frame.branches.length,
                branchSeparatorYCanvas: resolved.frame.branches
                    .map((branch) => branch.y)
                    .toList(growable: false),
                branchLabels: resolved.frame.branches
                    .map((branch) => branch.label)
                    .toList(growable: false),
                sourceLink: resolved.frame.sourceLink,
                sourceOpenLineIndex: resolved.frame.sourceOpenLineIndex,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final byStart = a.startYCanvas.compareTo(b.startYCanvas);
            if (byStart != 0) {
              return byStart;
            }
            return a.endYCanvas.compareTo(b.endYCanvas);
          });

    return result;
  }

  SequenceControlGroupInfo? _findSequenceControlGroupAtCanvasPosition(
    Offset canvasPosition, {
    List<SequenceMessageEntry>? rawEntriesOverride,
  }) {
    final span = _buildSequenceGroupSpan();
    if (span == null) {
      return null;
    }
    if (canvasPosition.dx < span.leftCanvas ||
        canvasPosition.dx > span.rightCanvas) {
      return null;
    }

    final groups = _buildSequenceControlGroupsForHitTest(
      rawEntriesOverride ?? _buildSequenceMessageEntries(),
    );
    final matches = groups
        .where((group) {
          return canvasPosition.dy >= group.startYCanvas &&
              canvasPosition.dy <= group.endYCanvas;
        })
        .toList(growable: false);

    if (matches.isEmpty) {
      return null;
    }

    int nestingDepth(SequenceControlGroupInfo candidate) {
      var depth = 0;
      for (final group in groups) {
        if (identical(group, candidate)) {
          continue;
        }
        final containsCandidate =
            group.startYCanvas <= candidate.startYCanvas &&
            group.endYCanvas >= candidate.endYCanvas &&
            (group.startYCanvas < candidate.startYCanvas ||
                group.endYCanvas > candidate.endYCanvas);
        if (containsCandidate) {
          depth++;
        }
      }
      return depth;
    }

    final sorted = List<SequenceControlGroupInfo>.from(matches)
      ..sort((a, b) {
        final depthCompare = nestingDepth(b).compareTo(nestingDepth(a));
        if (depthCompare != 0) {
          return depthCompare;
        }

        final heightA = a.endYCanvas - a.startYCanvas;
        final heightB = b.endYCanvas - b.startYCanvas;
        final byHeight = heightA.compareTo(heightB);
        if (byHeight != 0) {
          return byHeight;
        }

        final byStartDesc = b.startYCanvas.compareTo(a.startYCanvas);
        if (byStartDesc != 0) {
          return byStartDesc;
        }

        final byOpenLineIndexDesc = b.sourceOpenLineIndex.compareTo(
          a.sourceOpenLineIndex,
        );
        if (byOpenLineIndexDesc != 0) {
          return byOpenLineIndexDesc;
        }

        return a.endYCanvas.compareTo(b.endYCanvas);
      });

    final selected = sorted.first;
    if (selected.kind != 'alt') {
      return selected;
    }

    final separators = <double>[
      selected.startYCanvas,
      ...selected.branchSeparatorYCanvas,
      selected.endYCanvas,
    ]..sort();

    var branchIndex = 0;
    var matched = false;
    for (var i = 0; i < separators.length - 1; i++) {
      final top = separators[i];
      final bottom = separators[i + 1];
      final within = canvasPosition.dy >= top && canvasPosition.dy <= bottom;
      if (within) {
        branchIndex = i;
        matched = true;
        break;
      }
    }

    if (!matched && separators.length >= 2) {
      final center = canvasPosition.dy.clamp(separators.first, separators.last);
      var bestDistance = double.infinity;
      for (var i = 0; i < separators.length - 1; i++) {
        final mid = (separators[i] + separators[i + 1]) / 2;
        final distance = (center - mid).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          branchIndex = i;
        }
      }
    }

    final selectedBranchTop = separators[branchIndex];
    final selectedBranchBottom = separators[branchIndex + 1];
    return SequenceControlGroupInfo(
      kind: selected.kind,
      label: selected.label,
      startYCanvas: selectedBranchTop,
      endYCanvas: selectedBranchBottom,
      branchCount: selected.branchCount,
      branchSeparatorYCanvas: selected.branchSeparatorYCanvas,
      branchLabels: selected.branchLabels,
      targetBranchIndex: branchIndex,
      sourceLink: selected.sourceLink,
      sourceOpenLineIndex: selected.sourceOpenLineIndex,
    );
  }

  SequenceGroupSpan? _buildSequenceGroupSpan() {
    final participants = blocks.where((b) => !b.isZone).toList(growable: false);
    var minLeft = double.infinity;
    var maxRight = -double.infinity;

    if (participants.isNotEmpty) {
      for (final participant in participants) {
        final rect = _blockRectCanvas(participant);
        minLeft = math.min(minLeft, rect.left);
        maxRight = math.max(maxRight, rect.right);
      }
    }

    final entries = _buildSequenceMessageEntries();
    for (final entry in entries) {
      final messageLeft = math.min(
        entry.concernedLeftCanvas,
        math.min(
          entry.leftXCanvas,
          math.min(entry.startXCanvas, entry.endXCanvas),
        ),
      );
      final messageRight = math.max(
        entry.concernedRightCanvas,
        math.max(
          entry.rightXCanvas,
          math.max(entry.startXCanvas, entry.endXCanvas),
        ),
      );
      minLeft = math.min(minLeft, messageLeft);
      maxRight = math.max(
        maxRight,
        messageRight + (_sequenceFrameRightGap * zoomLevel),
      );
    }

    if (!minLeft.isFinite || !maxRight.isFinite || maxRight <= minLeft) {
      return null;
    }

    return SequenceGroupSpan(
      leftCanvas: minLeft - (20.0 * zoomLevel),
      rightCanvas: maxRight + (20.0 * zoomLevel),
    );
  }

  void _dragSequenceMessageToGlobalPosition(BlockLink link, Offset globalPos) {
    final canvasPos = _toCanvasLocal(globalPos);
    final minLaneCanvasY = _minSequenceLaneCanvasY(link);
    final laneCanvasY = math.max(canvasPos.dy, minLaneCanvasY);
    final laneModelY = (laneCanvasY - canvasOffset.dy) / zoomLevel;
    _setSequenceLinkLaneY(link, laneModelY);
  }

  List<_SequenceControlSnapshot> _captureSequenceControlSnapshotsByOrder(
    List<BlockLink> ordered,
  ) {
    if (ordered.isEmpty) {
      return const <_SequenceControlSnapshot>[];
    }

    final snapshots = <_SequenceControlSnapshot>[];
    final stack = <_SequenceOpenCapture>[];

    for (var messageIndex = 0; messageIndex < ordered.length; messageIndex++) {
      final link = ordered[messageIndex];

      for (
        var lineIndex = 0;
        lineIndex < link.sequenceBeforeLines.length;
        lineIndex++
      ) {
        final raw = link.sequenceBeforeLines[lineIndex];
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        if (RegExp(
          r'^(alt|opt|loop)\b',
          caseSensitive: false,
        ).hasMatch(trimmed)) {
          stack.add(
            _SequenceOpenCapture(
              startIndex: messageIndex,
              depth: stack.length,
              openLine: raw,
              sourceLink: link,
              sourceOpenLineIndex: lineIndex,
            ),
          );
          continue;
        }

        if (RegExp(r'^else\b', caseSensitive: false).hasMatch(trimmed) &&
            stack.isNotEmpty) {
          final current = stack.last;
          current.elseLines.add(raw);
          if (_isAltControlOpenLine(current.openLine)) {
            current.currentBranchIndex++;
          }
        }
      }

      for (final openCapture in stack) {
        openCapture.memberLinks.add(link);
        openCapture.memberBranchIndices.add(openCapture.currentBranchIndex);
      }

      for (final raw in link.sequenceAfterLines) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        if (RegExp(r'^else\b', caseSensitive: false).hasMatch(trimmed) &&
            stack.isNotEmpty) {
          final current = stack.last;
          current.elseLines.add(raw);
          if (_isAltControlOpenLine(current.openLine)) {
            current.currentBranchIndex++;
          }
          continue;
        }

        if (!RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed) ||
            stack.isEmpty) {
          continue;
        }

        final openCapture = stack.removeLast();
        snapshots.add(
          _SequenceControlSnapshot(
            startIndex: openCapture.startIndex,
            endIndex: messageIndex,
            depth: openCapture.depth,
            openLine: openCapture.openLine,
            elseLines: List<String>.from(openCapture.elseLines),
            endLine: raw,
            sourceLink: openCapture.sourceLink,
            sourceOpenLineIndex: openCapture.sourceOpenLineIndex,
            memberLinks: List<BlockLink>.from(openCapture.memberLinks),
            memberBranchIndices: List<int>.from(
              openCapture.memberBranchIndices,
            ),
          ),
        );
      }
    }

    return snapshots;
  }

  void _captureSequenceControlSnapshotsForDrag() {
    final ordered = _orderedSequenceLinks();
    _sequenceDragControlSnapshots = _captureSequenceControlSnapshotsByOrder(
      ordered,
    );
  }

  void _restoreSequenceControlSnapshotsByOrder(
    List<BlockLink> ordered,
    List<_SequenceControlSnapshot> snapshots,
  ) {
    if (ordered.isEmpty) {
      return;
    }

    final controlLinePattern = RegExp(
      r'^(alt|opt|loop|else|end)\b',
      caseSensitive: false,
    );

    for (final link in ordered) {
      link.sequenceBeforeLines.removeWhere(
        (line) => controlLinePattern.hasMatch(line.trim()),
      );
      link.sequenceAfterLines.removeWhere(
        (line) => controlLinePattern.hasMatch(line.trim()),
      );
    }

    if (snapshots.isEmpty) {
      return;
    }

    final normalized = snapshots
        .map(
          (s) => _SequenceControlSnapshot(
            startIndex: s.startIndex.clamp(0, ordered.length - 1),
            endIndex: s.endIndex.clamp(0, ordered.length - 1),
            depth: s.depth,
            openLine: s.openLine,
            elseLines: List<String>.from(s.elseLines),
            endLine: s.endLine,
            sourceLink: s.sourceLink,
            sourceOpenLineIndex: s.sourceOpenLineIndex,
            memberLinks: List<BlockLink>.from(s.memberLinks),
            memberBranchIndices: List<int>.from(s.memberBranchIndices),
          ),
        )
        .map((s) {
          final zipped = <(int index, BlockLink link, int branch)>[];
          final count = math.min(
            s.memberLinks.length,
            s.memberBranchIndices.length,
          );
          for (var i = 0; i < count; i++) {
            final link = s.memberLinks[i];
            final index = ordered.indexOf(link);
            if (index < 0) {
              continue;
            }
            zipped.add((index, link, s.memberBranchIndices[i]));
          }
          if (zipped.isEmpty) {
            return null;
          }
          zipped.sort((a, b) => a.$1.compareTo(b.$1));
          final memberIndices = zipped.map((e) => e.$1).toList(growable: false);
          final normalizedMembers = zipped
              .map((e) => e.$2)
              .toList(growable: false);
          final normalizedBranches = zipped
              .map((e) => e.$3)
              .toList(growable: false);
          final startIndex = memberIndices.first;
          final endIndex = memberIndices.last;
          return _SequenceControlSnapshot(
            startIndex: startIndex,
            endIndex: endIndex,
            depth: s.depth,
            openLine: s.openLine,
            elseLines: List<String>.from(s.elseLines),
            endLine: s.endLine,
            sourceLink: s.sourceLink,
            sourceOpenLineIndex: s.sourceOpenLineIndex,
            memberLinks: normalizedMembers,
            memberBranchIndices: normalizedBranches,
          );
        })
        .whereType<_SequenceControlSnapshot>()
        .where((s) => s.endIndex >= s.startIndex)
        .toList(growable: true);

    normalized.sort((a, b) {
      final byStart = a.startIndex.compareTo(b.startIndex);
      if (byStart != 0) {
        return byStart;
      }
      final byEnd = a.endIndex.compareTo(b.endIndex);
      if (byEnd != 0) {
        return byEnd;
      }
      return a.depth.compareTo(b.depth);
    });

    final byBeforeIndex = <int, List<(int depth, int priority, String line)>>{};
    final byElseStartIndex = <int, List<(int depth, String elseLine)>>{};
    final byEndIndex = <int, List<_SequenceControlSnapshot>>{};
    for (final snapshot in normalized) {
      byBeforeIndex
          .putIfAbsent(
            snapshot.startIndex,
            () => <(int depth, int priority, String line)>[],
          )
          .add((snapshot.depth, 1, snapshot.openLine));
      byEndIndex
          .putIfAbsent(snapshot.endIndex, () => <_SequenceControlSnapshot>[])
          .add(snapshot);

      final isAlt = _isAltControlOpenLine(snapshot.openLine);
      if (!isAlt || snapshot.elseLines.isEmpty) {
        continue;
      }
      final firstIndexByBranch = <int, int>{};
      final branchCount = math.min(
        snapshot.memberLinks.length,
        snapshot.memberBranchIndices.length,
      );
      for (var i = 0; i < branchCount; i++) {
        final branch = snapshot.memberBranchIndices[i];
        if (branch <= 0) {
          continue;
        }
        final index = ordered.indexOf(snapshot.memberLinks[i]);
        if (index < 0) {
          continue;
        }
        final previous = firstIndexByBranch[branch];
        if (previous == null || index < previous) {
          firstIndexByBranch[branch] = index;
        }
      }

      for (var branch = 1; branch <= snapshot.elseLines.length; branch++) {
        final elseStartIndex = firstIndexByBranch[branch];
        if (elseStartIndex == null) {
          continue;
        }
        byElseStartIndex
            .putIfAbsent(elseStartIndex, () => <(int depth, String elseLine)>[])
            .add((snapshot.depth, snapshot.elseLines[branch - 1]));
      }
    }

    for (final entry in byElseStartIndex.entries) {
      entry.value.sort((a, b) => a.$1.compareTo(b.$1));
      for (final elseData in entry.value) {
        byBeforeIndex
            .putIfAbsent(
              entry.key,
              () => <(int depth, int priority, String line)>[],
            )
            .add((elseData.$1, 0, elseData.$2));
      }
    }

    for (final entry in byBeforeIndex.entries) {
      entry.value.sort((a, b) {
        final byDepth = a.$1.compareTo(b.$1);
        if (byDepth != 0) {
          return byDepth;
        }
        return a.$2.compareTo(b.$2);
      });
      final link = ordered[entry.key];
      for (final beforeData in entry.value) {
        link.sequenceBeforeLines.add(beforeData.$3);
      }
    }

    for (final entry in byEndIndex.entries) {
      entry.value.sort((a, b) => b.depth.compareTo(a.depth));
      final link = ordered[entry.key];
      for (final snapshot in entry.value) {
        link.sequenceAfterLines.add(snapshot.endLine);
      }
    }

    _normalizeSequenceControlLinesForMermaid(ordered);
  }

  void _normalizeSequenceControlLinesForMermaid(List<BlockLink> ordered) {
    final openKindStack = <String>[];

    String? normalizeLine(String rawLine) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        return rawLine;
      }

      final openMatch = RegExp(
        r'^(alt|opt|loop)\b\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (openMatch != null) {
        openKindStack.add((openMatch.group(1) ?? '').toLowerCase());
        return rawLine;
      }

      final elseMatch = RegExp(
        r'^else\b\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (elseMatch != null) {
        final hasOpenAlt =
            openKindStack.isNotEmpty && openKindStack.last == 'alt';
        if (!hasOpenAlt) {
          final label = (elseMatch.group(1) ?? '').trim();
          // Converted else opens a new alt block, keep stack consistent
          // so the subsequent end remains valid.
          openKindStack.add('alt');
          return label.isEmpty ? 'alt' : 'alt $label';
        }
        return rawLine;
      }

      if (RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed)) {
        if (openKindStack.isEmpty) {
          // Orphan end: drop it to keep Mermaid structure valid.
          return null;
        }
        openKindStack.removeLast();
      }

      return rawLine;
    }

    for (final link in ordered) {
      for (var i = 0; i < link.sequenceBeforeLines.length; i++) {
        final normalized = normalizeLine(link.sequenceBeforeLines[i]);
        if (normalized == null) {
          link.sequenceBeforeLines.removeAt(i);
          i--;
          continue;
        }
        link.sequenceBeforeLines[i] = normalized;
      }
      for (var i = 0; i < link.sequenceAfterLines.length; i++) {
        final normalized = normalizeLine(link.sequenceAfterLines[i]);
        if (normalized == null) {
          link.sequenceAfterLines.removeAt(i);
          i--;
          continue;
        }
        link.sequenceAfterLines[i] = normalized;
      }
    }

    _collapseEmptyAltHeadElseBranches(ordered);
  }

  void _collapseEmptyAltHeadElseBranches(List<BlockLink> ordered) {
    final stack = <_SequenceNormalizeOpenCapture>[];
    final refsToRemove = <(BlockLink link, bool isBefore, int lineIndex)>[];

    void registerElseLine(
      _SequenceNormalizeOpenCapture capture,
      BlockLink link,
      bool isBefore,
      int lineIndex,
    ) {
      if (capture.kind != 'alt') {
        return;
      }
      capture.currentBranchIndex += 1;
      while (capture.branchMessageCounts.length <= capture.currentBranchIndex) {
        capture.branchMessageCounts.add(0);
      }
      capture.elseRefs.add((link, isBefore, lineIndex));
    }

    bool hasMessagesOnlyInElse(_SequenceNormalizeOpenCapture capture) {
      if (capture.kind != 'alt') {
        return false;
      }
      final headCount = capture.branchMessageCounts.isEmpty
          ? 0
          : capture.branchMessageCounts.first;
      final tailCount = capture.branchMessageCounts.length <= 1
          ? 0
          : capture.branchMessageCounts
                .sublist(1)
                .fold<int>(0, (sum, value) => sum + value);
      return headCount == 0 && tailCount > 0 && capture.elseRefs.isNotEmpty;
    }

    for (final link in ordered) {
      for (var i = 0; i < link.sequenceBeforeLines.length; i++) {
        final trimmed = link.sequenceBeforeLines[i].trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final openMatch = RegExp(
          r'^(alt|opt|loop)\b',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (openMatch != null) {
          final kind = (openMatch.group(1) ?? '').toLowerCase();
          stack.add(_SequenceNormalizeOpenCapture(kind));
          continue;
        }

        if (RegExp(r'^else\b', caseSensitive: false).hasMatch(trimmed) &&
            stack.isNotEmpty) {
          registerElseLine(stack.last, link, true, i);
        }
      }

      for (final capture in stack) {
        if (capture.kind != 'alt') {
          continue;
        }
        if (capture.currentBranchIndex >= 0 &&
            capture.currentBranchIndex < capture.branchMessageCounts.length) {
          capture.branchMessageCounts[capture.currentBranchIndex] += 1;
        }
      }

      for (var i = 0; i < link.sequenceAfterLines.length; i++) {
        final trimmed = link.sequenceAfterLines[i].trim();
        if (trimmed.isEmpty) {
          continue;
        }

        if (RegExp(r'^else\b', caseSensitive: false).hasMatch(trimmed) &&
            stack.isNotEmpty) {
          registerElseLine(stack.last, link, false, i);
          continue;
        }

        if (RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed) &&
            stack.isNotEmpty) {
          final closed = stack.removeLast();
          if (hasMessagesOnlyInElse(closed)) {
            refsToRemove.addAll(closed.elseRefs);
          }
        }
      }
    }

    final byLinkBefore = <BlockLink, List<int>>{};
    final byLinkAfter = <BlockLink, List<int>>{};
    for (final ref in refsToRemove) {
      if (ref.$2) {
        byLinkBefore.putIfAbsent(ref.$1, () => <int>[]).add(ref.$3);
      } else {
        byLinkAfter.putIfAbsent(ref.$1, () => <int>[]).add(ref.$3);
      }
    }

    for (final entry in byLinkBefore.entries) {
      final indices = entry.value.toSet().toList(growable: false)
        ..sort((a, b) => b.compareTo(a));
      for (final index in indices) {
        if (index < 0 || index >= entry.key.sequenceBeforeLines.length) {
          continue;
        }
        entry.key.sequenceBeforeLines.removeAt(index);
      }
    }

    for (final entry in byLinkAfter.entries) {
      final indices = entry.value.toSet().toList(growable: false)
        ..sort((a, b) => b.compareTo(a));
      for (final index in indices) {
        if (index < 0 || index >= entry.key.sequenceAfterLines.length) {
          continue;
        }
        entry.key.sequenceAfterLines.removeAt(index);
      }
    }
  }

  void _applyCanonicalSequenceLayout(
    List<Block> orderedParticipants,
    List<BlockLink> orderedLinks, {
    bool repositionParticipants = true,
  }) {
    if (repositionParticipants) {
      for (var i = 0; i < orderedParticipants.length; i++) {
        final block = orderedParticipants[i];
        block.position = Offset(
          120 + (i * _sequenceParticipantGap),
          _sequenceParticipantTop,
        );
      }
    }

    final blockById = <String, Block>{
      for (final block in orderedParticipants) block.id: block,
    };

    for (var i = 0; i < orderedLinks.length; i++) {
      final link = orderedLinks[i];
      if (blockById[link.fromBlockId] == null ||
          blockById[link.toBlockId] == null) {
        continue;
      }

      final messageY = _sequenceMessageStartY + (i * _sequenceMessageStepY);
      _setSequenceLinkLaneY(link, messageY);
    }

    _isSequenceDiagramView = true;
    _normalizeSequenceMessageGeometryAndSpacing();
  }

  void _reorderSequenceMessagesByLane({
    List<_SequenceControlSnapshot>? controlSnapshots,
    BlockLink? draggedLink,
    SequenceControlGroupInfo? dropTargetGroup,
  }) {
    final ordered = _orderedSequenceLinks();

    if (ordered.isEmpty) {
      return;
    }

    final laneByLink = <BlockLink, double>{
      for (final link in ordered) link: _sequenceLaneYModel(link),
    };

    final metricsByLink = _sequenceLayoutMetricsByOrder(ordered);
    final firstLink = ordered.first;
    final firstMetrics = metricsByLink[firstLink]!;
    final firstMinLane =
        _sequenceMessageStartY +
        (firstMetrics.depthAtMessage * _sequenceFrameNestGap) +
        (firstMetrics.elseCountBefore * _sequenceElseGap);
    if (laneByLink[firstLink]! < firstMinLane) {
      laneByLink[firstLink] = firstMinLane;
    }

    for (int i = 1; i < ordered.length; i++) {
      final previousLink = ordered[i - 1];
      final currentLink = ordered[i];
      final previousMetrics = metricsByLink[previousLink]!;
      final currentMetrics = metricsByLink[currentLink]!;
      final prevLane = laneByLink[ordered[i - 1]]!;
      final currentLane = laneByLink[currentLink]!;
      final structuralMin =
          _sequenceMessageStartY +
          (currentMetrics.depthAtMessage * _sequenceFrameNestGap) +
          (currentMetrics.elseCountBefore * _sequenceElseGap);
      final transitionGap =
          (currentMetrics.openCountBefore * _sequenceFrameNestGap) +
          (previousMetrics.endCountAfter * _sequenceFrameNestGap) +
          (previousMetrics.elseCountAfter * _sequenceElseGap) +
          (currentMetrics.elseCountBefore * _sequenceElseGap);
      final minAllowed =
          prevLane +
          _sequenceMinGapBetweenMessages(previousLink, currentLink) +
          transitionGap;
      if (currentLane < minAllowed) {
        laneByLink[currentLink] = minAllowed;
      }
      if (laneByLink[currentLink]! < structuralMin) {
        laneByLink[currentLink] = structuralMin;
      }
    }

    for (final link in ordered) {
      _setSequenceLinkLaneY(link, laneByLink[link]!);
    }

    final snapshots = controlSnapshots;
    if (snapshots != null && snapshots.isNotEmpty) {
      final adjustedSnapshots = _adjustSequenceControlSnapshotsForDrop(
        snapshots,
        draggedLink: draggedLink,
        dropTargetGroup: dropTargetGroup,
        orderedLinks: ordered,
      );
      _restoreSequenceControlSnapshotsByOrder(ordered, adjustedSnapshots);
    }
  }

  List<_SequenceControlSnapshot> _adjustSequenceControlSnapshotsForDrop(
    List<_SequenceControlSnapshot> snapshots, {
    BlockLink? draggedLink,
    SequenceControlGroupInfo? dropTargetGroup,
    List<BlockLink>? orderedLinks,
  }) {
    if (draggedLink == null) {
      return snapshots;
    }

    _SequenceControlSnapshot? targetSnapshot;
    if (dropTargetGroup != null) {
      for (final snapshot in snapshots) {
        if (identical(snapshot.sourceLink, dropTargetGroup.sourceLink) &&
            snapshot.sourceOpenLineIndex ==
                dropTargetGroup.sourceOpenLineIndex) {
          targetSnapshot = snapshot;
          break;
        }
      }
    }

    final targetChain = <_SequenceControlSnapshot>{};
    if (targetSnapshot != null) {
      for (final snapshot in snapshots) {
        final containsTarget =
            snapshot.startIndex <= targetSnapshot.startIndex &&
            snapshot.endIndex >= targetSnapshot.endIndex &&
            snapshot.depth <= targetSnapshot.depth;
        if (containsTarget) {
          targetChain.add(snapshot);
        }
      }
    }

    final movedSnapshots = snapshots
        .map((snapshot) {
          final members = List<BlockLink>.from(snapshot.memberLinks);
          final memberBranches = List<int>.from(snapshot.memberBranchIndices);
          final shouldContainDragged = targetChain.contains(snapshot);
          for (var i = members.length - 1; i >= 0; i--) {
            if (identical(members[i], draggedLink)) {
              members.removeAt(i);
              if (i < memberBranches.length) {
                memberBranches.removeAt(i);
              }
            }
          }

          final shouldUseTargetBranch =
              dropTargetGroup?.targetBranchIndex != null &&
              identical(snapshot.sourceLink, dropTargetGroup!.sourceLink) &&
              snapshot.sourceOpenLineIndex ==
                  dropTargetGroup.sourceOpenLineIndex &&
              _isAltControlOpenLine(snapshot.openLine);
          if (shouldContainDragged) {
            members.add(draggedLink);
            memberBranches.add(
              shouldUseTargetBranch
                  ? math.max(0, dropTargetGroup.targetBranchIndex!)
                  : 0,
            );
          }
          return _SequenceControlSnapshot(
            startIndex: snapshot.startIndex,
            endIndex: snapshot.endIndex,
            depth: snapshot.depth,
            openLine: snapshot.openLine,
            elseLines: List<String>.from(snapshot.elseLines),
            endLine: snapshot.endLine,
            sourceLink: snapshot.sourceLink,
            sourceOpenLineIndex: snapshot.sourceOpenLineIndex,
            memberLinks: members,
            memberBranchIndices: memberBranches,
          );
        })
        .where((snapshot) => snapshot.memberLinks.isNotEmpty)
        .where((snapshot) {
          if (orderedLinks == null) {
            return true;
          }
          final memberIndices =
              snapshot.memberLinks
                  .map(orderedLinks.indexOf)
                  .where((index) => index >= 0)
                  .toList(growable: true)
                ..sort();
          if (memberIndices.isEmpty) {
            return false;
          }
          for (var i = 1; i < memberIndices.length; i++) {
            if (memberIndices[i] != memberIndices[i - 1] + 1) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);

    final targetBranchIndex = dropTargetGroup?.targetBranchIndex;
    final branchTargetSnapshot = targetSnapshot;
    if (targetBranchIndex == null || branchTargetSnapshot == null) {
      return movedSnapshots;
    }

    return movedSnapshots
        .map((snapshot) {
          if (!identical(
                snapshot.sourceLink,
                branchTargetSnapshot.sourceLink,
              ) ||
              snapshot.sourceOpenLineIndex !=
                  branchTargetSnapshot.sourceOpenLineIndex ||
              snapshot.openLine.trim().toLowerCase().startsWith('alt') ==
                  false) {
            return snapshot;
          }

          final requiredElseCount = math.max(0, targetBranchIndex);
          final updatedElseLines = List<String>.from(snapshot.elseLines);
          while (updatedElseLines.length < requiredElseCount) {
            updatedElseLines.add('else');
          }

          return _SequenceControlSnapshot(
            startIndex: snapshot.startIndex,
            endIndex: snapshot.endIndex,
            depth: snapshot.depth,
            openLine: snapshot.openLine,
            elseLines: updatedElseLines,
            endLine: snapshot.endLine,
            sourceLink: snapshot.sourceLink,
            sourceOpenLineIndex: snapshot.sourceOpenLineIndex,
            memberLinks: List<BlockLink>.from(snapshot.memberLinks),
            memberBranchIndices: List<int>.from(snapshot.memberBranchIndices),
          );
        })
        .toList(growable: false);
  }

  void _insertSequenceMessageAtReference(
    BlockLink insertedLink,
    double referenceLaneYModel,
  ) {
    final ordered = _orderedSequenceLinks()..remove(insertedLink);

    final insertionIndex = ordered.indexWhere(
      (link) => _sequenceLaneYModel(link) >= referenceLaneYModel,
    );
    if (insertionIndex == -1) {
      ordered.add(insertedLink);
    } else {
      ordered.insert(insertionIndex, insertedLink);
    }

    if (ordered.isEmpty) {
      return;
    }

    final laneByLink = <BlockLink, double>{
      for (final link in ordered)
        link: link == insertedLink
            ? referenceLaneYModel
            : _sequenceLaneYModel(link),
    };

    for (int i = 1; i < ordered.length; i++) {
      final prevLane = laneByLink[ordered[i - 1]]!;
      final currentLane = laneByLink[ordered[i]]!;
      final minAllowed =
          prevLane + _sequenceMinGapBetweenMessages(ordered[i - 1], ordered[i]);
      if (currentLane < minAllowed) {
        laneByLink[ordered[i]] = minAllowed;
      }
    }

    for (final link in ordered) {
      _setSequenceLinkLaneY(link, laneByLink[link]!);
    }
  }
}
