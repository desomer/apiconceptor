part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateLinkingMethods on _MiroLikeWidgetState {
  void _startLinking(Block block) {
    if (block.isZone) {
      return;
    }
    // ignore: invalid_use_of_protected_member
    setState(() {
      linkSourceBlock = block;
      linkingFromPoint = _getBlockCenter(block);
      _sequenceLinkTargetHoverBlockId = null;
      _sequenceCreationStartCanvasY = null;
      pendingInflectionPoints.clear();
    });
  }

  Block? _findSequenceParticipantNearCanvasPosition(Offset canvasPosition) {
    final toleranceX = (20.0 * zoomLevel).clamp(12.0, 34.0);
    Block? closest;
    var bestDistance = double.infinity;

    for (final block in blocks) {
      if (block.isZone) {
        continue;
      }

      final rect = _blockRectCanvas(block);
      final minLifelineY = _sequenceLifelineStartCanvasY(block);
      if (canvasPosition.dy < minLifelineY) {
        continue;
      }

      final distanceX = (canvasPosition.dx - rect.center.dx).abs();
      if (distanceX > toleranceX || distanceX >= bestDistance) {
        continue;
      }

      bestDistance = distanceX;
      closest = block;
    }

    return closest;
  }

  bool _startSequenceLinkingFromCanvas(Offset canvasPosition) {
    if (!_isSequenceDiagramView) {
      return false;
    }

    final participant = _findSequenceParticipantNearCanvasPosition(
      canvasPosition,
    );
    if (participant == null) {
      return false;
    }

    linkSourceBlock = participant;
    linkingFromPoint = _getBlockCenter(participant);
    currentMousePosition = canvasPosition;
    _sequenceLinkTargetHoverBlockId = null;
    _sequenceCreationStartCanvasY = canvasPosition.dy;
    _dragPreviewSequenceGroup = _findSequenceControlGroupAtCanvasPosition(
      canvasPosition,
    );
    pendingInflectionPoints.clear();
    return true;
  }

  void _updateLinkPreviewFromGlobal(Offset globalPosition) {
    if (linkSourceBlock == null) {
      return;
    }
    // ignore: invalid_use_of_protected_member
    setState(() {
      final canvasPosition = _toCanvasLocal(globalPosition);
      currentMousePosition = canvasPosition;
      if (_isSequenceDiagramView) {
        final target = _findSequenceParticipantNearCanvasPosition(
          canvasPosition,
        );
        if (target != null && target.id != linkSourceBlock!.id) {
          _sequenceLinkTargetHoverBlockId = target.id;
        } else {
          _sequenceLinkTargetHoverBlockId = null;
        }
        _dragPreviewSequenceGroup = _findSequenceControlGroupAtCanvasPosition(
          canvasPosition,
        );
      }
    });
  }

  void _cancelLinking() {
    // ignore: invalid_use_of_protected_member
    setState(() {
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      _sequenceLinkTargetHoverBlockId = null;
      _sequenceCreationStartCanvasY = null;
      _dragPreviewSequenceGroup = null;
      pendingInflectionPoints.clear();
    });
  }

  void _finishLinkingAtGlobal(Offset globalPosition) {
    if (linkSourceBlock == null) {
      return;
    }

    if (_isSequenceDiagramView) {
      final canvasPosition = _toCanvasLocal(globalPosition);
      final targetParticipant = _findSequenceParticipantNearCanvasPosition(
        canvasPosition,
      );
      if (targetParticipant != null) {
        _endLinking(targetParticipant);
      }

      // Always clear preview state at the end of a sequence creation gesture.
      _cancelLinking();
      return;
    }

    final modelPosition = _toModelPosition(globalPosition);
    for (var b in blocks) {
      if (b.isZone) {
        continue;
      }
      final blockBounds = Rect.fromLTWH(
        b.position.dx,
        b.position.dy,
        b.size.width,
        b.size.height,
      );
      if (blockBounds.contains(modelPosition)) {
        final created = _endLinking(b);
        if (!created) {
          _cancelLinking();
        }
        return;
      }
    }

    _cancelLinking();
  }

  bool _endLinking(Block targetBlock) {
    final sourceBlock = linkSourceBlock;
    if (sourceBlock == null) {
      return false;
    }

    final isSelfLink = sourceBlock.id == targetBlock.id;
    if (isSelfLink && !_isSequenceDiagramView) {
      return false;
    }

    _pushUndoSnapshot();
    final sourceRect = _blockRectCanvas(sourceBlock);
    final targetRect = _blockRectCanvas(targetBlock);

    final sourceAnchorUnit = _calculateOptimalAnchorUnit(
      sourceRect,
      targetRect,
    );
    final targetAnchorUnit = _calculateOptimalAnchorUnit(
      targetRect,
      sourceRect,
    );

    // ignore: invalid_use_of_protected_member
    setState(() {
      final isSequenceMode = _isSequenceDiagramView;
      final laneYModel = isSequenceMode
          ? (() {
              final minLaneCanvasY = math.max(
                _sequenceLifelineStartCanvasY(sourceBlock),
                _sequenceLifelineStartCanvasY(targetBlock),
              );
              final fallbackLaneCanvasY = minLaneCanvasY + (32.0 * zoomLevel);
              final creationStartCanvasY = _sequenceCreationStartCanvasY;
              final previewLaneCanvasY = currentMousePosition?.dy;
              final referenceLaneCanvasY =
                  creationStartCanvasY ??
                  previewLaneCanvasY ??
                  fallbackLaneCanvasY;
              final laneCanvasY = math.max(
                referenceLaneCanvasY,
                minLaneCanvasY,
              );
              return (laneCanvasY - canvasOffset.dy) / zoomLevel;
            })()
          : null;

      links.add(
        BlockLink(
          fromBlockId: sourceBlock.id,
          toBlockId: targetBlock.id,
          name: 'Lien ${links.length + 1}',
          sequenceArrowType: isSequenceMode ? '->>' : null,
          colorKey: null,
          labelPosition: 0.75,
          labelOffset: Offset.zero,
          particleDensity: 1.0,
          particleSpeed: 1.0,
          connectorType: isSequenceMode
              ? ConnectorType.orthogonal
              : ConnectorType.bezier,
          inflectionPoints: isSequenceMode
              ? <Offset>[]
              : List<Offset>.from(pendingInflectionPoints),
          sourceAnchorUnit: isSequenceMode
              ? const Offset(0, 1)
              : sourceAnchorUnit,
          targetAnchorUnit: isSequenceMode
              ? const Offset(0, 1)
              : targetAnchorUnit,
          autoLayoutLock: false,
        ),
      );
      if (isSequenceMode && laneYModel != null) {
        _setSequenceLinkLaneY(links.last, laneYModel);
        _insertSequenceMessageAtReference(
          links.last,
          laneYModel,
          dropTargetGroup: _dragPreviewSequenceGroup,
        );
      }
      _ensureBlockHasSpaceForAnchors(sourceBlock);
      _ensureBlockHasSpaceForAnchors(targetBlock);
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      _sequenceLinkTargetHoverBlockId = null;
      _sequenceCreationStartCanvasY = null;
      _dragPreviewSequenceGroup = null;
      pendingInflectionPoints.clear();
      _markBoardChanged();
    });
    return true;
  }

  Future<void> _showCanvasCreationMenu(Offset globalPosition) async {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlayBox == null) {
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlayBox.size,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'add_block',
          child: Text('Ajouter un bloc'),
        ),
        PopupMenuItem<String>(
          value: 'add_zone',
          child: Text('Ajouter une zone'),
        ),
      ],
    );

    if (!mounted || selected == null) {
      return;
    }

    if (selected == 'add_block') {
      _addBlock(globalPosition);
      return;
    }
    if (selected == 'add_zone') {
      _addZoneBlock(globalPosition);
    }
  }
}
