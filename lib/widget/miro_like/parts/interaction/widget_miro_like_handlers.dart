// ignore_for_file: invalid_use_of_protected_member

part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateHandlersMethods on _MiroLikeWidgetState {
  Future<void> _confirmDeleteAll() async {
    if (blocks.isEmpty && links.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer tout ?'),
          content: const Text(
            'Cette action supprimera tous les blocs, liens et selections.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer tout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    _pushUndoSnapshot();
    setState(() {
      blocks.clear();
      links.clear();
      selectedBlock = null;
      _selectedBlockIds.clear();
      selectedLink = null;
      _selectedSequenceLinks.clear();
      _selectedSequenceGroup = null;
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      pendingInflectionPoints.clear();
      _resetBlockDragSnap();
      _isBoxSelecting = false;
      _selectionStartCanvas = null;
      _selectionCurrentCanvas = null;
      _draggedZoneId = null;
      _sequenceDragControlSnapshots = null;
      _frozenSequenceFrameEntriesDuringDrag = null;
      _dragPreviewSequenceGroup = null;
      _markBoardChanged();
    });
  }

  void _addBlock(Offset position) {
    _pushUndoSnapshot();
    setState(() {
      blocks.add(
        Block(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Block ${blocks.length + 1}',
          position: (position - canvasOffset) / zoomLevel,
          size: const Size(_minBlockWidth, _minBlockHeight),
        ),
      );
      _markBoardChanged();
    });
  }

  void _addFrameBlock(Offset position) {
    _pushUndoSnapshot();
    setState(() {
      final zoneCount = blocks.where((b) => b.isZone).length;
      blocks.add(
        Block(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Zone ${zoneCount + 1}',
          kind: BlockKind.zone,
          zoneType: BlockZoneType.frame,
          position: (position - canvasOffset) / zoomLevel,
          size: const Size(420, 280),
        ),
      );
      _markBoardChanged();
    });
  }

  void _deleteBlock(Block block) {
    _pushUndoSnapshot();
    setState(() {
      blocks.remove(block);
      links.removeWhere(
        (link) => link.fromBlockId == block.id || link.toBlockId == block.id,
      );
      _syncAutoSubgraphZones();
      selectedBlock = null;
      if (selectedLink != null && !links.contains(selectedLink)) {
        selectedLink = null;
      }
      _markBoardChanged();
    });
  }

  void _deleteLink(BlockLink link) {
    _pushUndoSnapshot();
    setState(() {
      linkManager.deleteLink(links, link);
      _selectedSequenceLinks.remove(link);
      if (selectedLink == link) {
        selectedLink = null;
      }
      if (_isSequenceDiagramView) {
        _reflowSequenceLayoutAfterMutation();
      }
      _markBoardChanged();
    });
  }

  void _deleteCurrentSelection() {
    if (_selectedSequenceGroup != null) {
      _deleteSequenceGroup(_selectedSequenceGroup!);
      return;
    }
    if (_selectedSequenceLinks.isNotEmpty) {
      _deleteSelectedSequenceMessages();
      return;
    }
    if (selectedLink != null) {
      _deleteLink(selectedLink!);
      return;
    }
    if (selectedBlock != null) {
      _deleteBlock(selectedBlock!);
    }
  }

  void _reverseLink(BlockLink link) {
    _pushUndoSnapshot();
    setState(() {
      linkManager.reverseLink(links, link);
      _markBoardChanged();
    });
  }

  void _handleBlockTitleChanged(String blockId, String newTitle) {
    _pushUndoSnapshotForGranularEdit('block-title:$blockId');
    setState(() {
      final blockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        final normalizedTitle = _normalizeBlockTitleLineBreaks(newTitle);
        blocks[blockIndex].title = normalizedTitle;
        final block = blocks[blockIndex];
        final subgraphDescriptor = block.isZone
            ? _autoSubgraphDescriptorFromZone(block)
            : null;
        if (subgraphDescriptor != null) {
          _setAutoSubgraphDescriptor(
            zone: block,
            id: subgraphDescriptor.id,
            title: normalizedTitle,
            nodeIds: subgraphDescriptor.nodeIds,
          );
        }
        _markBoardChanged();
      }
    });
  }

  void _handleBlockColorChanged(Block block, String? colorKey) {
    _pushUndoSnapshot();
    setState(() {
      block.colorKey = colorKey;
      _markBoardChanged();
    });
  }

  void _handleBlockNodeShapeChanged(Block block, BlockNodeShape nodeShape) {
    if (block.isZone) {
      return;
    }
    _pushUndoSnapshot();
    setState(() {
      block.nodeShape = nodeShape;
      _markBoardChanged();
    });
  }

  void _reorderZonesOnly(Block zone, {required bool bringToFront}) {
    if (!zone.isZone) {
      return;
    }

    _pushUndoSnapshot();
    setState(() {
      final zones = blocks.where((b) => b.isZone).toList(growable: true);
      final normals = blocks.where((b) => !b.isZone).toList(growable: false);
      final index = zones.indexWhere((z) => z.id == zone.id);
      if (index == -1 || zones.length <= 1) {
        return;
      }

      final moving = zones.removeAt(index);
      if (bringToFront) {
        zones.add(moving);
      } else {
        zones.insert(0, moving);
      }

      blocks
        ..clear()
        ..addAll(zones)
        ..addAll(normals);
      _markBoardChanged();
    });
  }

  void _handleZoneBringToFront(Block zone) {
    _reorderZonesOnly(zone, bringToFront: true);
  }

  void _handleZoneSendToBack(Block zone) {
    _reorderZonesOnly(zone, bringToFront: false);
  }

  void _handleZoneTransparencyChanged(Block zone, bool transparent) {
    if (!zone.isZone) {
      return;
    }
    _pushUndoSnapshot();
    setState(() {
      zone.zoneTransparent = transparent;
      _markBoardChanged();
    });
  }

  void _handleZoneBorderStyleChanged(Block zone, ZoneBorderStyle style) {
    if (!zone.isZone) {
      return;
    }
    _pushUndoSnapshot();
    setState(() {
      zone.zoneBorderStyle = style;
      _markBoardChanged();
    });
  }

  void _handleBlockTagsChanged(Block block, List<String> tagColorKeys) {
    _pushUndoSnapshot();
    setState(() {
      block.tagColorKeys
        ..clear()
        ..addAll(
          tagColorKeys.where((key) => kBlockTagColorMap.containsKey(key)),
        );
      _markBoardChanged();
    });
  }

  void _handleBlockIconBase64Changed(Block block, String value) {
    _pushUndoSnapshot();
    setState(() {
      final trimmed = value.trim();
      block.iconBase64 = trimmed.isEmpty ? null : trimmed;
      _normalizeBlockIconStorage(block);
      _markBoardChanged();
    });
  }

  String? _iconBase64FromPropertiesJson(String? rawJson) {
    final raw = rawJson?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final dynamicIcon = decoded['iconBase64'];
      if (dynamicIcon == null) {
        return null;
      }
      final iconBase64 = dynamicIcon.toString().trim();
      return iconBase64.isEmpty ? null : iconBase64;
    } catch (_) {
      return null;
    }
  }

  void _normalizeBlockIconStorage(Block block) {
    final iconFromJson = _iconBase64FromPropertiesJson(block.propertiesJson);
    if (iconFromJson != null) {
      // Avoid duplicated storage: JSON becomes source of truth when present.
      block.iconBase64 = null;
    }
  }

  void _handleBlockPropertiesJsonChanged(Block block, String rawJson) {
    _pushUndoSnapshot();
    setState(() {
      final trimmed = rawJson.trim();
      if (trimmed.isEmpty) {
        block.propertiesJson = null;
        _markBoardChanged();
        return;
      }

      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      block.propertiesJson = trimmed;

      final title = decoded['title'];
      if (title is String) {
        block.title = _normalizeBlockTitleLineBreaks(title);
      }

      if (decoded.containsKey('colorKey')) {
        final dynamicColor = decoded['colorKey'];
        if (dynamicColor == null) {
          block.colorKey = null;
        } else {
          final colorKey = dynamicColor.toString();
          if (kBlockColorMap.containsKey(colorKey)) {
            block.colorKey = colorKey;
          }
        }
      }

      final dynamicTags = decoded['tagColorKeys'];
      if (dynamicTags is List) {
        block.tagColorKeys
          ..clear()
          ..addAll(
            dynamicTags
                .map((e) => e?.toString() ?? '')
                .where((key) => kBlockTagColorMap.containsKey(key)),
          );
      }

      if (decoded.containsKey('iconBase64')) {
        final dynamicIcon = decoded['iconBase64'];
        if (dynamicIcon == null) {
          block.iconBase64 = null;
        } else {
          final iconBase64 = dynamicIcon.toString().trim();
          block.iconBase64 = iconBase64.isEmpty ? null : iconBase64;
        }
      }

      final sizeRaw = decoded['size'];
      if (sizeRaw is Map) {
        block.size = _sizeFromJson(sizeRaw, fallback: block.size);
      }

      _normalizeBlockIconStorage(block);
      _markBoardChanged();
    });
  }

  void _handleLinkNameChanged(BlockLink link, String newName) {
    _pushUndoSnapshotForGranularEdit(
      'link-name:${link.fromBlockId}->${link.toBlockId}',
    );
    setState(() {
      link.name = newName;
      _markBoardChanged();
    });
  }

  void _handleLinkColorChanged(BlockLink link, String? colorKey) {
    _pushUndoSnapshot();
    setState(() {
      link.colorKey = colorKey;
      _markBoardChanged();
    });
  }

  void _handleLinkLabelIconChanged(BlockLink link, String? iconKey) {
    _pushUndoSnapshot();
    setState(() {
      link.labelIconKey = iconKey;
      _markBoardChanged();
    });
  }

  void _handleLinkParticleDensityChanged(BlockLink link, double value) {
    _pushUndoSnapshotForGranularEdit(
      'link-density:${link.fromBlockId}->${link.toBlockId}',
    );
    setState(() {
      link.particleDensity = value.clamp(0.2, 3.0);
      _markBoardChanged();
    });
  }

  void _handleLinkParticleSpeedChanged(BlockLink link, double value) {
    _pushUndoSnapshotForGranularEdit(
      'link-speed:${link.fromBlockId}->${link.toBlockId}',
    );
    setState(() {
      link.particleSpeed = value.clamp(0.2, 3.0);
      _markBoardChanged();
    });
  }

  void _handleLinkLabelPositionChanged(BlockLink link, double value) {
    _pushUndoSnapshotForGranularEdit(
      'link-label-position:${link.fromBlockId}->${link.toBlockId}',
    );
    setState(() {
      link.labelPosition = value;
      _markBoardChanged();
    });
  }

  void _handleLinkLabelOffsetChanged(BlockLink link, Offset offset) {
    _pushUndoSnapshotForGranularEdit(
      'link-label-offset:${link.fromBlockId}->${link.toBlockId}',
    );
    setState(() {
      link.labelOffset = offset;
      _markBoardChanged();
    });
  }

  void _handleConnectorTypeChanged(
    BlockLink link,
    ConnectorType connectorType,
  ) {
    _pushUndoSnapshot();
    setState(() {
      link.connectorType = connectorType;
      _markBoardChanged();
    });
  }

  void _handleLinkAutoLayoutLockChanged(BlockLink link, bool value) {
    _pushUndoSnapshot();
    setState(() {
      link.autoLayoutLock = value;
      _markBoardChanged();
    });
  }

  void _handleLinkSequenceArrowTypeChanged(BlockLink link, String? value) {
    _pushUndoSnapshot();
    setState(() {
      final normalized = (value ?? '').trim();
      link.sequenceArrowType = normalized.isEmpty ? null : normalized;
      _markBoardChanged();
    });
  }

  void _handleSequenceGroupChanged(
    SequenceControlGroupInfo group,
    String kind,
    String label,
  ) {
    final targetBranchIndex = group.targetBranchIndex;
    if (group.kind == 'alt' &&
        targetBranchIndex != null &&
        targetBranchIndex > 0) {
      final elseIndex = targetBranchIndex - 1;
      final newElseLine = label.trim().isEmpty
          ? 'else'
          : 'else ${label.trim()}';
      final targetElse = _findSequenceGroupElseLine(group, elseIndex);
      if (targetElse == null) {
        return;
      }
      final elseLink = targetElse.$1;
      final elseLineIndex = targetElse.$2;
      if (elseLineIndex < 0 ||
          elseLineIndex >= elseLink.sequenceBeforeLines.length) {
        return;
      }
      if (elseLink.sequenceBeforeLines[elseLineIndex].trim() == newElseLine) {
        return;
      }

      _pushUndoSnapshot();
      setState(() {
        elseLink.sequenceBeforeLines[elseLineIndex] = newElseLine;
        final updatedBranchLabels = List<String>.from(group.branchLabels);
        if (elseIndex >= 0 && elseIndex < updatedBranchLabels.length) {
          updatedBranchLabels[elseIndex] = label.trim();
        }
        _selectedSequenceGroup = SequenceControlGroupInfo(
          kind: group.kind,
          label: newElseLine.substring(4).trim(),
          startYCanvas: group.startYCanvas,
          endYCanvas: group.endYCanvas,
          branchCount: group.branchCount,
          branchSeparatorYCanvas: group.branchSeparatorYCanvas,
          branchLabels: updatedBranchLabels,
          targetBranchIndex: group.targetBranchIndex,
          sourceLink: group.sourceLink,
          sourceOpenLineIndex: group.sourceOpenLineIndex,
        );
        _reflowSequenceLayoutAfterMutation();
        _markBoardChanged();
      });
      return;
    }

    final normalizedKind = kind.trim().toLowerCase();
    if (normalizedKind != 'alt' &&
        normalizedKind != 'opt' &&
        normalizedKind != 'loop') {
      return;
    }

    final normalizedLabel = label.trim();
    final newOpenLine = normalizedLabel.isEmpty
        ? normalizedKind
        : '$normalizedKind $normalizedLabel';

    final lineIndex = group.sourceOpenLineIndex;
    final beforeLines = group.sourceLink.sequenceBeforeLines;
    if (lineIndex < 0 || lineIndex >= beforeLines.length) {
      return;
    }

    if (beforeLines[lineIndex].trim() == newOpenLine) {
      return;
    }

    _pushUndoSnapshot();
    setState(() {
      beforeLines[lineIndex] = newOpenLine;
      _selectedSequenceGroup = group.copyWith(
        kind: normalizedKind,
        label: normalizedLabel,
      );
      _reflowSequenceLayoutAfterMutation();
      _markBoardChanged();
    });
  }

  void _showBlockInfoDialog(Block block) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Info bloc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nom: ${block.title}'),
              const SizedBox(height: 6),
              Text('ID: ${block.id}'),
              const SizedBox(height: 6),
              Text(
                'Couleur: ${block.colorKey ?? '"'
                        "'Par défaut'"
                        '"'}',
              ),
              const SizedBox(height: 6),
              Text(
                'Position: ${block.position.dx.toStringAsFixed(1)}, ${block.position.dy.toStringAsFixed(1)}',
              ),
              const SizedBox(height: 6),
              Text(
                'Taille: ${block.size.width.toStringAsFixed(1)} x ${block.size.height.toStringAsFixed(1)}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  String _normalizeBlockTitleLineBreaks(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('/n', '\n');
  }
}
