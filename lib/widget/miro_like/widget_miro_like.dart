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
  static const List<String> _mermaidDirections = ['LR', 'TB', 'RL', 'BT'];
  static const List<String> _placementQualities = [
    'Rapide',
    'Equilibre',
    'Dense',
  ];

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
  String _mermaidLayoutDirection = 'LR';
  String _placementQuality = 'Dense';
  double? _snapLeftModel;
  double? _snapTopModel;
  Offset? _dragFreePositionModel;

  ({
    double iterationMul,
    double repulsionMul,
    double springMul,
    double overlapMul,
    double hpwlMul,
    double crossingMul,
    int channelPitch,
    double snapTargetWeight,
  })
  _placementQualityProfile() {
    switch (_placementQuality) {
      case 'Rapide':
        return (
          iterationMul: 0.72,
          repulsionMul: 0.90,
          springMul: 0.92,
          overlapMul: 0.92,
          hpwlMul: 0.75,
          crossingMul: 0.78,
          channelPitch: 1,
          snapTargetWeight: 0.32,
        );
      case 'Dense':
        return (
          iterationMul: 1.38,
          repulsionMul: 1.14,
          springMul: 1.08,
          overlapMul: 1.14,
          hpwlMul: 1.25,
          crossingMul: 1.28,
          channelPitch: 3,
          snapTargetWeight: 0.56,
        );
      case 'Equilibre':
      default:
        return (
          iterationMul: 1.0,
          repulsionMul: 1.0,
          springMul: 1.0,
          overlapMul: 1.0,
          hpwlMul: 1.0,
          crossingMul: 1.0,
          channelPitch: 2,
          snapTargetWeight: 0.45,
        );
    }
  }

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
        blocks[blockIndex].title = _normalizeBlockTitleLineBreaks(newTitle);
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

  String _normalizeBlockTitleLineBreaks(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('/n', '\n');
  }

  String _escapeMermaidText(String text) {
    final normalized = _normalizeBlockTitleLineBreaks(text);
    return normalized
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .trim();
  }

  String _generateMermaid() {
    final blockIds = <String, String>{};
    for (var i = 0; i < blocks.length; i++) {
      blockIds[blocks[i].id] = 'm$i';
    }

    final buffer = StringBuffer('flowchart $_mermaidLayoutDirection\n');
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

      final title = _normalizeBlockTitleLineBreaks(
        item['title']?.toString() ?? 'Block',
      );
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

  Map<String, Offset> _computeMermaidAutoLayout(
    List<String> nodeOrder,
    List<({String fromId, String toId, String label})> edgeData,
    String direction,
    List<Block>? layoutBlocks, {
    Map<String, Offset>? seedPositions,
  }) {
    if (nodeOrder.isEmpty) {
      return {};
    }

    final effectiveBlocks = layoutBlocks ?? blocks;
    final nodeSet = nodeOrder.toSet();
    final indexByNode = <String, int>{
      for (int i = 0; i < nodeOrder.length; i++) nodeOrder[i]: i,
    };

    final directedEdges = <(String, String)>[];
    final undirectedEdges = <(String, String)>[];
    final undirectedSeen = <String>{};
    final degree = <String, int>{for (final id in nodeOrder) id: 0};
    final neighbors = <String, Set<String>>{
      for (final id in nodeOrder) id: <String>{},
    };

    for (final edge in edgeData) {
      if (!nodeSet.contains(edge.fromId) || !nodeSet.contains(edge.toId)) {
        continue;
      }
      if (edge.fromId == edge.toId) {
        continue;
      }
      directedEdges.add((edge.fromId, edge.toId));

      final a = edge.fromId;
      final b = edge.toId;
      final key = (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';
      if (undirectedSeen.add(key)) {
        undirectedEdges.add((a, b));
        degree[a] = (degree[a] ?? 0) + 1;
        degree[b] = (degree[b] ?? 0) + 1;
        neighbors[a]!.add(b);
        neighbors[b]!.add(a);
      }
    }

    final count = nodeOrder.length;
    final maxBlockW = effectiveBlocks.isEmpty
        ? 150.0
        : effectiveBlocks
              .map((b) => b.size.width)
              .fold<double>(150.0, math.max);
    final maxBlockH = effectiveBlocks.isEmpty
        ? 100.0
        : effectiveBlocks
              .map((b) => b.size.height)
              .fold<double>(100.0, math.max);

    final quality = _placementQualityProfile();
    final channelPitch = quality.channelPitch.clamp(1, 3);
    final aspectHint = direction == 'LR' || direction == 'RL' ? 1.45 : 0.82;
    final rawCols = math.sqrt(count * aspectHint);
    final cols = math.max(2, rawCols.ceil());
    final rows = math.max(2, (count / cols).ceil());
    final placementCols = cols + 1;
    final placementRows = math.max(
      rows + 1,
      (count / placementCols).ceil() + 1,
    );

    const baseX = 120.0;
    const baseY = 90.0;
    final cellW = math.max(210.0, maxBlockW + 110.0);
    final cellH = math.max(150.0, maxBlockH + 90.0);
    final areaWBase = math.max(760.0, cols * cellW);
    final areaHBase = math.max(560.0, rows * cellH);
    final minPlacementPitchX =
        maxBlockW +
        70 +
        (channelPitch == 3 ? 24 : (channelPitch == 2 ? 16 : 8));
    final minPlacementPitchY =
        maxBlockH +
        56 +
        (channelPitch == 3 ? 20 : (channelPitch == 2 ? 14 : 8));
    final requiredAreaW =
        maxBlockW + 20 + (placementCols - 1) * minPlacementPitchX;
    final requiredAreaH =
        maxBlockH + 20 + (placementRows - 1) * minPlacementPitchY;
    final areaW = math.max(areaWBase, requiredAreaW);
    final areaH = math.max(areaHBase, requiredAreaH);

    final minX = baseX;
    final minY = baseY;
    final maxX = baseX + areaW;
    final maxY = baseY + areaH;
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    final sortedByDegree = [...nodeOrder]
      ..sort((a, b) {
        final byDegree = (degree[b] ?? 0).compareTo(degree[a] ?? 0);
        if (byDegree != 0) {
          return byDegree;
        }
        return indexByNode[a]!.compareTo(indexByNode[b]!);
      });

    final seedPositionsByNode = seedPositions ?? const <String, Offset>{};
    final positions = <String, Offset>{};
    final cellTargets = <String, Offset>{};
    for (int i = 0; i < sortedByDegree.length; i++) {
      final nodeId = sortedByDegree[i];
      final col = i % cols;
      final row = i ~/ cols;
      final jitterX = ((i * 37) % 17 - 8) * 2.5;
      final jitterY = ((i * 53) % 19 - 9) * 2.0;
      final target = Offset(
        minX + (col + 0.5) * (areaW / cols),
        minY + (row + 0.5) * (areaH / rows),
      );
      cellTargets[nodeId] = seedPositionsByNode[nodeId] ?? target;
      positions[nodeId] =
          seedPositionsByNode[nodeId] ?? target + Offset(jitterX, jitterY);
    }

    final isHorizontal = direction == 'LR' || direction == 'RL';
    final isReverse = direction == 'RL' || direction == 'BT';
    final flowSign = isReverse ? -1.0 : 1.0;
    final sizeByNode = <String, Size>{
      for (final id in nodeOrder)
        id:
            effectiveBlocks
                .where((b) => b.id == id)
                .map((b) => b.size)
                .firstOrNull ??
            const Size(150, 100),
    };

    final edgeDensity = undirectedEdges.length / math.max(1, count);
    final averagePitch = math.sqrt((areaW * areaH) / math.max(1, count));
    final iterationCount = ((150 + count * 3) * quality.iterationMul)
        .round()
        .clamp(120, 420);

    final forces = <String, Offset>{
      for (final id in nodeOrder) id: Offset.zero,
    };
    final repulsion = (22000.0 + 16000.0 * edgeDensity) * quality.repulsionMul;
    final springRest = (averagePitch * (0.82 + 0.18 * edgeDensity)).clamp(
      150.0,
      300.0,
    );
    final springK =
        (0.020 + 0.008 * edgeDensity).clamp(0.018, 0.032) * quality.springMul;
    final overlapK =
        (0.30 + 0.06 * edgeDensity).clamp(0.30, 0.42) * quality.overlapMul;
    const boundaryK = 0.36;
    const targetK = 0.012;
    const centerK = 0.004;
    const directionK = 0.030;
    final hpwlK =
        (0.040 + 0.020 * edgeDensity).clamp(0.040, 0.075) * quality.hpwlMul;

    for (int iteration = 0; iteration < iterationCount; iteration++) {
      final cooling = 1.0 - (iteration / (iterationCount + 12.0));
      for (final id in nodeOrder) {
        forces[id] = Offset.zero;
      }

      // Repulsion + overlap handling between all node pairs.
      for (int i = 0; i < nodeOrder.length - 1; i++) {
        final a = nodeOrder[i];
        final pa = positions[a]!;
        final sa = sizeByNode[a]!;
        for (int j = i + 1; j < nodeOrder.length; j++) {
          final b = nodeOrder[j];
          final pb = positions[b]!;
          final sb = sizeByNode[b]!;

          final delta = pa - pb;
          final dist2 = math.max(
            36.0,
            delta.dx * delta.dx + delta.dy * delta.dy,
          );
          final dist = math.sqrt(dist2);
          final dir = dist > 1e-6 ? delta / dist : const Offset(1, 0);
          final push = dir * (repulsion / dist2);
          forces[a] = forces[a]! + push;
          forces[b] = forces[b]! - push;

          final overlapX =
              (sa.width + sb.width) / 2 + 26 - (pa.dx - pb.dx).abs();
          final overlapY =
              (sa.height + sb.height) / 2 + 22 - (pa.dy - pb.dy).abs();
          if (overlapX > 0 && overlapY > 0) {
            if (overlapX < overlapY) {
              final sx = pa.dx >= pb.dx ? 1.0 : -1.0;
              final correction = Offset(sx * overlapX * overlapK, 0);
              forces[a] = forces[a]! + correction;
              forces[b] = forces[b]! - correction;
            } else {
              final sy = pa.dy >= pb.dy ? 1.0 : -1.0;
              final correction = Offset(0, sy * overlapY * overlapK);
              forces[a] = forces[a]! + correction;
              forces[b] = forces[b]! - correction;
            }
          }
        }
      }

      // Springs on graph links keep related nodes close.
      for (final edge in undirectedEdges) {
        final a = edge.$1;
        final b = edge.$2;
        final pa = positions[a]!;
        final pb = positions[b]!;
        final delta = pb - pa;
        final dist = math.max(1.0, delta.distance);
        final dir = delta / dist;
        final spring = dir * ((dist - springRest) * springK);
        forces[a] = forces[a]! + spring;
        forces[b] = forces[b]! - spring;
      }

      // Preferred direction bias (soft constraint only).
      for (final edge in directedEdges) {
        final fromId = edge.$1;
        final toId = edge.$2;
        final from = positions[fromId]!;
        final to = positions[toId]!;

        final primaryDelta = isHorizontal
            ? (to.dx - from.dx)
            : (to.dy - from.dy);
        final missing = (170.0 - flowSign * primaryDelta).clamp(0.0, 320.0);
        if (missing <= 0) {
          continue;
        }

        final f = missing * directionK;
        if (isHorizontal) {
          final dirForce = Offset(flowSign * f, 0);
          forces[fromId] = forces[fromId]! - dirForce;
          forces[toId] = forces[toId]! + dirForce;
        } else {
          final dirForce = Offset(0, flowSign * f);
          forces[fromId] = forces[fromId]! - dirForce;
          forces[toId] = forces[toId]! + dirForce;
        }
      }

      // HPWL-style pull: attract each node toward median neighbor coordinates (Manhattan objective surrogate).
      for (final nodeId in nodeOrder) {
        final linked = neighbors[nodeId]!;
        if (linked.isEmpty) {
          continue;
        }

        final xs = <double>[];
        final ys = <double>[];
        for (final n in linked) {
          final p = positions[n];
          if (p == null) {
            continue;
          }
          xs.add(p.dx);
          ys.add(p.dy);
        }
        if (xs.isEmpty) {
          continue;
        }
        xs.sort();
        ys.sort();
        final medX = xs[xs.length ~/ 2];
        final medY = ys[ys.length ~/ 2];
        final current = positions[nodeId]!;
        forces[nodeId] =
            forces[nodeId]! +
            Offset((medX - current.dx) * hpwlK, (medY - current.dy) * hpwlK);
      }

      // Crossing minimization with orthogonal pushes on intersecting links.
      if (iteration % 3 == 0 && directedEdges.length > 1) {
        for (int i = 0; i < directedEdges.length - 1; i++) {
          final e1 = directedEdges[i];
          for (int j = i + 1; j < directedEdges.length; j++) {
            final e2 = directedEdges[j];

            final shared =
                e1.$1 == e2.$1 ||
                e1.$1 == e2.$2 ||
                e1.$2 == e2.$1 ||
                e1.$2 == e2.$2;
            if (shared) {
              continue;
            }

            final p1 = positions[e1.$1]!;
            final p2 = positions[e1.$2]!;
            final p3 = positions[e2.$1]!;
            final p4 = positions[e2.$2]!;
            if (!_segmentsIntersect(p1, p2, p3, p4)) {
              continue;
            }

            final d1 = p2 - p1;
            final d2 = p4 - p3;
            final n1 = d1.distance > 1e-6
                ? Offset(-d1.dy, d1.dx) / d1.distance
                : const Offset(0, 1);
            final n2 = d2.distance > 1e-6
                ? Offset(-d2.dy, d2.dx) / d2.distance
                : const Offset(0, -1);
            final crossPush = (12.0 + 8.0 * cooling) * quality.crossingMul;

            forces[e1.$1] = forces[e1.$1]! + n1 * crossPush;
            forces[e1.$2] = forces[e1.$2]! + n1 * crossPush;
            forces[e2.$1] = forces[e2.$1]! + n2 * crossPush;
            forces[e2.$2] = forces[e2.$2]! + n2 * crossPush;
          }
        }
      }

      // Keep nodes spread in a rectangle and avoid drifting away.
      for (final id in nodeOrder) {
        final current = positions[id]!;
        final target = cellTargets[id]!;
        var force = forces[id]!;

        force += (target - current) * targetK;
        force += (center - current) * centerK;

        final halfW = sizeByNode[id]!.width / 2;
        final halfH = sizeByNode[id]!.height / 2;
        final safeMinX = minX + halfW;
        final safeMaxX = maxX - halfW;
        final safeMinY = minY + halfH;
        final safeMaxY = maxY - halfH;

        if (current.dx < safeMinX) {
          force += Offset((safeMinX - current.dx) * boundaryK, 0);
        } else if (current.dx > safeMaxX) {
          force += Offset((safeMaxX - current.dx) * boundaryK, 0);
        }
        if (current.dy < safeMinY) {
          force += Offset(0, (safeMinY - current.dy) * boundaryK);
        } else if (current.dy > safeMaxY) {
          force += Offset(0, (safeMaxY - current.dy) * boundaryK);
        }

        final step = force * (0.10 * cooling);
        final next = current + step;
        positions[id] = Offset(
          next.dx.clamp(safeMinX, safeMaxX),
          next.dy.clamp(safeMinY, safeMaxY),
        );
      }
    }

    // Legalization phase: assign nodes to a rectangular slot grid, similar to EDA row/slot legalization.
    final slotCols = placementCols * channelPitch - (channelPitch - 1);
    final slotRows = placementRows * channelPitch - (channelPitch - 1);
    final safeSlots = <Offset>[];
    final slotMinX = minX + maxBlockW / 2 + 10;
    final slotMaxX = maxX - maxBlockW / 2 - 10;
    final slotMinY = minY + maxBlockH / 2 + 10;
    final slotMaxY = maxY - maxBlockH / 2 - 10;
    final pitchX = slotCols <= 1 ? 0.0 : (slotMaxX - slotMinX) / (slotCols - 1);
    final pitchY = slotRows <= 1 ? 0.0 : (slotMaxY - slotMinY) / (slotRows - 1);
    // Use sparse indices for block slots; skipped indices become routing channels.
    for (int r = 0; r < slotRows; r += channelPitch) {
      for (int c = 0; c < slotCols; c += channelPitch) {
        safeSlots.add(Offset(slotMinX + c * pitchX, slotMinY + r * pitchY));
      }
    }

    final freeSlotIndices = <int>{for (int i = 0; i < safeSlots.length; i++) i};
    final legalized = <String, Offset>{};
    final placementOrder = [...nodeOrder]
      ..sort((a, b) {
        final byDegree = (degree[b] ?? 0).compareTo(degree[a] ?? 0);
        if (byDegree != 0) {
          return byDegree;
        }
        return indexByNode[a]!.compareTo(indexByNode[b]!);
      });

    double directionalPenalty(Offset nodePos, Offset slotPos) {
      if (directedEdges.isEmpty) {
        return 0;
      }

      // Keep slot selection biased toward the chosen Mermaid direction.
      final dirAxis = isHorizontal
          ? (slotPos.dx - nodePos.dx)
          : (slotPos.dy - nodePos.dy);
      final wrongWay = (-flowSign * dirAxis).clamp(0.0, 220.0);
      return wrongWay * 0.08;
    }

    double overlapPenaltyForCandidate(
      String nodeId,
      Offset candidate,
      Map<String, Offset> assigned,
    ) {
      final size = sizeByNode[nodeId] ?? const Size(150, 100);
      var penalty = 0.0;
      for (final entry in assigned.entries) {
        final otherSize = sizeByNode[entry.key] ?? const Size(150, 100);
        final other = entry.value;
        final dx = (candidate.dx - other.dx).abs();
        final dy = (candidate.dy - other.dy).abs();
        final requiredX = (size.width + otherSize.width) / 2 + 14;
        final requiredY = (size.height + otherSize.height) / 2 + 12;
        if (dx < requiredX && dy < requiredY) {
          final ox = requiredX - dx;
          final oy = requiredY - dy;
          penalty += 120000 + (ox * ox + oy * oy) * 320;
        }
      }
      return penalty;
    }

    for (final nodeId in placementOrder) {
      final current = positions[nodeId]!;
      int? bestSlot;
      double bestScore = double.infinity;
      for (final slotIndex in freeSlotIndices) {
        final slot = safeSlots[slotIndex];
        final distanceScore = (current - slot).distanceSquared;
        final targetScore =
            (slot - cellTargets[nodeId]!).distanceSquared * 0.35;
        final score =
            distanceScore +
            targetScore +
            directionalPenalty(current, slot) +
            overlapPenaltyForCandidate(nodeId, slot, legalized);
        if (score < bestScore) {
          bestScore = score;
          bestSlot = slotIndex;
        }
      }

      if (bestSlot == null) {
        legalized[nodeId] = current;
      } else {
        freeSlotIndices.remove(bestSlot);
        legalized[nodeId] = safeSlots[bestSlot];
      }
    }

    positions
      ..clear()
      ..addAll(legalized);

    // Short post-legalization relax: preserve slots while shortening wires and reducing crossings.
    for (int iteration = 0; iteration < 28; iteration++) {
      final cooling = 1.0 - (iteration / 32.0);
      for (final id in nodeOrder) {
        forces[id] = Offset.zero;
      }

      for (final edge in undirectedEdges) {
        final a = edge.$1;
        final b = edge.$2;
        final pa = positions[a]!;
        final pb = positions[b]!;
        final delta = pb - pa;
        final dist = math.max(1.0, delta.distance);
        final dir = delta / dist;
        final spring = dir * ((dist - springRest) * (springK * 1.2));
        forces[a] = forces[a]! + spring;
        forces[b] = forces[b]! - spring;
      }

      if (iteration % 2 == 0 && directedEdges.length > 1) {
        for (int i = 0; i < directedEdges.length - 1; i++) {
          final e1 = directedEdges[i];
          for (int j = i + 1; j < directedEdges.length; j++) {
            final e2 = directedEdges[j];
            final shared =
                e1.$1 == e2.$1 ||
                e1.$1 == e2.$2 ||
                e1.$2 == e2.$1 ||
                e1.$2 == e2.$2;
            if (shared) {
              continue;
            }

            final p1 = positions[e1.$1]!;
            final p2 = positions[e1.$2]!;
            final p3 = positions[e2.$1]!;
            final p4 = positions[e2.$2]!;
            if (!_segmentsIntersect(p1, p2, p3, p4)) {
              continue;
            }

            final d1 = p2 - p1;
            final d2 = p4 - p3;
            final n1 = d1.distance > 1e-6
                ? Offset(-d1.dy, d1.dx) / d1.distance
                : const Offset(0, 1);
            final n2 = d2.distance > 1e-6
                ? Offset(-d2.dy, d2.dx) / d2.distance
                : const Offset(0, -1);
            final crossPush = 8.0 * quality.crossingMul;

            forces[e1.$1] = forces[e1.$1]! + n1 * crossPush;
            forces[e1.$2] = forces[e1.$2]! + n1 * crossPush;
            forces[e2.$1] = forces[e2.$1]! + n2 * crossPush;
            forces[e2.$2] = forces[e2.$2]! + n2 * crossPush;
          }
        }
      }

      for (final id in nodeOrder) {
        final anchor = legalized[id]!;
        final current = positions[id]!;
        final force = forces[id]! + (anchor - current) * 0.22;
        final next = current + force * (0.08 * cooling);
        positions[id] = Offset(
          next.dx.clamp(slotMinX, slotMaxX),
          next.dy.clamp(slotMinY, slotMaxY),
        );
      }
    }

    // Final strict snap to unique placement slots for deterministic PCB-like grid alignment.
    final strictSnapped = <String, Offset>{};
    final freeFinalSlots = <int>{for (int i = 0; i < safeSlots.length; i++) i};
    for (final nodeId in placementOrder) {
      final current = positions[nodeId]!;
      int? bestSlot;
      double bestScore = double.infinity;
      for (final slotIndex in freeFinalSlots) {
        final slot = safeSlots[slotIndex];
        final distanceScore = (current - slot).distanceSquared;
        final targetScore =
            (slot - cellTargets[nodeId]!).distanceSquared *
            quality.snapTargetWeight;
        final score =
            distanceScore +
            targetScore +
            directionalPenalty(current, slot) +
            overlapPenaltyForCandidate(nodeId, slot, strictSnapped);
        if (score < bestScore) {
          bestScore = score;
          bestSlot = slotIndex;
        }
      }

      if (bestSlot == null) {
        strictSnapped[nodeId] = current;
      } else {
        freeFinalSlots.remove(bestSlot);
        strictSnapped[nodeId] = safeSlots[bestSlot];
      }
    }

    positions
      ..clear()
      ..addAll(strictSnapped);

    return _packAutoLayoutComponents(
      positions,
      nodeOrder,
      neighbors,
      sizeByNode,
      indexByNode,
      direction,
    );
  }

  Map<String, Offset> _packAutoLayoutComponents(
    Map<String, Offset> positions,
    List<String> nodeOrder,
    Map<String, Set<String>> neighbors,
    Map<String, Size> sizeByNode,
    Map<String, int> indexByNode,
    String direction,
  ) {
    if (positions.isEmpty) {
      return positions;
    }

    final orderedNodes = [...nodeOrder]
      ..sort((a, b) => indexByNode[a]!.compareTo(indexByNode[b]!));

    final visited = <String>{};
    final components = <List<String>>[];
    for (final start in orderedNodes) {
      if (!visited.add(start)) {
        continue;
      }

      final stack = <String>[start];
      final component = <String>[];
      while (stack.isNotEmpty) {
        final nodeId = stack.removeLast();
        component.add(nodeId);
        for (final neighbor in neighbors[nodeId] ?? const <String>{}) {
          if (visited.add(neighbor)) {
            stack.add(neighbor);
          }
        }
      }

      component.sort((a, b) {
        final byDegree = (neighbors[b]?.length ?? 0).compareTo(
          neighbors[a]?.length ?? 0,
        );
        if (byDegree != 0) {
          return byDegree;
        }
        return indexByNode[a]!.compareTo(indexByNode[b]!);
      });
      components.add(component);
    }

    if (components.length <= 1) {
      return positions;
    }

    final quality = _placementQualityProfile();
    final isHorizontal = direction == 'LR' || direction == 'RL';
    final aspectHint = isHorizontal ? 1.38 : 0.82;
    final macroCols = math.max(
      1,
      math.sqrt(components.length * aspectHint).ceil(),
    );

    final componentInfos =
        <
          ({
            List<String> nodes,
            Rect bounds,
            double width,
            double height,
            Offset center,
          })
        >[];
    var widest = 0.0;
    var tallest = 0.0;

    for (final component in components) {
      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = -double.infinity;
      var maxY = -double.infinity;
      var maxNodeW = 150.0;
      var maxNodeH = 100.0;

      for (final nodeId in component) {
        final point = positions[nodeId] ?? Offset.zero;
        final size = sizeByNode[nodeId] ?? const Size(150, 100);
        final halfW = size.width / 2;
        final halfH = size.height / 2;
        minX = math.min(minX, point.dx - halfW);
        minY = math.min(minY, point.dy - halfH);
        maxX = math.max(maxX, point.dx + halfW);
        maxY = math.max(maxY, point.dy + halfH);
        maxNodeW = math.max(maxNodeW, size.width);
        maxNodeH = math.max(maxNodeH, size.height);
      }

      final componentPaddingX = 54.0 + quality.channelPitch * 8.0;
      final componentPaddingY = 42.0 + quality.channelPitch * 6.0;
      final width = math.max(
        360.0,
        (maxX - minX) + maxNodeW + componentPaddingX,
      );
      final height = math.max(
        260.0,
        (maxY - minY) + maxNodeH + componentPaddingY,
      );
      final bounds = Rect.fromLTWH(0, 0, width, height);
      componentInfos.add((
        nodes: component,
        bounds: bounds,
        width: width,
        height: height,
        center: Offset((minX + maxX) / 2, (minY + maxY) / 2),
      ));
      widest = math.max(widest, width);
      tallest = math.max(tallest, height);
    }

    final cellW = math.max(420.0, widest + 72.0);
    final cellH = math.max(300.0, tallest + 72.0);
    final baseX = positions.values
        .map((p) => p.dx)
        .fold<double>(120.0, math.min);
    final baseY = positions.values
        .map((p) => p.dy)
        .fold<double>(90.0, math.min);

    final packed = Map<String, Offset>.from(positions);
    for (int index = 0; index < componentInfos.length; index++) {
      final info = componentInfos[index];
      final targetCol = index % macroCols;
      final targetRow = index ~/ macroCols;
      final targetCenter = Offset(
        baseX + targetCol * cellW + cellW / 2,
        baseY + targetRow * cellH + cellH / 2,
      );
      final translation = targetCenter - info.center;

      for (final nodeId in info.nodes) {
        packed[nodeId] = (packed[nodeId] ?? Offset.zero) + translation;
      }
    }

    final compacted = _compactPackedLayout(
      packed,
      components,
      neighbors,
      sizeByNode,
      direction,
    );
    final packedScore = _layoutQualityScore(
      packed,
      nodeOrder,
      neighbors,
      sizeByNode,
    );
    final compactedScore = _layoutQualityScore(
      compacted,
      nodeOrder,
      neighbors,
      sizeByNode,
    );
    return compactedScore < packedScore ? compacted : packed;
  }

  Map<String, Offset> _compactPackedLayout(
    Map<String, Offset> positions,
    List<List<String>> components,
    Map<String, Set<String>> neighbors,
    Map<String, Size> sizeByNode,
    String direction,
  ) {
    final quality = _placementQualityProfile();
    final compacted = Map<String, Offset>.from(positions);
    final shrink = (direction == 'LR' || direction == 'RL')
        ? (0.94 - quality.channelPitch * 0.02).clamp(0.84, 0.95)
        : (0.92 - quality.channelPitch * 0.02).clamp(0.82, 0.94);

    final originalCenters = <int, Offset>{};
    for (
      int componentIndex = 0;
      componentIndex < components.length;
      componentIndex++
    ) {
      final component = components[componentIndex];
      var sumX = 0.0;
      var sumY = 0.0;
      for (final nodeId in component) {
        final point = compacted[nodeId] ?? Offset.zero;
        sumX += point.dx;
        sumY += point.dy;
      }
      originalCenters[componentIndex] = Offset(
        sumX / math.max(1, component.length),
        sumY / math.max(1, component.length),
      );
    }

    for (int iteration = 0; iteration < 8; iteration++) {
      final forces = <String, Offset>{
        for (final id in compacted.keys) id: Offset.zero,
      };

      for (
        int componentIndex = 0;
        componentIndex < components.length;
        componentIndex++
      ) {
        final component = components[componentIndex];
        final componentSet = component.toSet();
        final componentCenter = originalCenters[componentIndex] ?? Offset.zero;

        for (final nodeId in component) {
          final current = compacted[nodeId] ?? Offset.zero;
          final neighborsInComponent =
              neighbors[nodeId]
                  ?.where(componentSet.contains)
                  .toList(growable: false) ??
              const <String>[];

          if (neighborsInComponent.isNotEmpty) {
            var medianX = 0.0;
            var medianY = 0.0;
            for (final neighbor in neighborsInComponent) {
              final point = compacted[neighbor] ?? Offset.zero;
              medianX += point.dx;
              medianY += point.dy;
            }
            medianX /= neighborsInComponent.length;
            medianY /= neighborsInComponent.length;
            forces[nodeId] =
                forces[nodeId]! +
                Offset(
                  (medianX - current.dx) * 0.022,
                  (medianY - current.dy) * 0.022,
                );
          }

          forces[nodeId] = forces[nodeId]! + (componentCenter - current) * 0.05;
        }

        for (int i = 0; i < component.length - 1; i++) {
          final a = component[i];
          final pa = compacted[a] ?? Offset.zero;
          final sa = sizeByNode[a] ?? const Size(150, 100);
          for (int j = i + 1; j < component.length; j++) {
            final b = component[j];
            final pb = compacted[b] ?? Offset.zero;
            final sb = sizeByNode[b] ?? const Size(150, 100);
            final dx = pa.dx - pb.dx;
            final dy = pa.dy - pb.dy;
            final overlapX = (sa.width + sb.width) / 2 + 18 - dx.abs();
            final overlapY = (sa.height + sb.height) / 2 + 14 - dy.abs();
            if (overlapX > 0 && overlapY > 0) {
              if (overlapX < overlapY) {
                final sx = dx >= 0 ? 1.0 : -1.0;
                final push = sx * overlapX * 0.18;
                forces[a] = forces[a]! + Offset(push, 0);
                forces[b] = forces[b]! - Offset(push, 0);
              } else {
                final sy = dy >= 0 ? 1.0 : -1.0;
                final push = sy * overlapY * 0.18;
                forces[a] = forces[a]! + Offset(0, push);
                forces[b] = forces[b]! - Offset(0, push);
              }
            }
          }
        }
      }

      for (final entry in forces.entries) {
        compacted[entry.key] =
            (compacted[entry.key] ?? Offset.zero) + entry.value * shrink;
      }

      for (
        int componentIndex = 0;
        componentIndex < components.length;
        componentIndex++
      ) {
        final component = components[componentIndex];
        var sumX = 0.0;
        var sumY = 0.0;
        for (final nodeId in component) {
          final point = compacted[nodeId] ?? Offset.zero;
          sumX += point.dx;
          sumY += point.dy;
        }
        final currentCenter = Offset(
          sumX / math.max(1, component.length),
          sumY / math.max(1, component.length),
        );
        final desiredCenter = originalCenters[componentIndex] ?? currentCenter;
        final correction = desiredCenter - currentCenter;
        for (final nodeId in component) {
          compacted[nodeId] = (compacted[nodeId] ?? Offset.zero) + correction;
        }
      }
    }

    return compacted;
  }

  double _layoutQualityScore(
    Map<String, Offset> positions,
    List<String> nodeOrder,
    Map<String, Set<String>> neighbors,
    Map<String, Size> sizeByNode,
  ) {
    if (positions.isEmpty) {
      return 0;
    }

    var score = 0.0;
    final rects = <String, Rect>{};
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    for (final nodeId in nodeOrder) {
      final point = positions[nodeId];
      if (point == null) {
        continue;
      }
      final size = sizeByNode[nodeId] ?? const Size(150, 100);
      final rect = Rect.fromCenter(
        center: point,
        width: size.width,
        height: size.height,
      );
      rects[nodeId] = rect;
      minX = math.min(minX, rect.left);
      minY = math.min(minY, rect.top);
      maxX = math.max(maxX, rect.right);
      maxY = math.max(maxY, rect.bottom);
    }

    for (final nodeId in nodeOrder) {
      final point = positions[nodeId];
      if (point == null) {
        continue;
      }
      for (final neighbor in neighbors[nodeId] ?? const <String>{}) {
        if (nodeId.compareTo(neighbor) >= 0) {
          continue;
        }
        final other = positions[neighbor];
        if (other == null) {
          continue;
        }
        score += (point - other).distance;
      }
    }

    for (int i = 0; i < nodeOrder.length - 1; i++) {
      final a = nodeOrder[i];
      final rectA = rects[a];
      if (rectA == null) {
        continue;
      }
      for (int j = i + 1; j < nodeOrder.length; j++) {
        final b = nodeOrder[j];
        final rectB = rects[b];
        if (rectB == null) {
          continue;
        }
        final overlapX =
            math.min(rectA.right, rectB.right) -
            math.max(rectA.left, rectB.left);
        final overlapY =
            math.min(rectA.bottom, rectB.bottom) -
            math.max(rectA.top, rectB.top);
        if (overlapX > 0 && overlapY > 0) {
          score += 120000 + (overlapX * overlapY * 450);
        }
      }
    }

    final area = math.max(1.0, maxX - minX) * math.max(1.0, maxY - minY);
    score += area * 0.02;
    return score;
  }

  Offset _chooseAnchorUnitTowardRect(
    Rect fromRect,
    Rect toRect, {
    required Map<Offset, int> sideUsage,
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
      final sideLoad = (sideUsage[unit] ?? 0) * 16.0;
      final axisMismatch = horizontalPreferred
          ? (unit.dx.abs() > 0 ? 0.0 : 26.0)
          : (unit.dy.abs() > 0 ? 0.0 : 26.0);
      final flowBias = horizontalPreferred
          ? (delta.dx >= 0
                ? (unit.dx > 0 ? 0.0 : (unit.dx < 0 ? 18.0 : 10.0))
                : (unit.dx < 0 ? 0.0 : (unit.dx > 0 ? 18.0 : 10.0)))
          : (delta.dy >= 0
                ? (unit.dy > 0 ? 0.0 : (unit.dy < 0 ? 18.0 : 10.0))
                : (unit.dy < 0 ? 0.0 : (unit.dy > 0 ? 18.0 : 10.0)));
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

  List<Offset> _routeLinkAroundObstacles({
    required Rect fromRect,
    required Rect toRect,
    required Offset sourceAnchor,
    required Offset targetAnchor,
    required List<Rect> obstacleRects,
  }) {
    final clearance = 24.0;
    final startEdge = _borderPointFromUnit(fromRect, sourceAnchor);
    final endEdge = _borderPointFromUnit(toRect, targetAnchor);
    final start = startEdge + _normalizeAnchorUnit(sourceAnchor) * clearance;
    final end = endEdge + _normalizeAnchorUnit(targetAnchor) * clearance;

    final inflatedObstacles = obstacleRects
        .map((rect) => rect.inflate(clearance))
        .toList(growable: false);
    if (_segmentIntersectsAnyRect(start, end, inflatedObstacles)) {
      // fall back to routing around the obstacles
    } else {
      return const [];
    }

    final xCoords = <double>{start.dx, end.dx};
    final yCoords = <double>{start.dy, end.dy};
    for (final rect in inflatedObstacles) {
      xCoords
        ..add(rect.left)
        ..add(rect.right)
        ..add(rect.center.dx);
      yCoords
        ..add(rect.top)
        ..add(rect.bottom)
        ..add(rect.center.dy);
    }

    final xs = xCoords.toList()..sort();
    final ys = yCoords.toList()..sort();
    if (xs.length < 2 || ys.length < 2) {
      return const [];
    }

    String keyFor(Offset point) =>
        '${point.dx.toStringAsFixed(2)}|${point.dy.toStringAsFixed(2)}';
    final nodeByKey = <String, Offset>{};
    final nodes = <Offset>[];

    for (final x in xs) {
      for (final y in ys) {
        final point = Offset(x, y);
        if (_pointInsideAnyRect(point, inflatedObstacles)) {
          continue;
        }
        final key = keyFor(point);
        nodeByKey[key] = point;
        nodes.add(point);
      }
    }

    final startKey = keyFor(start);
    final endKey = keyFor(end);
    nodeByKey[startKey] = start;
    nodeByKey[endKey] = end;
    if (!nodes.any((p) => p == start)) {
      nodes.add(start);
    }
    if (!nodes.any((p) => p == end)) {
      nodes.add(end);
    }

    final adjacency = <String, List<(String, double)>>{
      for (final point in nodes) keyFor(point): <(String, double)>[],
    };

    double segmentPenalty(Offset a, Offset b) {
      final length = (a - b).distance;
      final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      var penalty = 0.0;
      for (final rect in inflatedObstacles) {
        final distance = _distancePointToRect(midpoint, rect);
        if (distance < 0) {
          return double.infinity;
        }
        if (distance < 52.0) {
          penalty += (52.0 - distance) * 5.0;
        }
      }
      return length + penalty;
    }

    bool clearSegment(Offset a, Offset b) {
      for (final rect in inflatedObstacles) {
        if (_segmentIntersectsRect(a, b, rect)) {
          return false;
        }
      }
      return true;
    }

    for (int yIndex = 0; yIndex < ys.length; yIndex++) {
      for (int xIndex = 0; xIndex < xs.length - 1; xIndex++) {
        final left = Offset(xs[xIndex], ys[yIndex]);
        final right = Offset(xs[xIndex + 1], ys[yIndex]);
        final leftKey = keyFor(left);
        final rightKey = keyFor(right);
        if (nodeByKey[leftKey] == null || nodeByKey[rightKey] == null) {
          continue;
        }
        if (!clearSegment(left, right)) {
          continue;
        }
        final cost = segmentPenalty(left, right);
        if (!cost.isFinite) {
          continue;
        }
        adjacency[leftKey]!.add((rightKey, cost));
        adjacency[rightKey]!.add((leftKey, cost));
      }
    }

    for (int xIndex = 0; xIndex < xs.length; xIndex++) {
      for (int yIndex = 0; yIndex < ys.length - 1; yIndex++) {
        final top = Offset(xs[xIndex], ys[yIndex]);
        final bottom = Offset(xs[xIndex], ys[yIndex + 1]);
        final topKey = keyFor(top);
        final bottomKey = keyFor(bottom);
        if (nodeByKey[topKey] == null || nodeByKey[bottomKey] == null) {
          continue;
        }
        if (!clearSegment(top, bottom)) {
          continue;
        }
        final cost = segmentPenalty(top, bottom);
        if (!cost.isFinite) {
          continue;
        }
        adjacency[topKey]!.add((bottomKey, cost));
        adjacency[bottomKey]!.add((topKey, cost));
      }
    }

    final frontier = <(String, double)>[(startKey, 0.0)];
    final cameFrom = <String, String>{};
    final gScore = <String, double>{startKey: 0.0};

    double heuristic(String key) {
      final point = nodeByKey[key];
      if (point == null) {
        return double.infinity;
      }
      return (point - end).distance;
    }

    while (frontier.isNotEmpty) {
      frontier.sort((a, b) => a.$2.compareTo(b.$2));
      final current = frontier.removeAt(0).$1;
      if (current == endKey) {
        break;
      }

      for (final neighbor in adjacency[current] ?? const <(String, double)>[]) {
        final tentative = (gScore[current] ?? double.infinity) + neighbor.$2;
        if (tentative >= (gScore[neighbor.$1] ?? double.infinity)) {
          continue;
        }
        cameFrom[neighbor.$1] = current;
        gScore[neighbor.$1] = tentative;
        frontier.add((neighbor.$1, tentative + heuristic(neighbor.$1)));
      }
    }

    if (!cameFrom.containsKey(endKey)) {
      return const [];
    }

    final route = <Offset>[end];
    var currentKey = endKey;
    while (currentKey != startKey) {
      currentKey = cameFrom[currentKey]!;
      route.add(nodeByKey[currentKey]!);
    }
    route.add(start);
    final ordered = route.reversed.toList();
    final simplified = _simplifyRoutedPath(ordered);
    if (simplified.length <= 2) {
      return const [];
    }
    return simplified.sublist(1, simplified.length - 1);
  }

  bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    if (a.dx == b.dx) {
      final x = a.dx;
      if (x < rect.left || x > rect.right) {
        return false;
      }
      final minY = math.min(a.dy, b.dy);
      final maxY = math.max(a.dy, b.dy);
      return maxY > rect.top && minY < rect.bottom;
    }

    if (a.dy == b.dy) {
      final y = a.dy;
      if (y < rect.top || y > rect.bottom) {
        return false;
      }
      final minX = math.min(a.dx, b.dx);
      final maxX = math.max(a.dx, b.dx);
      return maxX > rect.left && minX < rect.right;
    }

    return false;
  }

  bool _pointInsideAnyRect(Offset point, List<Rect> rects) {
    for (final rect in rects) {
      if (rect.contains(point)) {
        return true;
      }
    }
    return false;
  }

  double _distancePointToRect(Offset point, Rect rect) {
    if (rect.contains(point)) {
      return -1;
    }
    final dx = math.max(
      0.0,
      math.max(rect.left - point.dx, point.dx - rect.right),
    );
    final dy = math.max(
      0.0,
      math.max(rect.top - point.dy, point.dy - rect.bottom),
    );
    return math.sqrt(dx * dx + dy * dy);
  }

  bool _segmentIntersectsAnyRect(Offset a, Offset b, List<Rect> rects) {
    for (final rect in rects) {
      if (_segmentIntersectsRect(a, b, rect)) {
        return true;
      }
    }
    return false;
  }

  List<Offset> _simplifyRoutedPath(List<Offset> points) {
    if (points.length <= 2) {
      return points;
    }

    final simplified = <Offset>[points.first];
    for (int i = 1; i < points.length - 1; i++) {
      final prev = simplified.last;
      final current = points[i];
      final next = points[i + 1];
      final sameX =
          (prev.dx - current.dx).abs() < 0.5 &&
          (current.dx - next.dx).abs() < 0.5;
      final sameY =
          (prev.dy - current.dy).abs() < 0.5 &&
          (current.dy - next.dy).abs() < 0.5;
      if (sameX || sameY) {
        continue;
      }
      simplified.add(current);
    }
    simplified.add(points.last);
    return simplified;
  }

  bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    double cross(Offset u, Offset v) => u.dx * v.dy - u.dy * v.dx;

    final ab = b - a;
    final ac = c - a;
    final ad = d - a;
    final cd = d - c;
    final ca = a - c;
    final cb = b - c;

    final o1 = cross(ab, ac);
    final o2 = cross(ab, ad);
    final o3 = cross(cd, ca);
    final o4 = cross(cd, cb);

    const eps = 1e-8;
    final proper =
        ((o1 > eps && o2 < -eps) || (o1 < -eps && o2 > eps)) &&
        ((o3 > eps && o4 < -eps) || (o3 < -eps && o4 > eps));
    return proper;
  }

  String _extractMermaidDirection(String source) {
    final match = RegExp(
      r'^(?:flowchart|graph)\s+([A-Za-z]{2})\b',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(source);
    if (match == null) {
      return _mermaidLayoutDirection;
    }

    final parsed = (match.group(1) ?? '').toUpperCase();
    if (parsed == 'TD') {
      return 'TB';
    }
    if (_mermaidDirections.contains(parsed)) {
      return parsed;
    }
    return _mermaidLayoutDirection;
  }

  void _reorganizeGraphLayout() {
    if (blocks.isEmpty) {
      return;
    }

    setState(() {
      _runAutoLayoutOnGraph(
        blocks,
        links,
        _mermaidLayoutDirection,
        preserveCurrentPositions: true,
      );
    });
  }

  void _applyAutoLayoutLinkGeometry(
    List<Block> targetBlocks,
    List<BlockLink> targetLinks,
  ) {
    final blockById = <String, Block>{
      for (final block in targetBlocks) block.id: block,
    };
    final rectById = <String, Rect>{
      for (final block in targetBlocks)
        block.id: Rect.fromLTWH(
          block.position.dx,
          block.position.dy,
          block.size.width,
          block.size.height,
        ),
    };
    final sideUsageByBlock = <String, Map<Offset, int>>{};

    double orderKeyForSide(Offset side, Offset otherCenter) {
      if (side.dx.abs() >= side.dy.abs()) {
        return otherCenter.dy;
      }
      return otherCenter.dx;
    }

    for (final link in targetLinks) {
      final fromBlock = blockById[link.fromBlockId];
      final toBlock = blockById[link.toBlockId];
      final fromRect = rectById[link.fromBlockId];
      final toRect = rectById[link.toBlockId];
      if (fromBlock == null ||
          toBlock == null ||
          fromRect == null ||
          toRect == null) {
        continue;
      }

      final sourceUsage = sideUsageByBlock.putIfAbsent(
        fromBlock.id,
        () => <Offset, int>{},
      );
      final targetUsage = sideUsageByBlock.putIfAbsent(
        toBlock.id,
        () => <Offset, int>{},
      );

      final sourceAnchor =
          link.isSourceAnchorLocked && link.sourceAnchorUnit != null
          ? _normalizeAnchorUnit(link.sourceAnchorUnit!)
          : _chooseAnchorUnitTowardRect(
              fromRect,
              toRect,
              sideUsage: sourceUsage,
            );
      final targetAnchor =
          link.isTargetAnchorLocked && link.targetAnchorUnit != null
          ? _normalizeAnchorUnit(link.targetAnchorUnit!)
          : _chooseAnchorUnitTowardRect(
              toRect,
              fromRect,
              sideUsage: targetUsage,
            );

      final obstacleRects = <Rect>[
        for (final block in targetBlocks)
          if (block.id != fromBlock.id && block.id != toBlock.id)
            Rect.fromLTWH(
              block.position.dx,
              block.position.dy,
              block.size.width,
              block.size.height,
            ).inflate(20.0),
      ];

      final routedInflections = _routeLinkAroundObstacles(
        fromRect: fromRect,
        toRect: toRect,
        sourceAnchor: sourceAnchor,
        targetAnchor: targetAnchor,
        obstacleRects: obstacleRects,
      );

      link.connectorType = ConnectorType.bezier;
      link.inflectionPoints
        ..clear()
        ..addAll(routedInflections);
      link.isSourceAnchorLocked = false;
      link.isTargetAnchorLocked = false;
      link.sourceAnchorUnit = sourceAnchor;
      link.targetAnchorUnit = targetAnchor;
      link.sourceAnchorOrderKey = orderKeyForSide(sourceAnchor, toRect.center);
      link.targetAnchorOrderKey = orderKeyForSide(
        targetAnchor,
        fromRect.center,
      );

      sourceUsage[sourceAnchor] = (sourceUsage[sourceAnchor] ?? 0) + 1;
      targetUsage[targetAnchor] = (targetUsage[targetAnchor] ?? 0) + 1;
    }
  }

  void _ensureBlockHasSpaceForAnchorsInGraph(
    Block block,
    List<BlockLink> graphLinks,
  ) {
    int leftCount = 0;
    int rightCount = 0;
    int topCount = 0;
    int bottomCount = 0;

    for (final link in graphLinks) {
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

  void _runAutoLayoutOnGraph(
    List<Block> targetBlocks,
    List<BlockLink> targetLinks,
    String direction, {
    bool preserveCurrentPositions = false,
  }) {
    if (targetBlocks.isEmpty) {
      return;
    }

    _applyAutoLayoutLinkGeometry(targetBlocks, targetLinks);
    for (final block in targetBlocks) {
      _ensureBlockHasSpaceForAnchorsInGraph(block, targetLinks);
    }

    final nodeOrder = targetBlocks.map((b) => b.id).toList();
    final edgeData = targetLinks
        .map((l) => (fromId: l.fromBlockId, toId: l.toBlockId, label: l.name))
        .toList();
    final positions = _computeMermaidAutoLayout(
      nodeOrder,
      edgeData,
      direction,
      targetBlocks,
      seedPositions: preserveCurrentPositions
          ? {for (final block in targetBlocks) block.id: block.position}
          : null,
    );

    for (final block in targetBlocks) {
      final position = positions[block.id];
      if (position != null) {
        block.position = position;
      }
    }

    _applyAutoLayoutLinkGeometry(targetBlocks, targetLinks);
    for (final block in targetBlocks) {
      _ensureBlockHasSpaceForAnchorsInGraph(block, targetLinks);
    }
  }

  void _importMermaid(String text) {
    final source = _extractMermaidSource(text);
    if (source.isEmpty) {
      throw const FormatException('Le code Mermaid est vide');
    }
    final layoutDirection = _extractMermaidDirection(source);

    final lines = source.split(RegExp(r'\r?\n'));
    final nodeTitles = <String, String>{};
    final nodeOrder = <String>[];
    final edgeData = <({String fromId, String toId, String label})>[];

    void registerNode(String nodeId, [String? title]) {
      if (!nodeOrder.contains(nodeId)) {
        nodeOrder.add(nodeId);
      }
      if (title != null && title.isNotEmpty) {
        nodeTitles[nodeId] = _normalizeBlockTitleLineBreaks(title);
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
          position: Offset(120 + (i % 4) * 240, 100 + (i ~/ 4) * 170),
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

    _runAutoLayoutOnGraph(importedBlocks, importedLinks, layoutDirection);

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

      for (final block in blocks) {
        _ensureBlockHasSpaceForAnchors(block);
      }
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
          PopupMenuButton<String>(
            tooltip: 'Direction Mermaid ($_mermaidLayoutDirection)',
            onSelected: (value) {
              setState(() {
                _mermaidLayoutDirection = value;
              });
            },
            itemBuilder: (context) {
              return _mermaidDirections
                  .map(
                    (direction) => CheckedPopupMenuItem<String>(
                      value: direction,
                      checked: _mermaidLayoutDirection == direction,
                      child: Text('Direction $direction'),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.swap_horiz),
          ),
          PopupMenuButton<String>(
            tooltip: 'Qualite placement ($_placementQuality)',
            onSelected: (value) {
              setState(() {
                _placementQuality = value;
              });
            },
            itemBuilder: (context) {
              return _placementQualities
                  .map(
                    (quality) => CheckedPopupMenuItem<String>(
                      value: quality,
                      checked: _placementQuality == quality,
                      child: Text(quality),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Réorganiser le graphe',
            onPressed: _reorganizeGraphLayout,
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
