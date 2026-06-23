import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:jsonschema/widget/miro_like/miro_canvas_painter.dart';
import 'package:jsonschema/widget/miro_like/connector_path_utils.dart';
import 'package:jsonschema/widget/miro_like/properties_panel.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'link_manager.dart';
import 'link_model.dart';
import 'block_model.dart';
import 'import_export_manager.dart';
import 'widgets/anchor_handle_widget.dart';
import 'widgets/inflection_handle_widget.dart';
import 'widgets/link_label_handle_widget.dart';
import 'widgets/miro_canvas_workspace.dart';

// ============================================================================
// THEME COLORS - Centralized color definitions for the entire application
// ============================================================================

// Canvas and Background Colors
const Color colorCanvasBackground = Color.fromARGB(255, 48, 48, 51);
const Color colorPropertiesPanelBg = Color.fromARGB(255, 24, 24, 27);
const Color colorPanelBorder = Color.fromARGB(255, 71, 71, 74);

// Block Colors
const Color colorBlockBackground = Color.fromARGB(255, 33, 33, 36);
const Color colorBlockBackgroundSelected = Color.fromARGB(61, 255, 193, 7);
const Color colorBlockBorder = Color.fromARGB(255, 66, 66, 69);
const Color colorBlockBorderSelected = Color.fromARGB(255, 255, 152, 0);
const Color colorBlockText = Colors.white;
const Color colorBlockTextSelected = Colors.white;

// Link Colors
const Color colorLinkDefault = Color.fromARGB(255, 100, 200, 255);
const Color colorLinkSelected = Color.fromARGB(255, 255, 165, 0);
const Color colorLinkCreation = Color.fromARGB(255, 56, 142, 60);
const Color colorInflectionPoint = Color.fromARGB(255, 255, 152, 0);

// Anchor Handle Colors
const Color colorAnchorSourceHandle = Color.fromARGB(255, 0, 128, 128);
const Color colorAnchorTargetHandle = Color.fromARGB(255, 103, 58, 183);
const Color colorAnchorBorder = Colors.white;

// Text Colors
const Color colorTextPrimary = Colors.white;
const Color colorTextSecondary = Color.fromARGB(179, 255, 255, 255);
const Color colorTextError = Colors.red;

// Shadow and Effects
const Color colorShadow1 = Color.fromARGB(77, 0, 0, 0);
const Color colorShadow2 = Color.fromARGB(64, 0, 0, 0);

class MiroLikeWidget extends StatefulWidget {
  const MiroLikeWidget({super.key});

  @override
  State<MiroLikeWidget> createState() => _MiroLikeWidgetState();
}

const double _linkHitTolerance = 24.0;
const double _inflectionHandleRadius = 7.0;
const double _anchorHandleRadius = 6.0;
const double anchorSpacingDistance = 25.0;
const double _anchorPaddingMargin = 50.0;
const double _alignmentSnapCaptureDistance = 10.0;
const double _alignmentSnapReleaseDistance = 24.0;

