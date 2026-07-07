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

  Size _sizeFromJson(dynamic value, {Size fallback = const Size(150, 100)}) {
    if (value is! Map) {
      return Size(
        math.max(fallback.width, _minBlockWidth),
        math.max(fallback.height, _minBlockHeight),
      );
    }
    final width = value['width'];
    final height = value['height'];
    if (width is num && height is num) {
      return Size(
        math.max(width.toDouble(), _minBlockWidth),
        math.max(height.toDouble(), _minBlockHeight),
      );
    }
    return Size(
      math.max(fallback.width, _minBlockWidth),
      math.max(fallback.height, _minBlockHeight),
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

      parsed.add(
        Block(
          id: id,
          title: title,
          kind:
              item['kind']?.toString() == BlockKind.zone.name ||
                  item['isZone'] == true
              ? BlockKind.zone
              : BlockKind.normal,
          colorKey: item['colorKey']?.toString(),
          tagColorKeys: parsedTagColorKeys,
          iconBase64: item['iconBase64']?.toString(),
          propertiesJson: item['propertiesJson']?.toString(),
          position: _offsetFromJson(item['position']),
          size: _sizeFromJson(item['size']),
          zoneTransparent: item['zoneTransparent'] == true,
          zoneBorderStyle: _zoneBorderStyleFromJsonName(
            item['zoneBorderStyle']?.toString(),
          ),
          zoneType: _zoneTypeFromJsonName(
            item['zoneType']?.toString(),
            propertiesJson: item['propertiesJson']?.toString(),
            kind:
                item['kind']?.toString() == BlockKind.zone.name ||
                    item['isZone'] == true
                ? BlockKind.zone
                : BlockKind.normal,
          ),
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
