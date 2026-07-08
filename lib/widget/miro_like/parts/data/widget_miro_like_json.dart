part of '../../widget_miro_like.dart';

extension _MiroLikeWidgetStateJsonMethods on _MiroLikeWidgetState {
  Map<String, dynamic> _offsetToJson(Offset offset) {
    return {'dx': offset.dx, 'dy': offset.dy};
  }

  Offset _offsetFromJson(dynamic value, {Offset fallback = Offset.zero}) {
    if (value is! Map) {
      return fallback;
    }
    final dx = value['dx'];
    final dy = value['dy'];
    if (dx is num && dy is num) {
      return Offset(dx.toDouble(), dy.toDouble());
    }
    return fallback;
  }

  Map<String, dynamic> _sizeToJson(Size size) {
    return {'width': size.width, 'height': size.height};
  }

  Size _sizeFromJson(
    dynamic value, {
    Size fallback = const Size(150, 100),
    double minWidth = _minBlockWidth,
    double minHeight = _minBlockHeight,
  }) {
    if (value is! Map) {
      return Size(
        math.max(fallback.width, minWidth),
        math.max(fallback.height, minHeight),
      );
    }
    final width = value['width'];
    final height = value['height'];
    if (width is num && height is num) {
      return Size(
        math.max(width.toDouble(), minWidth),
        math.max(height.toDouble(), minHeight),
      );
    }
    return Size(
      math.max(fallback.width, minWidth),
      math.max(fallback.height, minHeight),
    );
  }

  Map<String, dynamic> _blockToJson(Block block) {
    return {
      'id': block.id,
      'title': block.title,
      'kind': block.kind.name,
      'colorKey': block.colorKey,
      'tagColorKeys': block.tagColorKeys,
      'iconBase64': block.iconBase64,
      'propertiesJson': block.propertiesJson,
      'position': _offsetToJson(block.position),
      'size': _sizeToJson(block.size),
      'zoneTransparent': block.zoneTransparent,
      'zoneBorderStyle': block.zoneBorderStyle.name,
      'zoneType': block.zoneType.name,
      'nodeShape': block.nodeShape.name,
    };
  }

  Map<String, dynamic> _linkToJson(BlockLink link) {
    return {
      'id': link.id,
      'fromBlockId': link.fromBlockId,
      'toBlockId': link.toBlockId,
      'name': link.name,
      'sequenceArrowType': link.sequenceArrowType,
      'sequenceBeforeLines': link.sequenceBeforeLines,
      'sequenceAfterLines': link.sequenceAfterLines,
      'colorKey': link.colorKey,
      'labelIconKey': link.labelIconKey,
      'tagColorKeys': link.tagColorKeys,
      'particleDensity': link.particleDensity,
      'particleSpeed': link.particleSpeed,
      'labelPosition': link.labelPosition,
      'labelOffset': _offsetToJson(link.labelOffset),
      'connectorType': link.connectorType.name,
      'inflectionPoints': link.inflectionPoints.map(_offsetToJson).toList(),
      'sourceAnchorUnit': link.sourceAnchorUnit == null
          ? null
          : _offsetToJson(link.sourceAnchorUnit!),
      'targetAnchorUnit': link.targetAnchorUnit == null
          ? null
          : _offsetToJson(link.targetAnchorUnit!),
      'autoLayoutLock': link.autoLayoutLock,
      'webLinksJson': link.webLinksJson,
      'sourceAnchorOrderKey': link.sourceAnchorOrderKey,
      'targetAnchorOrderKey': link.targetAnchorOrderKey,
    };
  }

  Map<String, dynamic> _boardToJson() {
    return {
      'version': 1,
      'diagramMode': _isSequenceDiagramView ? 'sequence' : 'flowchart',
      'zoomLevel': zoomLevel,
      'canvasOffset': _offsetToJson(canvasOffset),
      'blocks': blocks.map(_blockToJson).toList(),
      'links': links.map(_linkToJson).toList(),
    };
  }