class _MiroLikeWidgetState extends State<MiroLikeWidget>
    with SingleTickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();
  final List<Block> blocks = [];
  final List<BlockLink> links = [];
  late final AnimationController _flowController;
  late final LinkManager linkManager;
  late final ImportExportManager importExportManager;
  Block? selectedBlock;
  BlockLink? selectedLink;
  Block? linkSourceBlock;
  Offset? linkingFromPoint;
  Offset? currentMousePosition;
  final List<Offset> pendingInflectionPoints = [];
  Offset canvasOffset = Offset.zero;
  double zoomLevel = 1.0;
  bool isPanning = false;
  double? _snapLeftModel;
  double? _snapTopModel;
  Offset? _dragFreePositionModel;

  @override
  void initState() {
    super.initState();
    linkManager = LinkManager(
      blocks: blocks,
      onBlockSpaceEnsure: _ensureBlockHasSpaceForAnchors,
    );
    importExportManager = ImportExportManager(
      context: context,
      generateBoardJson: _generateBoardJson,
      importBoard: _importBoard,
      generateMermaid: _generateMermaid,
      importMermaid: _importMermaid,
    );
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _initializeSampleBlocks();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  void _initializeSampleBlocks() {
    blocks.addAll([
      Block(id: '1', title: 'Block 1', position: const Offset(100, 100)),
      Block(id: '2', title: 'Block 2', position: const Offset(350, 100)),
      Block(id: '3', title: 'Block 3', position: const Offset(225, 300)),
    ]);
  }

  void _addBlock(Offset position) {
    setState(() {
      blocks.add(
        Block(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Block ${blocks.length + 1}',
          position: (position - canvasOffset) / zoomLevel,
        ),
      );
    });
  }

  void _deleteBlock(Block block) {
    setState(() {
      blocks.remove(block);
      links.removeWhere(
        (link) => link.fromBlockId == block.id || link.toBlockId == block.id,
      );
      selectedBlock = null;
      if (selectedLink != null && !links.contains(selectedLink)) {
        selectedLink = null;
      }
    });
  }

  void _deleteLink(BlockLink link) {
    setState(() {
      linkManager.deleteLink(links, link);
      if (selectedLink == link) {
        selectedLink = null;
      }
    });
  }

  void _reverseLink(BlockLink link) {
    setState(() {
      linkManager.reverseLink(links, link);
    });
  }

  void _handleBlockTitleChanged(String blockId, String newTitle) {
    setState(() {
      final blockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        blocks[blockIndex].title = newTitle;
      }
    });
  }

  void _handleBlockColorChanged(Block block, String? colorKey) {
    setState(() {
      block.colorKey = colorKey;
    });
  }

  void _handleLinkNameChanged(BlockLink link, String newName) {
    setState(() {
      link.name = newName;
    });
  }

  void _handleLinkColorChanged(BlockLink link, String? colorKey) {
    setState(() {
      link.colorKey = colorKey;
    });
  }

  void _handleLinkLabelIconChanged(BlockLink link, String? iconKey) {
    setState(() {
      link.labelIconKey = iconKey;
    });
  }

  void _handleLinkParticleDensityChanged(BlockLink link, double value) {
    setState(() {
      link.particleDensity = value.clamp(0.2, 3.0);
    });
  }

  void _handleLinkParticleSpeedChanged(BlockLink link, double value) {
    setState(() {
      link.particleSpeed = value.clamp(0.2, 3.0);
    });
  }

  void _handleLinkLabelPositionChanged(BlockLink link, double value) {
    setState(() {
      link.labelPosition = value;
    });
  }

  void _handleLinkLabelOffsetChanged(BlockLink link, Offset offset) {
    setState(() {
      link.labelOffset = offset;
    });
  }

  void _handleConnectorTypeChanged(
    BlockLink link,
    ConnectorType connectorType,
  ) {
    setState(() {
      link.connectorType = connectorType;
    });
  }

  void _fitToView() {
    if (blocks.isEmpty) {
      return;
    }

    setState(() {
      // Calculer la bounding box de tous les blocs
      double minX = blocks[0].position.dx;
      double minY = blocks[0].position.dy;
      double maxX = blocks[0].position.dx + blocks[0].size.width;
      double maxY = blocks[0].position.dy + blocks[0].size.height;

      for (final block in blocks) {
        minX = math.min(minX, block.position.dx);
        minY = math.min(minY, block.position.dy);
        maxX = math.max(maxX, block.position.dx + block.size.width);
        maxY = math.max(maxY, block.position.dy + block.size.height);
      }

      final contentWidth = maxX - minX;
      final contentHeight = maxY - minY;
      const padding = 60.0;

      // Calculer le zoom pour que tout rentre dans la vue avec du padding
      final RenderBox? renderBox =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        return;
      }

      final viewportWidth = renderBox.size.width - (padding * 2);
      final viewportHeight = renderBox.size.height - (padding * 2);

      final zoomX = viewportWidth / contentWidth;
      final zoomY = viewportHeight / contentHeight;
      zoomLevel = math.min(zoomX, zoomY).clamp(0.2, 4.0);

      // Centrer le contenu dans la vue
      final centeredX =
          viewportWidth / 2 - (contentWidth * zoomLevel) / 2 + padding;
      final centeredY =
          viewportHeight / 2 - (contentHeight * zoomLevel) / 2 + padding;

      canvasOffset = Offset(
        centeredX - minX * zoomLevel,
        centeredY - minY * zoomLevel,
      );
    });
  }

  void _startLinking(Block block) {
    setState(() {
      linkSourceBlock = block;
      linkingFromPoint = _getBlockCenter(block);
      pendingInflectionPoints.clear();
    });
  }

  void _updateLinkPreviewFromGlobal(Offset globalPosition) {
    if (linkSourceBlock == null) {
      return;
    }
    setState(() {
      currentMousePosition = _toCanvasLocal(globalPosition);
    });
  }

  void _cancelLinking() {
    setState(() {
      linkSourceBlock = null;
      linkingFromPoint = null;
      currentMousePosition = null;
      pendingInflectionPoints.clear();
    });
  }

  void _finishLinkingAtGlobal(Offset globalPosition) {
    if (linkSourceBlock == null) {
      return;
    }

    final modelPosition = _toModelPosition(globalPosition);
    for (var b in blocks) {
      final blockBounds = Rect.fromLTWH(
        b.position.dx,
        b.position.dy,
        b.size.width,
        b.size.height,
      );
      if (blockBounds.contains(modelPosition)) {
        _endLinking(b);
        _cancelLinking();
        return;
      }
    }

    _cancelLinking();
  }

  bool _isSecondaryButtonPressed(int buttons) {
    return (buttons & kSecondaryMouseButton) != 0;
  }

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
      return fallback;
    }
    final width = value['width'];
    final height = value['height'];
    if (width is num && height is num) {
      return Size(width.toDouble(), height.toDouble());
    }
    return fallback;
  }

  Map<String, dynamic> _blockToJson(Block block) {
    return {
      'id': block.id,
      'title': block.title,
      'colorKey': block.colorKey,
      'position': _offsetToJson(block.position),
      'size': _sizeToJson(block.size),
    };
  }

  Map<String, dynamic> _linkToJson(BlockLink link) {
    return {
      'fromBlockId': link.fromBlockId,
      'toBlockId': link.toBlockId,
      'name': link.name,
      'colorKey': link.colorKey,
      'labelIconKey': link.labelIconKey,
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
      'sourceAnchorOrderKey': link.sourceAnchorOrderKey,
      'targetAnchorOrderKey': link.targetAnchorOrderKey,
    };
  }

  Map<String, dynamic> _boardToJson() {
    return {
      'version': 1,
      'zoomLevel': zoomLevel,
      'canvasOffset': _offsetToJson(canvasOffset),
      'blocks': blocks.map(_blockToJson).toList(),
      'links': links.map(_linkToJson).toList(),
    };
  }

  String _generateBoardJson() {
    return const JsonEncoder.withIndent('  ').convert(_boardToJson());
  }

  String _escapeMermaidText(String text) {
    return text
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();
  }

  String _generateMermaid() {
    final blockIds = <String, String>{};
    for (var i = 0; i < blocks.length; i++) {
      blockIds[blocks[i].id] = 'm$i';
    }

    final buffer = StringBuffer('flowchart TD\n');
    for (final block in blocks) {
      final nodeId = blockIds[block.id];
      if (nodeId == null) {
        continue;
      }
      buffer.writeln('  $nodeId["${_escapeMermaidText(block.title)}"]');
    }

    for (final link in links) {
      final fromId = blockIds[link.fromBlockId];
      final toId = blockIds[link.toBlockId];
      if (fromId == null || toId == null) {
        continue;
      }

      final label = link.name.trim();
      if (label.isEmpty) {
        buffer.writeln('  $fromId --> $toId');
      } else {
        buffer.writeln('  $fromId -->|${_escapeMermaidText(label)}| $toId');
      }
    }

    return buffer.toString().trimRight();
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

      final title = item['title']?.toString() ?? 'Block';
      parsed.add(
        Block(
          id: id,
          title: title,
          colorKey: item['colorKey']?.toString(),
          position: _offsetFromJson(item['position']),
          size: _sizeFromJson(item['size']),
        ),
      );
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

      parsed.add(
        BlockLink(
          fromBlockId: fromId,
          toBlockId: toId,
          name: item['name']?.toString() ?? '',
          colorKey: item['colorKey']?.toString(),
          labelIconKey: item['labelIconKey']?.toString(),
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

  String _extractMermaidSource(String text) {
    final fenced = RegExp(
      r'```(?:mermaid)?\s*([\s\S]*?)```',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    if (fenced != null) {
      return fenced.group(1)?.trim() ?? '';
    }
    return text.trim();
  }

  void _importMermaid(String text) {
    final source = _extractMermaidSource(text);
    if (source.isEmpty) {
      throw const FormatException('Le code Mermaid est vide');
    }

    final lines = source.split(RegExp(r'\r?\n'));
    final nodeTitles = <String, String>{};
    final nodeOrder = <String>[];
    final edgeData = <({String fromId, String toId, String label})>[];

    void registerNode(String nodeId, [String? title]) {
      if (!nodeOrder.contains(nodeId)) {
        nodeOrder.add(nodeId);
      }
      if (title != null && title.isNotEmpty) {
        nodeTitles[nodeId] = title;
      } else {
        nodeTitles.putIfAbsent(nodeId, () => nodeId);
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('%%')) {
        continue;
      }

      if (line.startsWith('flowchart ') || line.startsWith('graph ')) {
        continue;
      }

      final nodeMatch = RegExp(
        r'^([A-Za-z_][A-Za-z0-9_-]*)\s*\[\s*(?:"([^"]*)"|([^\]]*))\s*\]\s*$',
      ).firstMatch(line);
      if (nodeMatch != null) {
        final nodeId = nodeMatch.group(1)!;
        final title = nodeMatch.group(2) ?? nodeMatch.group(3) ?? nodeId;
        registerNode(nodeId, title);
        continue;
      }

      final edgeMatch = RegExp(
        r'^([A-Za-z_][A-Za-z0-9_-]*)\s*--?>\s*(?:\|([^|]*)\|\s*)?([A-Za-z_][A-Za-z0-9_-]*)\s*$',
      ).firstMatch(line);
      if (edgeMatch != null) {
        final fromId = edgeMatch.group(1)!;
        final label = (edgeMatch.group(2) ?? '').trim();
        final toId = edgeMatch.group(3)!;
        registerNode(fromId);
        registerNode(toId);
        edgeData.add((fromId: fromId, toId: toId, label: label));
      }
    }

    if (nodeOrder.isEmpty) {
      throw const FormatException('Aucun bloc Mermaid reconnu');
    }

    final importedBlocks = <Block>[];
    for (var i = 0; i < nodeOrder.length; i++) {
      final nodeId = nodeOrder[i];
      importedBlocks.add(
        Block(
          id: nodeId,
          title: nodeTitles[nodeId] ?? nodeId,
          position: Offset(80 + (i % 4) * 220, 80 + (i ~/ 4) * 160),
        ),
      );
    }

    final importedLinks = <BlockLink>[];
    for (final edge in edgeData) {
      importedLinks.add(
        BlockLink(
          fromBlockId: edge.fromId,
          toBlockId: edge.toId,
          name: edge.label,
        ),
      );
    }

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
    });
  }

  void _importBoard(Map<String, dynamic> decoded) {
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
    });
  }

  void _endLinking(Block targetBlock) {
    if (linkSourceBlock != null && linkSourceBlock!.id != targetBlock.id) {
      final sourceRect = _blockRectCanvas(linkSourceBlock!);
      final targetRect = _blockRectCanvas(targetBlock);

      final sourceAnchorUnit = _calculateOptimalAnchorUnit(
        sourceRect,
        targetRect,
      );
      final targetAnchorUnit = _calculateOptimalAnchorUnit(
        targetRect,
        sourceRect,
      );

      setState(() {
        links.add(
          BlockLink(
            fromBlockId: linkSourceBlock!.id,
            toBlockId: targetBlock.id,
            name: 'Lien ${links.length + 1}',
            colorKey: null,
            labelPosition: 0.75,
            labelOffset: Offset.zero,
            particleDensity: 1.0,
            particleSpeed: 1.0,
            connectorType: ConnectorType.bezier,
            inflectionPoints: List<Offset>.from(pendingInflectionPoints),
            sourceAnchorUnit: sourceAnchorUnit,
            targetAnchorUnit: targetAnchorUnit,
          ),
        );
        _ensureBlockHasSpaceForAnchors(linkSourceBlock!);
        _ensureBlockHasSpaceForAnchors(targetBlock);
        linkSourceBlock = null;
        linkingFromPoint = null;
        pendingInflectionPoints.clear();
      });
    }
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
    // Find all blocks connected to this block
    final connectedBlockIds = <String>{};
    for (var link in links) {
      if (link.fromBlockId == block.id) {
        connectedBlockIds.add(link.toBlockId);
      }
      if (link.toBlockId == block.id) {
        connectedBlockIds.add(link.fromBlockId);
      }
    }

    // Update anchors for this block and all connected blocks
    final blockIdsToUpdate = {block.id, ...connectedBlockIds};

    for (var blockId in blockIdsToUpdate) {
      for (var link in links) {
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
            final newAnchor = _calculateOptimalAnchorUnit(
              sourceRect,
              targetRect,
            );
            // Only update if the new anchor is truly opposite to the current one
            if (link.sourceAnchorUnit != null &&
                _areAnchorsTrulyOpposite(link.sourceAnchorUnit!, newAnchor)) {
              link.sourceAnchorUnit = newAnchor;
            } else {
              link.sourceAnchorUnit ??= newAnchor;
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
            final newAnchor = _calculateOptimalAnchorUnit(
              targetRect,
              sourceRect,
            );
            // Only update if the new anchor is truly opposite to the current one
            if (link.targetAnchorUnit != null &&
                _areAnchorsTrulyOpposite(link.targetAnchorUnit!, newAnchor)) {
              link.targetAnchorUnit = newAnchor;
            } else {
              link.targetAnchorUnit ??= newAnchor;
            }
          }
        }
      }

      final blockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        _ensureBlockHasSpaceForAnchors(blocks[blockIndex]);
      }
    }
  }

  /// Check if two anchor units are truly opposite (e.g., left vs right, top vs bottom)
  bool _areAnchorsTrulyOpposite(Offset current, Offset newAnchor) {
    // Two anchors are truly opposite if their dot product is -1
    final dotProduct = current.dx * newAnchor.dx + current.dy * newAnchor.dy;
    return dotProduct <
        -0.5; // Less than -0.5 to account for floating point precision
  }

  Offset _getBlockCenter(Block block) {
    return Offset(
      block.position.dx + block.size.width / 2,
      block.position.dy + block.size.height / 2,
    );
  }

  Offset _toCanvasLocal(Offset globalPosition) {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return globalPosition;
    }
    return renderBox.globalToLocal(globalPosition);
  }

  Offset _toModelPosition(Offset globalPosition) {
    final localPosition = _toCanvasLocal(globalPosition);
    return (localPosition - canvasOffset) / zoomLevel;
  }

  Offset _modelToCanvas(Offset modelPoint) {
    return Offset(
      modelPoint.dx * zoomLevel + canvasOffset.dx,
      modelPoint.dy * zoomLevel + canvasOffset.dy,
    );
  }

  void _resetBlockDragSnap() {
    _snapLeftModel = null;
    _snapTopModel = null;
    _dragFreePositionModel = null;
  }

  Offset _applyBlockAlignmentSnap(Block movingBlock, Offset proposedPosition) {
    final captureDistanceModel = _alignmentSnapCaptureDistance / zoomLevel;
    final releaseDistanceModel = _alignmentSnapReleaseDistance / zoomLevel;

    double? closestLeft;
    double closestLeftDeltaAbs = double.infinity;
    double? closestTop;
    double closestTopDeltaAbs = double.infinity;

    for (final other in blocks) {
      if (other.id == movingBlock.id) {
        continue;
      }

      final leftDelta = other.position.dx - proposedPosition.dx;
      final leftDeltaAbs = leftDelta.abs();
      if (leftDeltaAbs < closestLeftDeltaAbs) {
        closestLeftDeltaAbs = leftDeltaAbs;
        closestLeft = other.position.dx;
      }

      final topDelta = other.position.dy - proposedPosition.dy;
      final topDeltaAbs = topDelta.abs();
      if (topDeltaAbs < closestTopDeltaAbs) {
        closestTopDeltaAbs = topDeltaAbs;
        closestTop = other.position.dy;
      }
    }

    if (_snapLeftModel != null &&
        (proposedPosition.dx - _snapLeftModel!).abs() > releaseDistanceModel) {
      _snapLeftModel = null;
    }
    if (_snapTopModel != null &&
        (proposedPosition.dy - _snapTopModel!).abs() > releaseDistanceModel) {
      _snapTopModel = null;
    }

    if (_snapLeftModel == null &&
        closestLeft != null &&
        closestLeftDeltaAbs <= captureDistanceModel) {
      _snapLeftModel = closestLeft;
    }
    if (_snapTopModel == null &&
        closestTop != null &&
        closestTopDeltaAbs <= captureDistanceModel) {
      _snapTopModel = closestTop;
    }

    return Offset(
      _snapLeftModel ?? proposedPosition.dx,
      _snapTopModel ?? proposedPosition.dy,
    );
  }

  Rect _blockRectCanvas(Block block) {
    return Rect.fromLTWH(
      block.position.dx * zoomLevel + canvasOffset.dx,
      block.position.dy * zoomLevel + canvasOffset.dy,
      block.size.width * zoomLevel,
      block.size.height * zoomLevel,
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

    // Keep room for anchor handle diameter and edge breathing room.
    final sidePadding = (_anchorHandleRadius * 2) + 4.0;
    return (count - 1) * anchorSpacingDistance + (2 * sidePadding);
  }

  void _ensureBlockHasSpaceForAnchors(Block block) {
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

    // Add padding margin to allow easy addition of new anchors
    final paddingMargin = _anchorPaddingMargin / zoomLevel;
    final newWidth = math.max(
      block.size.width,
      requiredModelWidth + paddingMargin,
    );
    final newHeight = math.max(
      block.size.height,
      requiredModelHeight + paddingMargin,
    );

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

    final currentLinkIndex = links.indexOf(currentLink);
    if (currentLinkIndex == -1) {
      return Offset.zero;
    }

    final grouped = <(int, double)>[];
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
      grouped.add((i, _anchorOrderKeyForLinkSide(link, blockId, side, i)));
    }

    if (grouped.isEmpty) {
      return Offset.zero;
    }

    grouped.sort((a, b) {
      final byKey = a.$2.compareTo(b.$2);
      if (byKey != 0) {
        return byKey;
      }
      return a.$1.compareTo(b.$1);
    });

    final anchorIndex = grouped.indexWhere(
      (entry) => entry.$1 == currentLinkIndex,
    );
    if (anchorIndex == -1) {
      return Offset.zero;
    }

    final centerOffset =
        (anchorIndex - (grouped.length - 1) / 2) * spacingDistance;

    // Apply spacing parallel to the anchor side
    if (side.dx != 0) {
      // Horizontal side (left/right) - space vertically
      return Offset(0, centerOffset);
    } else if (side.dy != 0) {
      // Vertical side (top/bottom) - space horizontally
      return Offset(centerOffset, 0);
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

    final startTangent = axisNormalForBorderPoint(fromRect, fromEdge);
    final targetOutward = axisNormalForBorderPoint(toRect, toEdge);
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
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onSecondaryTapDown: (_) {
            setState(() {
              if (pointIndex >= 0 &&
                  pointIndex < link.inflectionPoints.length) {
                link.inflectionPoints.removeAt(pointIndex);
              }
            });
          },
          onPanUpdate: (details) {
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              link.inflectionPoints[pointIndex] += details.delta / zoomLevel;
            });
          },
        ),
      );
    }

    return widgets;
  }

  Offset? _linkLabelReferenceCanvas(BlockLink link) {
    final linkData = _resolveLinkAnchorsAndRects(link);
    if (linkData == null) return null;

    final fromEdge = linkData.$1;
    final toEdge = linkData.$2;
    final viaCanvas = linkData.$3;
    final fromRect = linkData.$4;
    final toRect = linkData.$5;

    // Compute tangents the same way the painter does
    final startTangent = axisNormalForBorderPoint(fromRect, fromEdge);
    final targetOutward = axisNormalForBorderPoint(toRect, toEdge);
    final endTangent = Offset(-targetOutward.dx, -targetOutward.dy);

    // Build the exact same path as the painter so the hit area matches
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
    return tangent.position + normal * 18 + link.labelOffset * zoomLevel;
  }

  List<Widget> _buildLinkLabelHandles() {
    final widgets = <Widget>[];

    for (final link in links) {
      if (link.name.trim().isEmpty) {
        continue;
      }

      final labelCenter = _linkLabelReferenceCanvas(link);
      if (labelCenter == null) {
        continue;
      }

      final iconExtraWidth = link.labelIconKey == null ? 0.0 : 20.0;
      final width = math.max(
        90.0,
        link.name.length * 8.0 + 28.0 + iconExtraWidth,
      );
      const height = 32.0;

      widgets.add(
        LinkLabelHandleWidget(
          left: labelCenter.dx - width / 2,
          top: labelCenter.dy - height / 2,
          width: width,
          height: height,
          onTapDown: (_) {
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              link.labelOffset += details.delta / zoomLevel;
            });
          },
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildAnchorHandles() {
    final widgets = <Widget>[];

    // Scale handle radius with zoom so handles never overlap
    // (spacing = 15 * zoomLevel, handles must fit within that spacing)
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
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onSecondaryTapDown: (_) {
            setState(() {
              if (linkIndex >= 0 && linkIndex < links.length) {
                links.removeAt(linkIndex);
                if (selectedLink == link) {
                  selectedLink = null;
                }
              }
            });
          },
          onPanUpdate: (details) {
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              final canvasPosition = _toCanvasLocal(details.globalPosition);
              link.sourceAnchorUnit = _anchorUnitFromCanvasPoint(
                fromRect,
                canvasPosition,
              );
              link.sourceAnchorOrderKey = _anchorOrderKeyFromCanvasPoint(
                fromRect,
                link.sourceAnchorUnit!,
                canvasPosition,
              );
              final fromIndex = blocks.indexWhere(
                (b) => b.id == link.fromBlockId,
              );
              if (fromIndex != -1) {
                _ensureBlockHasSpaceForAnchors(blocks[fromIndex]);
              }
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
            setState(() {
              selectedLink = link;
              selectedBlock = null;
            });
          },
          onSecondaryTapDown: (_) {
            setState(() {
              if (linkIndex >= 0 && linkIndex < links.length) {
                links.removeAt(linkIndex);
                if (selectedLink == link) {
                  selectedLink = null;
                }
              }
            });
          },
          onPanUpdate: (details) {
            setState(() {
              selectedLink = link;
              selectedBlock = null;
              final canvasPosition = _toCanvasLocal(details.globalPosition);
              link.targetAnchorUnit = _anchorUnitFromCanvasPoint(
                toRect,
                canvasPosition,
              );
              link.targetAnchorOrderKey = _anchorOrderKeyFromCanvasPoint(
                toRect,
                link.targetAnchorUnit!,
                canvasPosition,
              );
              final toIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
              if (toIndex != -1) {
                _ensureBlockHasSpaceForAnchors(blocks[toIndex]);
              }
            });
          },
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Domain Designer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addBlock(Offset(200, 200)),
            tooltip: 'Ajouter un bloc',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: selectedBlock != null
                ? () => _deleteBlock(selectedBlock!)
                : null,
            tooltip: 'Supprimer le bloc sélectionné',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Export JSON',
            onPressed: () => importExportManager.showExportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import JSON',
            onPressed: () => importExportManager.showImportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Export Mermaid',
            onPressed: () => importExportManager.showExportMermaidDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.schema_outlined),
            tooltip: 'Import Mermaid',
            onPressed: () => importExportManager.showImportMermaidDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Voir tous les blocs',
            onPressed: _fitToView,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: MiroCanvasWorkspace(
              canvasKey: _canvasKey,
              canvasBackgroundColor: colorCanvasBackground,
              blocks: blocks,
              canvasOffset: canvasOffset,
              zoomLevel: zoomLevel,
              selectedBlock: selectedBlock,
              linkSourceBlock: linkSourceBlock,
              foregroundPainter: MiroCanvasPainter(
                blocks: blocks,
                links: links,
                canvasOffset: canvasOffset,
                zoomLevel: zoomLevel,
                selectedBlock: selectedBlock,
                selectedLink: selectedLink,
                linkingFromPoint: linkingFromPoint,
                currentMousePosition: currentMousePosition,
                linkSourceBlock: linkSourceBlock,
                flowAnimation: _flowController,
                pendingInflectionPoints: pendingInflectionPoints,
              ),
              overlayWidgets: [
                ..._buildAnchorHandles(),
                ..._buildInflectionHandles(),
                ..._buildLinkLabelHandles(),
              ],
              onHover: (event) {
                setState(() {
                  currentMousePosition = event.localPosition;
                });
              },
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  setState(() {
                    final mouseCanvasPos = event.localPosition;
                    final modelPointBeforeZoom =
                        (mouseCanvasPos - canvasOffset) / zoomLevel;
                    final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
                    zoomLevel = (zoomLevel * zoomFactor).clamp(0.2, 4.0);
                    canvasOffset =
                        mouseCanvasPos - modelPointBeforeZoom * zoomLevel;
                  });
                }
              },
              onCanvasPanDown: (details) {
                setState(() {
                  final modelPosition = _toModelPosition(
                    details.globalPosition,
                  );
                  bool isOnBlock = false;
                  for (var block in blocks) {
                    final blockRect = Rect.fromLTWH(
                      block.position.dx,
                      block.position.dy,
                      block.size.width,
                      block.size.height,
                    );
                    if (blockRect.contains(modelPosition)) {
                      isOnBlock = true;
                      break;
                    }
                  }
                  isPanning = !isOnBlock;
                });
              },
              onCanvasPanUpdate: (details) {
                if (isPanning) {
                  setState(() {
                    canvasOffset += details.delta;
                  });
                }
              },
              onCanvasPanEnd: (_) {
                setState(() {
                  isPanning = false;
                });
              },
              onCanvasTapDown: (details) {
                setState(() {
                  final canvasPosition = _toCanvasLocal(details.globalPosition);
                  final modelPosition = _toModelPosition(
                    details.globalPosition,
                  );

                  if (linkSourceBlock != null) {
                    return;
                  }

                  for (var block in blocks) {
                    final blockRect = Rect.fromLTWH(
                      block.position.dx,
                      block.position.dy,
                      block.size.width,
                      block.size.height,
                    );
                    if (blockRect.contains(modelPosition)) {
                      selectedBlock = block;
                      selectedLink = null;
                      return;
                    }
                  }

                  final hitLink = _findLinkAtCanvasPosition(canvasPosition);
                  if (hitLink != null) {
                    selectedBlock = null;
                    selectedLink = hitLink;
                    return;
                  }

                  selectedBlock = null;
                  selectedLink = null;
                });
              },
              onCanvasSecondaryTapDown: (details) {
                setState(() {
                  final canvasPosition = _toCanvasLocal(details.globalPosition);

                  if (linkSourceBlock != null) {
                    return;
                  }

                  final hitLink = _findLinkAtCanvasPosition(canvasPosition);
                  if (hitLink == null) {
                    return;
                  }

                  selectedBlock = null;
                  if (selectedLink != hitLink) {
                    selectedLink = hitLink;
                    return;
                  }

                  final pointAdded = _insertInflectionPointOnLink(
                    canvasPosition,
                  );
                  if (!pointAdded) {
                    selectedLink = hitLink;
                  }
                });
              },
              isSecondaryButtonPressed: _isSecondaryButtonPressed,
              onStartLinkingForBlock: _startLinking,
              onUpdateLinkPreviewFromGlobal: _updateLinkPreviewFromGlobal,
              onFinishLinkingAtGlobal: _finishLinkingAtGlobal,
              onBlockPanDown: (block) {
                setState(() {
                  selectedBlock = block;
                  selectedLink = null;
                  _resetBlockDragSnap();
                  _dragFreePositionModel = block.position;
                });
              },
              onBlockPanUpdate: (block, details) {
                if (selectedBlock == block) {
                  setState(() {
                    final deltaModel = Offset(
                      details.delta.dx / zoomLevel,
                      details.delta.dy / zoomLevel,
                    );
                    final proposedPosition =
                        (_dragFreePositionModel ?? block.position) + deltaModel;
                    _dragFreePositionModel = proposedPosition;
                    block.position = _applyBlockAlignmentSnap(
                      block,
                      proposedPosition,
                    );
                    _updateLinksAnchorsForBlock(block);
                  });
                }
              },
              onBlockPanEnd: (_) {
                _resetBlockDragSnap();
              },
              onBlockTapDown: (block) {
                setState(() {
                  selectedBlock = block;
                  selectedLink = null;
                  _resetBlockDragSnap();
                });
              },
            ),
          ),
          PropertiesPanel(
            selectedBlock: selectedBlock,
            selectedLink: selectedLink,
            onBlockTitleChanged: _handleBlockTitleChanged,
            onBlockColorChanged: _handleBlockColorChanged,
            onLinkNameChanged: _handleLinkNameChanged,
            onLinkColorChanged: _handleLinkColorChanged,
            onLinkLabelIconChanged: _handleLinkLabelIconChanged,
            onLinkParticleDensityChanged: _handleLinkParticleDensityChanged,
            onLinkParticleSpeedChanged: _handleLinkParticleSpeedChanged,
            onLinkLabelPositionChanged: _handleLinkLabelPositionChanged,
            onLinkLabelOffsetChanged: _handleLinkLabelOffsetChanged,
            onReverseLink: _reverseLink,
            onDeleteLink: _deleteLink,
            onConnectorTypeChanged: _handleConnectorTypeChanged,
          ),
        ],
      ),
    );
  }
}
