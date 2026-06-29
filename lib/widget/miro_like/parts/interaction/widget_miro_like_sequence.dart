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
  });
}

class _SequenceOpenCapture {
  final int startIndex;
  final int depth;
  final String openLine;
  final BlockLink sourceLink;
  final int sourceOpenLineIndex;
  final List<String> elseLines = <String>[];

  _SequenceOpenCapture({
    required this.startIndex,
    required this.depth,
    required this.openLine,
    required this.sourceLink,
    required this.sourceOpenLineIndex,
  });
}

extension _MiroLikeWidgetStateSequenceMethods on _MiroLikeWidgetState {
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

    final selectedOrdered =
        _sequenceMessageLinks()
            .where((link) => _selectedSequenceLinks.contains(link))
            .toList(growable: true)
          ..sort(
            (a, b) => _sequenceLaneYModel(a).compareTo(_sequenceLaneYModel(b)),
          );
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
    final orderedAll = _sequenceMessageLinks()
      ..sort(
        (a, b) => _sequenceLaneYModel(a).compareTo(_sequenceLaneYModel(b)),
      );
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

    final sequenceLinks = _sequenceMessageLinks();
    for (final link in sequenceLinks) {
      final laneYModel = _sequenceLaneYModel(link);
      _setSequenceLinkLaneY(link, laneYModel);
    }

