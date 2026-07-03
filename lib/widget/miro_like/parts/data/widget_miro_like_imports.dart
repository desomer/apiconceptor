part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateImportMethods on _MiroLikeWidgetState {
  void _importMermaid(String text) {
    if (MermaidSequenceCodec.isSequenceDiagram(text)) {
      _importSequenceMermaid(text);
    } else {
      _importFlowchartMermaid(text);
    }
  }

  void _importFlowchartMermaid(String text) {
    final parsed = MermaidFlowchartCodec.parse(
      text,
      fallbackDirection: _mermaidLayoutDirection,
      allowedDirections: _MiroLikeWidgetState._mermaidDirections,
    );
    final layoutDirection = parsed.layoutDirection;

    final importedBlocks = <Block>[];
    for (var i = 0; i < parsed.nodeOrder.length; i++) {
      final nodeId = parsed.nodeOrder[i];
      importedBlocks.add(
        Block(
          id: nodeId,
          title: parsed.nodeTitles[nodeId] ?? nodeId,
          position: Offset(120 + (i % 4) * 240, 100 + (i ~/ 4) * 170),
          size: const Size(_minBlockWidth, _minBlockHeight),
        ),
      );
    }

    final importedLinks = <BlockLink>[];
    for (final edge in parsed.edges) {
      importedLinks.add(
        BlockLink(
          fromBlockId: edge.fromId,
          toBlockId: edge.toId,
          name: edge.label,
          sequenceArrowType: edge.arrowType,
        ),
      );
    }

    final subgraphNodeGroups = parsed.subgraphs
        .map((subgraph) => subgraph.nodeIds)
        .where((ids) => ids.length >= 2)
        .toList(growable: false);

    _runAutoLayoutOnGraph(
      importedBlocks,
      importedLinks,
      layoutDirection,
      subgraphNodeGroups: subgraphNodeGroups,
    );

    _pushUndoSnapshot();

    // ignore: invalid_use_of_protected_member
    setState(() {
      blocks
        ..clear()
        ..addAll(importedBlocks);
      links
        ..clear()
        ..addAll(importedLinks);
      selectedBlock = null;
      selectedLink = null;
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      pendingInflectionPoints.clear();
      canvasOffset = Offset.zero;
      zoomLevel = 1.0;
      _snapLeftModel = null;
      _snapTopModel = null;
      _dragFreePositionModel = null;
      _mermaidLayoutDirection = layoutDirection;
      _isSequenceDiagramView = false;
      _upsertAutoSubgraphZonesFromMermaid(parsed.subgraphs);

      for (final block in blocks) {
        if (block.isZone) {
          continue;
        }
        _ensureBlockHasSpaceForAnchors(block);
      }
      _markBoardChanged();
    });

    _fitToViewAfterNextFrame();
  }

  void _importSequenceMermaid(String text) {
    final parsed = MermaidSequenceCodec.parse(text);
    final participants = parsed.participants;
    if (participants.isEmpty) {
      throw const FormatException('Aucun participant Mermaid reconnu');
    }

    final importedBlocks = <Block>[];
    for (var i = 0; i < participants.length; i++) {
      final participant = participants[i];
      importedBlocks.add(
        Block(
          id: participant.id,
          title: participant.label,
          position: Offset(
            120 + (i * _sequenceParticipantGap),
            _sequenceParticipantTop,
          ),
          size: const Size(_minBlockWidth, _minBlockHeight),
        ),
      );
    }

    final blockById = <String, Block>{
      for (final block in importedBlocks) block.id: block,
    };

    final importedLinks = <BlockLink>[];
    for (var i = 0; i < parsed.messages.length; i++) {
      final message = parsed.messages[i];
      final fromBlock = blockById[message.fromId];
      final toBlock = blockById[message.toId];
      if (fromBlock == null || toBlock == null) {
        continue;
      }

      final messageY = _sequenceMessageStartY + (i * _sequenceMessageStepY);
      final fromCenterX = fromBlock.position.dx + (fromBlock.size.width / 2);
      final toCenterX = toBlock.position.dx + (toBlock.size.width / 2);

      final inflectionPoints = <Offset>[];
      if (message.fromId == message.toId) {
        final loopX = fromCenterX + _sequenceSelfLoopHorizontalOffset;
        final loopReturnY = messageY + _sequenceSelfLoopVerticalOffset;
        inflectionPoints
          ..add(Offset(loopX, messageY))
          ..add(Offset(loopX, loopReturnY))
          ..add(Offset(fromCenterX, loopReturnY));
      } else {
        inflectionPoints
          ..add(Offset(fromCenterX, messageY))
          ..add(Offset(toCenterX, messageY));
      }

      importedLinks.add(
        BlockLink(
            fromBlockId: message.fromId,
            toBlockId: message.toId,
            name: message.label,
            sequenceArrowType: message.arrowType,
            sequenceBeforeLines: List<String>.from(message.beforeLines),
            sequenceAfterLines: List<String>.from(message.afterLines),
            connectorType: ConnectorType.orthogonal,
            sourceAnchorUnit: const Offset(0, 1),
            targetAnchorUnit: const Offset(0, 1),
            inflectionPoints: inflectionPoints,
            autoLayoutLock: false,
          )
          ..sourceAnchorOrderKey = messageY
          ..targetAnchorOrderKey = messageY,
      );
    }

    _pushUndoSnapshot();

    // ignore: invalid_use_of_protected_member
    setState(() {
      blocks
        ..clear()
        ..addAll(importedBlocks);
      links
        ..clear()
        ..addAll(importedLinks);
      selectedBlock = null;
      selectedLink = null;
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      pendingInflectionPoints.clear();
      canvasOffset = Offset.zero;
      zoomLevel = 1.0;
      _snapLeftModel = null;
      _snapTopModel = null;
      _dragFreePositionModel = null;
      _applyCanonicalSequenceLayout(importedBlocks, importedLinks);
      _syncAutoSubgraphZones();
      _markBoardChanged();
    });

    _fitToViewAfterNextFrame();
  }

  void _importBoard(Map<String, dynamic> decoded, {bool recordHistory = true}) {
    if (recordHistory) {
      _pushUndoSnapshot();
    }
    final importedBlocks = _blocksFromJson(decoded['blocks']);
    final legacyType = _connectorTypeFromName(decoded['connectorType']);
    final importedLinks = _linksFromJson(
      decoded['links'],
      fallbackType: legacyType,
    );
    final importedIds = importedBlocks.map((b) => b.id).toSet();
    importedLinks.removeWhere(
      (l) =>
          !importedIds.contains(l.fromBlockId) ||
          !importedIds.contains(l.toBlockId),
    );
    final isSequenceDiagramView =
        decoded['diagramMode']?.toString() == 'sequence';

    // ignore: invalid_use_of_protected_member
    setState(() {
      blocks
        ..clear()
        ..addAll(importedBlocks);
      links
        ..clear()
        ..addAll(importedLinks);

      final zoom = decoded['zoomLevel'];
      if (zoom is num) {
        zoomLevel = zoom.toDouble().clamp(0.2, 4.0);
      }

      canvasOffset = _offsetFromJson(decoded['canvasOffset']);
      selectedBlock = null;
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      pendingInflectionPoints.clear();
      _isSequenceDiagramView = isSequenceDiagramView;
      if (_isSequenceDiagramView) {
        _normalizeSequenceMessageGeometryAndSpacing();
      } else {
        _syncAutoSubgraphZones();
      }
      _markBoardSaved();
    });

    _fitToViewAfterNextFrame();
  }
}