  Future<void> _copySelectedBlocksToClipboard() async {
    final selectedIds = _effectiveSelectedBlockIds();
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun bloc selectionne a copier.')),
      );
      return;
    }

    final selectedBlocks = blocks
        .where((block) => selectedIds.contains(block.id))
        .toList(growable: false);
    if (selectedBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun bloc selectionne a copier.')),
      );
      return;
    }

    double originX = selectedBlocks.first.position.dx;
    double originY = selectedBlocks.first.position.dy;
    for (final block in selectedBlocks.skip(1)) {
      if (block.position.dx < originX) {
        originX = block.position.dx;
      }
      if (block.position.dy < originY) {
        originY = block.position.dy;
      }
    }
    final origin = Offset(originX, originY);

    final selectedLinks = links
        .where(
          (link) =>
              selectedIds.contains(link.fromBlockId) &&
              selectedIds.contains(link.toBlockId),
        )
        .toList(growable: false);

    final selectionJson = {
      'version': 1,
      'type': 'miro-like-selection',
      'diagramMode': _isSequenceDiagramView ? 'sequence' : 'flowchart',
      'blocks': selectedBlocks
          .map((block) {
            final json = Map<String, dynamic>.from(_blockToJson(block));
            json['position'] = _offsetToJson(block.position - origin);
            return json;
          })
          .toList(growable: false),
      'links': selectedLinks
          .map((link) {
            final json = Map<String, dynamic>.from(_linkToJson(link));
            json['inflectionPoints'] = link.inflectionPoints
                .map((point) => _offsetToJson(point - origin))
                .toList(growable: false);
            return json;
          })
          .toList(growable: false),
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(selectionJson);
    await Clipboard.setData(ClipboardData(text: jsonText));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selectedBlocks.length} bloc(s) et ${selectedLinks.length} lien(s) copies dans le presse-papiers.',
        ),
      ),
    );
  }

  Offset? _clipboardPasteAnchorModel() {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return null;
    }

    final canvasPosition =
        currentMousePosition ?? renderBox.size.center(Offset.zero);
    return Offset(
      (canvasPosition.dx - canvasOffset.dx) / zoomLevel,
      (canvasPosition.dy - canvasOffset.dy) / zoomLevel,
    );
  }

  Block _duplicateClipboardBlock(
    Block source,
    Offset pasteOriginModel,
    int index,
  ) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return Block(
      id: 'block_${stamp}_$index',
      title: source.title,
      kind: source.kind,
      colorKey: source.colorKey,
      tagColorKeys: List<String>.from(source.tagColorKeys),
      iconBase64: source.iconBase64,
      propertiesJson: source.propertiesJson,
      position: pasteOriginModel + source.position,
      size: source.size,
      zoneTransparent: source.zoneTransparent,
      zoneBorderStyle: source.zoneBorderStyle,
      zoneType: source.zoneType,
      nodeShape: source.nodeShape,
    );
  }

  BlockLink _duplicateClipboardLink(
    BlockLink source,
    Map<String, String> idMapping,
    Offset pasteOriginModel,
  ) {
    final duplicated = BlockLink(
      fromBlockId: idMapping[source.fromBlockId] ?? source.fromBlockId,
      toBlockId: idMapping[source.toBlockId] ?? source.toBlockId,
      name: source.name,
      sequenceArrowType: source.sequenceArrowType,
      sequenceBeforeLines: List<String>.from(source.sequenceBeforeLines),
      sequenceAfterLines: List<String>.from(source.sequenceAfterLines),
      colorKey: source.colorKey,
      labelIconKey: source.labelIconKey,
      tagColorKeys: List<String>.from(source.tagColorKeys),
      particleDensity: source.particleDensity,
      particleSpeed: source.particleSpeed,
      labelPosition: source.labelPosition,
      labelOffset: source.labelOffset,
      connectorType: source.connectorType,
      inflectionPoints: source.inflectionPoints
          .map((point) => point + pasteOriginModel)
          .toList(growable: false),
      sourceAnchorUnit: source.sourceAnchorUnit,
      targetAnchorUnit: source.targetAnchorUnit,
      autoLayoutLock: source.autoLayoutLock,
      webLinksJson: source.webLinksJson,
    );
    duplicated.isSourceAnchorLocked = source.isSourceAnchorLocked;
    duplicated.isTargetAnchorLocked = source.isTargetAnchorLocked;
    duplicated.sourceAnchorOrderKey = source.sourceAnchorOrderKey;
    duplicated.targetAnchorOrderKey = source.targetAnchorOrderKey;
    return duplicated;
  }

  Future<void> _pasteSelectionFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text?.trim();
    if (clipboardText == null || clipboardText.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le presse-papiers est vide.')),
      );
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(clipboardText);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le presse-papiers ne contient pas un JSON valide.'),
        ),
      );
      return;
    }

    if (decoded is! Map ||
        decoded['type']?.toString() != 'miro-like-selection') {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le presse-papiers ne contient pas une selection Miro valide.',
          ),
        ),
      );
      return;
    }

    final pastedBlocks = _blocksFromJson(decoded['blocks']);
    if (pastedBlocks.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun bloc a coller dans le presse-papiers.'),
        ),
      );
      return;
    }

    final pastedBlockIds = pastedBlocks.map((block) => block.id).toSet();
    final pastedLinks = _linksFromJson(decoded['links'])
      ..removeWhere(
        (link) =>
            !pastedBlockIds.contains(link.fromBlockId) ||
            !pastedBlockIds.contains(link.toBlockId),
      );

    final pasteOriginModel = _clipboardPasteAnchorModel();
    if (pasteOriginModel == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvas indisponible pour le collage.')),
      );
      return;
    }

    _pushUndoSnapshot();

    // ignore: invalid_use_of_protected_member
    this.setState(() {
      final duplicatedBlocks = <Block>[];
      final idMapping = <String, String>{};
      for (var i = 0; i < pastedBlocks.length; i++) {
        final source = pastedBlocks[i];
        final duplicated = _duplicateClipboardBlock(
          source,
          pasteOriginModel,
          i,
        );
        duplicatedBlocks.add(duplicated);
        idMapping[source.id] = duplicated.id;
      }

      final duplicatedLinks = pastedLinks
          .map(
            (link) =>
                _duplicateClipboardLink(link, idMapping, pasteOriginModel),
          )
          .toList(growable: false);

      blocks.addAll(duplicatedBlocks);
      links.addAll(duplicatedLinks);

      selectedBlock = duplicatedBlocks.length == 1
          ? duplicatedBlocks.first
          : null;
      _selectedBlockIds
        ..clear()
        ..addAll(duplicatedBlocks.map((block) => block.id));
      selectedLink = duplicatedLinks.length == 1 ? duplicatedLinks.first : null;
      _selectedSequenceLinks
        ..clear()
        ..addAll(duplicatedLinks);
      _selectedSequenceGroup = null;

      for (final block in duplicatedBlocks) {
        if (!block.isZone) {
          _ensureBlockHasSpaceForAnchors(block);
        }
      }
      if (_isSequenceDiagramView) {
        _normalizeSequenceMessageGeometryAndSpacing();
      } else {
        _syncAutoSubgraphZones();
      }
      _markBoardChanged();
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${pastedBlocks.length} bloc(s) et ${pastedLinks.length} lien(s) colles.',
        ),
      ),
    );
  }

  String _generateBoardJson() {
    return const JsonEncoder.withIndent('  ').convert(_boardToJson());
  }

  ConnectorType _connectorTypeFromName(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw == ConnectorType.orthogonal.name) {
      return ConnectorType.orthogonal;
    }
    return ConnectorType.bezier;
  }

  List<Block> _blocksFromJson(dynamic value) {
    if (value is! List) {
      return [];
    }

    final parsed = <Block>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }

      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }

      final title = _normalizeBlockTitleLineBreaks(
        item['title']?.toString() ?? 'Block',
      );
      final parsedTagColorKeys = <String>[];
      final rawTagColorKeys = item['tagColorKeys'];
      if (rawTagColorKeys is List) {
        for (final key in rawTagColorKeys) {
          final keyString = key?.toString() ?? '';
          if (kBlockTagColorMap.containsKey(keyString)) {
            parsedTagColorKeys.add(keyString);
          }
        }
      }

      final parsedKind =
          item['kind']?.toString() == BlockKind.zone.name ||
              item['isZone'] == true
          ? BlockKind.zone
          : BlockKind.normal;
      final parsedZoneType = _zoneTypeFromJsonName(
        item['zoneType']?.toString(),
        propertiesJson: item['propertiesJson']?.toString(),
        kind: parsedKind,
      );

      parsed.add(
        Block(
          id: id,
          title: title,
          kind: parsedKind,
          colorKey: item['colorKey']?.toString(),
          tagColorKeys: parsedTagColorKeys,
          iconBase64: item['iconBase64']?.toString(),
          propertiesJson: item['propertiesJson']?.toString(),
          position: _offsetFromJson(item['position']),
          size: _sizeFromJson(
            item['size'],
            minWidth: parsedKind == BlockKind.zone
                ? _minZoneWidth
                : _minBlockWidth,
            minHeight: parsedKind == BlockKind.zone
                ? _minZoneHeight
                : _minBlockHeight,
          ),
          zoneTransparent: item['zoneTransparent'] == true,
          zoneBorderStyle: _zoneBorderStyleFromJsonName(
            item['zoneBorderStyle']?.toString(),
          ),
          zoneType: parsedZoneType,
          nodeShape: _blockNodeShapeFromJsonName(item['nodeShape']?.toString()),
        ),
      );
      final importedBlock = parsed.last;
      _normalizeBlockIconStorage(importedBlock);
    }
    return parsed;
  }

  List<BlockLink> _linksFromJson(
    dynamic value, {
    ConnectorType fallbackType = ConnectorType.bezier,
  }) {
    if (value is! List) {
      return [];
    }

    final parsed = <BlockLink>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }

      final fromId = item['fromBlockId']?.toString();
      final toId = item['toBlockId']?.toString();
      if (fromId == null || fromId.isEmpty || toId == null || toId.isEmpty) {
        continue;
      }

      final inflectionRaw = item['inflectionPoints'];
      final inflectionPoints = <Offset>[];
      if (inflectionRaw is List) {
        for (final p in inflectionRaw) {
          inflectionPoints.add(_offsetFromJson(p));
        }
      }

      final sequenceBeforeLines = <String>[];
      final sequenceBeforeRaw = item['sequenceBeforeLines'];
      if (sequenceBeforeRaw is List) {
        for (final raw in sequenceBeforeRaw) {
          final text = raw?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            sequenceBeforeLines.add(text);
          }
        }
      }

      final sequenceAfterLines = <String>[];
      final sequenceAfterRaw = item['sequenceAfterLines'];
      if (sequenceAfterRaw is List) {
        for (final raw in sequenceAfterRaw) {
          final text = raw?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            sequenceAfterLines.add(text);
          }
        }
      }

      final parsedTagColorKeys = <String>[];
      final rawTagColorKeys = item['tagColorKeys'];
      if (rawTagColorKeys is List) {
        for (final key in rawTagColorKeys) {
          final keyString = key?.toString() ?? '';
          if (kBlockTagColorMap.containsKey(keyString)) {
            parsedTagColorKeys.add(keyString);
          }
        }
      }

      parsed.add(
        BlockLink(
          id: item['id']?.toString(),
          fromBlockId: fromId,
          toBlockId: toId,
          name: item['name']?.toString() ?? '',
          sequenceArrowType: item['sequenceArrowType']?.toString(),
          sequenceBeforeLines: sequenceBeforeLines,
          sequenceAfterLines: sequenceAfterLines,
          colorKey: item['colorKey']?.toString(),
          labelIconKey: item['labelIconKey']?.toString(),
          tagColorKeys: parsedTagColorKeys,
          particleDensity: item['particleDensity'] is num
              ? (item['particleDensity'] as num).toDouble().clamp(0.2, 3.0)
              : 1.0,
          particleSpeed: item['particleSpeed'] is num
              ? (item['particleSpeed'] as num).toDouble().clamp(0.2, 3.0)
              : 1.0,
          labelPosition: item['labelPosition'] is num
              ? (item['labelPosition'] as num).toDouble().clamp(0.0, 1.0)
              : 0.75,
          labelOffset: item['labelOffset'] == null
              ? Offset.zero
              : _offsetFromJson(item['labelOffset']),
          connectorType: _connectorTypeFromName(item['connectorType']),
          inflectionPoints: inflectionPoints,
          sourceAnchorUnit: item['sourceAnchorUnit'] == null
              ? null
              : _offsetFromJson(item['sourceAnchorUnit']),
          targetAnchorUnit: item['targetAnchorUnit'] == null
              ? null
              : _offsetFromJson(item['targetAnchorUnit']),
          autoLayoutLock: item['autoLayoutLock'] == true,
          webLinksJson: item['webLinksJson']?.toString(),
        ),
      );
      final sourceOrderKey = item['sourceAnchorOrderKey'];
      if (sourceOrderKey is num) {
        parsed.last.sourceAnchorOrderKey = sourceOrderKey.toDouble();
      }
      final targetOrderKey = item['targetAnchorOrderKey'];
      if (targetOrderKey is num) {
        parsed.last.targetAnchorOrderKey = targetOrderKey.toDouble();
      }
      if (item['connectorType'] == null) {
        parsed.last.connectorType = fallbackType;
      }
    }
    return parsed;
  }

  ZoneBorderStyle _zoneBorderStyleFromJsonName(String? raw) {
    switch (raw) {
      case 'dashed1_2':
        return ZoneBorderStyle.dashed1_2;
      case 'dashed2_2':
        return ZoneBorderStyle.dashed2_2;
      case 'dashed2_1':
        return ZoneBorderStyle.dashed2_1;
      case 'plain':
      default:
        return ZoneBorderStyle.plain;
    }
  }

  BlockZoneType _zoneTypeFromJsonName(
    String? raw, {
    required String? propertiesJson,
    required BlockKind kind,
  }) {
    if (raw == BlockZoneType.sticky.name) {
      return BlockZoneType.sticky;
    }
    if (raw == BlockZoneType.subgraph.name) {
      return BlockZoneType.subgraph;
    }
    if (raw == BlockZoneType.frame.name) {
      return BlockZoneType.frame;
    }

    if (kind == BlockKind.zone &&
        (propertiesJson ?? '').contains('"autoSubgraph"')) {
      return BlockZoneType.subgraph;
    }
    return BlockZoneType.frame;
  }

  BlockNodeShape _blockNodeShapeFromJsonName(String? raw) {
    switch (raw) {
      case 'roundedRectangle':
        return BlockNodeShape.roundedRectangle;
      case 'stadium':
        return BlockNodeShape.stadium;
      case 'subroutine':
        return BlockNodeShape.subroutine;
      case 'circle':
        return BlockNodeShape.circle;
      case 'doubleCircle':
        return BlockNodeShape.doubleCircle;
      case 'database':
        return BlockNodeShape.database;
      case 'horizontalTube':
        return BlockNodeShape.horizontalTube;
      case 'hexagon':
        return BlockNodeShape.hexagon;
      case 'parallelogram':
        return BlockNodeShape.parallelogram;
      case 'parallelogramInverted':
        return BlockNodeShape.parallelogramInverted;
      case 'trapezoid':
        return BlockNodeShape.trapezoid;
      case 'trapezoidInverted':
        return BlockNodeShape.trapezoidInverted;
      case 'person':
        return BlockNodeShape.person;
      case 'rectangle':
      default:
        return BlockNodeShape.rectangle;
    }
  }
}