    _reorderSequenceMessagesByLane();
  }

  void _setSequenceLinkLaneY(BlockLink link, double laneYModel) {
    final fromBlock = blocks.where((b) => b.id == link.fromBlockId).firstOrNull;
    final toBlock = blocks.where((b) => b.id == link.toBlockId).firstOrNull;
    if (fromBlock == null || toBlock == null) {
      return;
    }

    final fromCenterX = fromBlock.position.dx + (fromBlock.size.width / 2);

    if (link.fromBlockId == link.toBlockId) {
      final loopX =
          fromBlock.position.dx +
          fromBlock.size.width +
          _sequenceSelfLoopHorizontalOffset;
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
    final baseGap = _sequenceMessageStepY + visualHeight;

    // Extra spacing keeps nested frame labels readable and avoids parent/child
    // title overlap when control groups open on consecutive messages.
    final openCountOnCurrent = _countSequenceOpenLines(
      current.sequenceBeforeLines,
    );
    final elseCountAroundCurrent =
        _countSequenceElseLines(current.sequenceBeforeLines) +
        _countSequenceElseLines(current.sequenceAfterLines);
    final endCountOnPrevious = _countSequenceEndLines(
      previous.sequenceAfterLines,
    );

    final openGap = openCountOnCurrent * 20.0;
    final elseGap = elseCountAroundCurrent * 12.0;
    final closeGap = endCountOnPrevious * 8.0;

    return baseGap + openGap + elseGap + closeGap;
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

    final result = <SequenceControlGroupInfo>[];
    final openStack =
        <
          (
            String kind,
            String label,
            double startY,
            BlockLink sourceLink,
            int sourceOpenLineIndex,
            List<String> branches,
          )
        >[];
    final lastY = sortedEntries.last.bottomYCanvas;

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
        final trimmed = entry.link.sequenceBeforeLines[lineIndex].trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final openMatch = RegExp(
          r'^(alt|opt|loop)\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (openMatch != null) {
          openStack.add((
            (openMatch.group(1) ?? '').toLowerCase(),
            (openMatch.group(2) ?? '').trim(),
            entry.topYCanvas,
            entry.link,
            lineIndex,
            <String>[],
          ));
          continue;
        }

        final elseMatch = RegExp(
          r'^else\b\s*(.*)$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (elseMatch != null && openStack.isNotEmpty) {
          final current = openStack.removeLast();
          if (current.$1 == 'alt') {
            current.$6.add('else@${separatorY.toStringAsFixed(2)}');
          }
          openStack.add(current);
        }
      }

      for (final rawLine in entry.link.sequenceAfterLines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        if (RegExp(r'^end\b', caseSensitive: false).hasMatch(trimmed) &&
            openStack.isNotEmpty) {
          final current = openStack.removeLast();
          result.add(
            SequenceControlGroupInfo(
              kind: current.$1,
              label: current.$2,
              startYCanvas: current.$3,
              endYCanvas: entry.bottomYCanvas,
              branchCount: current.$6.length,
              sourceLink: current.$4,
              sourceOpenLineIndex: current.$5,
            ),
          );
        }
      }
    }

    while (openStack.isNotEmpty) {
      final current = openStack.removeLast();
      result.add(
        SequenceControlGroupInfo(
          kind: current.$1,
          label: current.$2,
          startYCanvas: current.$3,
          endYCanvas: lastY,
          branchCount: current.$6.length,
          sourceLink: current.$4,
          sourceOpenLineIndex: current.$5,
        ),
      );
    }

    result.sort((a, b) {
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
    for (var i = groups.length - 1; i >= 0; i--) {
      final group = groups[i];
      final top = group.startYCanvas - 10.0;
      final bottom = group.endYCanvas + 10.0;
      if (canvasPosition.dy >= top && canvasPosition.dy <= bottom) {
        return group;
      }
    }
    return null;
  }

  SequenceGroupSpan? _buildSequenceGroupSpan() {
    final participants = blocks.where((b) => !b.isZone).toList(growable: false);
    if (participants.isEmpty) {
      return null;
    }

    var minLeft = double.infinity;
    var maxRight = -double.infinity;
    for (final participant in participants) {
      final rect = _blockRectCanvas(participant);
      minLeft = math.min(minLeft, rect.left);
      maxRight = math.max(maxRight, rect.right);
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

      for (final raw in link.sequenceBeforeLines) {
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
              sourceOpenLineIndex: link.sequenceBeforeLines.indexOf(raw),
            ),
          );
          continue;
        }

        if (RegExp(r'^else\b', caseSensitive: false).hasMatch(trimmed) &&
            stack.isNotEmpty) {
          stack.last.elseLines.add(raw);
        }
      }

      for (final raw in link.sequenceAfterLines) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        if (RegExp(r'^else\b', caseSensitive: false).hasMatch(trimmed) &&
            stack.isNotEmpty) {
          stack.last.elseLines.add(raw);
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
            memberLinks: List<BlockLink>.from(
              ordered.sublist(openCapture.startIndex, messageIndex + 1),
            ),
          ),
        );
      }
    }

    return snapshots;
  }

  void _captureSequenceControlSnapshotsForDrag() {
    final ordered = _sequenceMessageLinks()
      ..sort(
        (a, b) => _sequenceLaneYModel(a).compareTo(_sequenceLaneYModel(b)),
      );
    _sequenceDragControlSnapshots = _captureSequenceControlSnapshotsByOrder(
      ordered,
    );
  }

  void _restoreSequenceControlSnapshotsByOrder(
    List<BlockLink> ordered,
    List<_SequenceControlSnapshot> snapshots,
  ) {
    if (ordered.isEmpty || snapshots.isEmpty) {
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
          ),
        )
        .map((s) {
          final memberIndices = s.memberLinks
              .map(ordered.indexOf)
              .where((index) => index >= 0)
              .toList(growable: false);
          if (memberIndices.isEmpty) {
            return null;
          }
          final startIndex = memberIndices.reduce(math.min);
          final endIndex = memberIndices.reduce(math.max);
          return _SequenceControlSnapshot(
            startIndex: startIndex,
            endIndex: endIndex,
            depth: s.depth,
            openLine: s.openLine,
            elseLines: List<String>.from(s.elseLines),
            endLine: s.endLine,
            sourceLink: s.sourceLink,
            sourceOpenLineIndex: s.sourceOpenLineIndex,
            memberLinks: List<BlockLink>.from(s.memberLinks),
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

    final byStartIndex = <int, List<_SequenceControlSnapshot>>{};
    final byEndIndex = <int, List<_SequenceControlSnapshot>>{};
    for (final snapshot in normalized) {
      byStartIndex
          .putIfAbsent(snapshot.startIndex, () => <_SequenceControlSnapshot>[])
          .add(snapshot);
      byEndIndex
          .putIfAbsent(snapshot.endIndex, () => <_SequenceControlSnapshot>[])
          .add(snapshot);
    }

    for (final entry in byStartIndex.entries) {
      entry.value.sort((a, b) => a.depth.compareTo(b.depth));
      final link = ordered[entry.key];
      for (final snapshot in entry.value) {
        link.sequenceBeforeLines.add(snapshot.openLine);
      }
    }

    for (final entry in byEndIndex.entries) {
      entry.value.sort((a, b) => b.depth.compareTo(a.depth));
      final link = ordered[entry.key];
      for (final snapshot in entry.value) {
        link.sequenceAfterLines.addAll(snapshot.elseLines);
        link.sequenceAfterLines.add(snapshot.endLine);
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
    final ordered = _sequenceMessageLinks()
      ..sort(
        (a, b) => _sequenceLaneYModel(a).compareTo(_sequenceLaneYModel(b)),
      );

    if (ordered.isEmpty) {
      return;
    }

    final laneByLink = <BlockLink, double>{
      for (final link in ordered) link: _sequenceLaneYModel(link),
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

    final snapshots = controlSnapshots;
    if (snapshots != null && snapshots.isNotEmpty) {
      final adjustedSnapshots = _adjustSequenceControlSnapshotsForDrop(
        snapshots,
        draggedLink: draggedLink,
        dropTargetGroup: dropTargetGroup,
      );
      _restoreSequenceControlSnapshotsByOrder(ordered, adjustedSnapshots);
    }
  }

  List<_SequenceControlSnapshot> _adjustSequenceControlSnapshotsForDrop(
    List<_SequenceControlSnapshot> snapshots, {
    BlockLink? draggedLink,
    SequenceControlGroupInfo? dropTargetGroup,
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

    return snapshots
        .map((snapshot) {
          final members = List<BlockLink>.from(snapshot.memberLinks);
          final shouldContainDragged = identical(snapshot, targetSnapshot);
          members.removeWhere((link) => identical(link, draggedLink));
          if (shouldContainDragged) {
            members.add(draggedLink);
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
          );
        })
        .where((snapshot) => snapshot.memberLinks.isNotEmpty)
        .toList(growable: false);
  }

  void _insertSequenceMessageAtReference(
    BlockLink insertedLink,
    double referenceLaneYModel,
  ) {
    final ordered = _sequenceMessageLinks()
      ..remove(insertedLink)
      ..sort(
        (a, b) => _sequenceLaneYModel(a).compareTo(_sequenceLaneYModel(b)),
      );

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
