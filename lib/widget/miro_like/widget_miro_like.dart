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
import 'auto_layout_engine.dart';
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
const double anchorSpacingDistance = 35.0;
const double anchorBorderMarginDistance = 50.0;
const double _minBlockWidth = 200.0;
const double _minBlockHeight = 150.0;
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
  static const List<String> _blockSpacingModes = [
    'Dense',
    'Normal',
    'Plus ecarte',
  ];
  static const List<String> _alignmentPriorityModes = [
    'Normal',
    'Fort',
    'Extreme',
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
  String _blockSpacingMode = 'Dense';
  String _alignmentPriorityMode = 'Fort';
  double? _snapLeftModel;
  double? _snapTopModel;
  Offset? _dragFreePositionModel;

  double _blockSpacingMultiplier() {
    switch (_blockSpacingMode) {
      case 'Dense':
        return 0.30;
      case 'Plus ecarte':
        return 1.55;
      case 'Normal':
      default:
        return 0.70;
    }
  }

  double _alignmentPriorityMultiplier() {
    switch (_alignmentPriorityMode) {
      case 'Normal':
        return 0;
      case 'Fort':
        return 0.5;
      case 'Extreme':
      default:
        return 2.0;
    }
  }

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
      Block(
        id: '1',
        title: 'Block 1',
        position: const Offset(100, 100),
        size: const Size(_minBlockWidth, _minBlockHeight),
      ),
      Block(
        id: '2',
        title: 'Block 2',
        position: const Offset(350, 100),
        size: const Size(_minBlockWidth, _minBlockHeight),
      ),
      Block(
        id: '3',
        title: 'Block 3',
        position: const Offset(225, 300),
        size: const Size(_minBlockWidth, _minBlockHeight),
      ),
    ]);
  }

  void _addBlock(Offset position) {
    setState(() {
      blocks.add(
        Block(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Block ${blocks.length + 1}',
          position: (position - canvasOffset) / zoomLevel,
          size: const Size(_minBlockWidth, _minBlockHeight),
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

  void _handleBlockTagsChanged(Block block, List<String> tagColorKeys) {
    setState(() {
      block.tagColorKeys
        ..clear()
        ..addAll(
          tagColorKeys.where((key) => kBlockTagColorMap.containsKey(key)),
        );
    });
  }

  void _handleBlockIconBase64Changed(Block block, String value) {
    setState(() {
      final trimmed = value.trim();
      block.iconBase64 = trimmed.isEmpty ? null : trimmed;
      _normalizeBlockIconStorage(block);
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
    setState(() {
      final trimmed = rawJson.trim();
      if (trimmed.isEmpty) {
        block.propertiesJson = null;
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

  void _fitToViewAfterNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _fitToView();
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
      'colorKey': block.colorKey,
      'tagColorKeys': block.tagColorKeys,
      'iconBase64': block.iconBase64,
      'propertiesJson': block.propertiesJson,
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
          colorKey: item['colorKey']?.toString(),
          tagColorKeys: parsedTagColorKeys,
          iconBase64: item['iconBase64']?.toString(),
          propertiesJson: item['propertiesJson']?.toString(),
          position: _offsetFromJson(item['position']),
          size: _sizeFromJson(item['size']),
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
    final effectiveBlocks = layoutBlocks ?? blocks;
    final quality = _placementQualityProfile();
    return AutoLayoutEngine.computeMermaidAutoLayout(
      nodeOrder: nodeOrder,
      edgeData: edgeData,
      direction: direction,
      effectiveBlocks: effectiveBlocks,
      quality: AutoLayoutQualityProfile(
        iterationMul: quality.iterationMul,
        repulsionMul: quality.repulsionMul,
        springMul: quality.springMul,
        overlapMul: quality.overlapMul,
        hpwlMul: quality.hpwlMul,
        crossingMul: quality.crossingMul,
        spacingMul: _blockSpacingMultiplier(),
        channelPitch: quality.channelPitch,
        snapTargetWeight: quality.snapTargetWeight,
        alignmentPriority: _alignmentPriorityMultiplier(),
      ),
      seedPositions: seedPositions,
    );
  }

  Offset _chooseAnchorUnitTowardRect(
    Rect fromRect,
    Rect toRect, {
    required Map<Offset, int> sideUsage,
    bool isHub = false,
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
      final baseSideLoad = (sideUsage[unit] ?? 0);
      final sideLoad = isHub
          ? baseSideLoad * 6.0 + (baseSideLoad > 0 ? 8.0 : 0.0)
          : baseSideLoad * 16.0;
      final axisMismatch = horizontalPreferred
          ? (unit.dx.abs() > 0 ? 0.0 : 26.0)
          : (unit.dy.abs() > 0 ? 0.0 : 26.0);
      final flowBias = horizontalPreferred
          ? (delta.dx >= 0
                ? (unit.dx > 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dx < 0 ? (isHub ? 16.0 : 18.0) : 10.0))
                : (unit.dx < 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dx > 0 ? (isHub ? 16.0 : 18.0) : 10.0)))
          : (delta.dy >= 0
                ? (unit.dy > 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dy < 0 ? (isHub ? 16.0 : 18.0) : 10.0))
                : (unit.dy < 0
                      ? (isHub ? 4.0 : 0.0)
                      : (unit.dy > 0 ? (isHub ? 16.0 : 18.0) : 10.0)));
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

      final isColinear = _isColinear(prev, current, next, tolerance: 1.5);
      if (isColinear) {
        continue;
      }

      simplified.add(current);
    }
    simplified.add(points.last);
    return _mergeOscillatingSegments(simplified);
  }

  bool _isColinear(Offset a, Offset b, Offset c, {double tolerance = 0.5}) {
    final ab = b - a;
    final ac = c - a;
    if (ab.distanceSquared == 0 || ac.distanceSquared == 0) {
      return true;
    }

    final crossProduct = (ab.dx * ac.dy - ab.dy * ac.dx).abs();
    final combinedLength = ab.distance * ac.distance;
    if (combinedLength == 0) {
      return true;
    }

    return (crossProduct / combinedLength) < tolerance;
  }

  List<Offset> _mergeOscillatingSegments(List<Offset> points) {
    if (points.length <= 3) {
      return points;
    }

    final merged = <Offset>[points.first];
    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      if (merged.length < 2) {
        merged.add(current);
        continue;
      }

      final prev = merged.last;
      final prevPrev = merged[merged.length - 2];
      final distCurrentPrev = (current - prev).distance;
      final distPrevPrevPrev = (prev - prevPrev).distance;

      if (distCurrentPrev < 8.0 || distPrevPrevPrev < 8.0) {
        final dirPrevPrev = math.atan2(
          prev.dy - prevPrev.dy,
          prev.dx - prevPrev.dx,
        );
        final dirCurrent = math.atan2(
          current.dy - prev.dy,
          current.dx - prev.dx,
        );
        final angleDiff = (dirCurrent - dirPrevPrev).abs();
        final normalizedDiff = math.min(angleDiff, 2 * math.pi - angleDiff);

        if (normalizedDiff < 0.3 || normalizedDiff > math.pi - 0.3) {
          merged[merged.length - 1] = current;
          continue;
        }
      }

      merged.add(current);
    }

    return merged;
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

    final degreeByNode = <String, int>{
      for (final block in targetBlocks) block.id: 0,
    };
    for (final link in targetLinks) {
      degreeByNode[link.fromBlockId] =
          (degreeByNode[link.fromBlockId] ?? 0) + 1;
      degreeByNode[link.toBlockId] = (degreeByNode[link.toBlockId] ?? 0) + 1;
    }

    final hubThreshold = math.max(
      2,
      (targetLinks.length / targetBlocks.length).ceil(),
    );
    final hubs = <String>{
      for (final entry in degreeByNode.entries)
        if (entry.value >= hubThreshold) entry.key,
    };

    final sideUsageByBlock = <String, Map<Offset, int>>{};
    final sortedLinksForBlock = <String, List<BlockLink>>{
      for (final block in targetBlocks) block.id: <BlockLink>[],
    };

    for (final link in targetLinks) {
      sortedLinksForBlock[link.fromBlockId]!.add(link);
      sortedLinksForBlock[link.toBlockId]!.add(link);
    }

    for (final entry in sortedLinksForBlock.entries) {
      entry.value.sort((a, b) {
        final aOtherId = a.fromBlockId == entry.key
            ? a.toBlockId
            : a.fromBlockId;
        final bOtherId = b.fromBlockId == entry.key
            ? b.toBlockId
            : b.fromBlockId;
        return aOtherId.compareTo(bOtherId);
      });
    }

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

      final isSourceHub = hubs.contains(fromBlock.id);
      final isTargetHub = hubs.contains(toBlock.id);

      final sourceAnchor =
          link.isSourceAnchorLocked && link.sourceAnchorUnit != null
          ? _normalizeAnchorUnit(link.sourceAnchorUnit!)
          : _chooseAnchorUnitTowardRect(
              fromRect,
              toRect,
              sideUsage: sourceUsage,
              isHub: isSourceHub,
            );
      final targetAnchor =
          link.isTargetAnchorLocked && link.targetAnchorUnit != null
          ? _normalizeAnchorUnit(link.targetAnchorUnit!)
          : _chooseAnchorUnitTowardRect(
              toRect,
              fromRect,
              sideUsage: targetUsage,
              isHub: isTargetHub,
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

    _recomputeAutoLayoutAnchorOrderKeys(targetBlocks, targetLinks);
  }

  void _recomputeAutoLayoutAnchorOrderKeys(
    List<Block> targetBlocks,
    List<BlockLink> targetLinks,
  ) {
    final blockById = <String, Block>{
      for (final block in targetBlocks) block.id: block,
    };

    final groups =
        <
          String,
          List<
            ({BlockLink link, bool isSource, double projection, int tieBreak})
          >
        >{};

    void pushGroup(
      String blockId,
      Offset side,
      BlockLink link,
      bool isSource,
      double projection,
      int tieBreak,
    ) {
      final key =
          '${blockId}|${side.dx.toStringAsFixed(0)}|${side.dy.toStringAsFixed(0)}';
      groups.putIfAbsent(
        key,
        () =>
            <
              ({BlockLink link, bool isSource, double projection, int tieBreak})
            >[],
      );
      groups[key]!.add((
        link: link,
        isSource: isSource,
        projection: projection,
        tieBreak: tieBreak,
      ));
    }

    double sideProjection(Offset side, Offset ownCenter, Offset otherCenter) {
      final delta = otherCenter - ownCenter;
      if (side.dx != 0) {
        return delta.dy;
      }
      return delta.dx;
    }

    Offset centerOf(Block block) {
      return Offset(
        block.position.dx + block.size.width / 2,
        block.position.dy + block.size.height / 2,
      );
    }

    for (int i = 0; i < targetLinks.length; i++) {
      final link = targetLinks[i];
      final fromBlock = blockById[link.fromBlockId];
      final toBlock = blockById[link.toBlockId];
      if (fromBlock == null || toBlock == null) {
        continue;
      }

      if (link.sourceAnchorUnit != null) {
        final side = _anchorSideUnit(link.sourceAnchorUnit!);
        final projection = sideProjection(
          side,
          centerOf(fromBlock),
          centerOf(toBlock),
        );
        pushGroup(link.fromBlockId, side, link, true, projection, i);
      }

      if (link.targetAnchorUnit != null) {
        final side = _anchorSideUnit(link.targetAnchorUnit!);
        final projection = sideProjection(
          side,
          centerOf(toBlock),
          centerOf(fromBlock),
        );
        pushGroup(link.toBlockId, side, link, false, projection, i);
      }
    }

    for (final entries in groups.values) {
      entries.sort((a, b) {
        final byProjection = a.projection.compareTo(b.projection);
        if (byProjection != 0) {
          return byProjection;
        }
        return a.tieBreak.compareTo(b.tieBreak);
      });

      for (int idx = 0; idx < entries.length; idx++) {
        final entry = entries[idx];
        final key = idx.toDouble();
        if (entry.isSource) {
          entry.link.sourceAnchorOrderKey = key;
        } else {
          entry.link.targetAnchorOrderKey = key;
        }
      }
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
    final newWidth = math.max(_minBlockWidth, requiredModelWidth);
    final newHeight = math.max(_minBlockHeight, requiredModelHeight);

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
          size: const Size(_minBlockWidth, _minBlockHeight),
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

    _fitToViewAfterNextFrame();
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

    _fitToViewAfterNextFrame();
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
    final dirtyAnchorSideKeys = <String>{};

    void markDirtySide(String blockId, Offset side) {
      dirtyAnchorSideKeys.add(
        '${blockId}|${side.dx.toStringAsFixed(0)}|${side.dy.toStringAsFixed(0)}',
      );
    }

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
            final previousSourceSide = link.sourceAnchorUnit == null
                ? null
                : _anchorSideUnit(link.sourceAnchorUnit!);
            final newAnchor = _calculateOptimalAnchorUnit(
              sourceRect,
              targetRect,
            );
            link.sourceAnchorUnit = newAnchor;
            final newSourceSide = _anchorSideUnit(newAnchor);
            if (previousSourceSide == null ||
                previousSourceSide != newSourceSide) {
              markDirtySide(link.fromBlockId, newSourceSide);
              if (link.targetAnchorUnit != null) {
                markDirtySide(
                  link.toBlockId,
                  _anchorSideUnit(link.targetAnchorUnit!),
                );
              }
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
            final previousTargetSide = link.targetAnchorUnit == null
                ? null
                : _anchorSideUnit(link.targetAnchorUnit!);
            final newAnchor = _calculateOptimalAnchorUnit(
              targetRect,
              sourceRect,
            );
            link.targetAnchorUnit = newAnchor;
            final newTargetSide = _anchorSideUnit(newAnchor);
            if (previousTargetSide == null ||
                previousTargetSide != newTargetSide) {
              markDirtySide(link.toBlockId, newTargetSide);
              if (link.sourceAnchorUnit != null) {
                markDirtySide(
                  link.fromBlockId,
                  _anchorSideUnit(link.sourceAnchorUnit!),
                );
              }
            }
          }
        }
      }

      final blockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        _ensureBlockHasSpaceForAnchors(blocks[blockIndex]);
      }
    }

    for (final dirtyKey in dirtyAnchorSideKeys) {
      final parts = dirtyKey.split('|');
      if (parts.length != 3) {
        continue;
      }
      final blockId = parts[0];
      final side = Offset(
        double.tryParse(parts[1]) ?? 0,
        double.tryParse(parts[2]) ?? 0,
      );
      final anchorBlockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (anchorBlockIndex == -1) {
        continue;
      }
      _recomputeAnchorOrderKeysForBlockSide(blocks[anchorBlockIndex], side);
    }
  }

  void _recomputeAnchorOrderKeysForBlockSide(Block block, Offset side) {
    final sideAnchors =
        <({BlockLink link, bool isSource, double sortKey, int linkIndex})>[];

    double orderKeyFromOtherBlockCenter(Offset otherCenter) {
      if (side.dx.abs() >= side.dy.abs()) {
        return otherCenter.dy;
      }
      return otherCenter.dx;
    }

    for (int i = 0; i < links.length; i++) {
      final link = links[i];
      if (link.fromBlockId == block.id && link.sourceAnchorUnit != null) {
        final currentSide = _anchorSideUnit(link.sourceAnchorUnit!);
        if (currentSide == side) {
          final otherIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
          if (otherIndex == -1) {
            continue;
          }
          sideAnchors.add((
            link: link,
            isSource: true,
            sortKey: orderKeyFromOtherBlockCenter(
              _blockRectCanvas(blocks[otherIndex]).center,
            ),
            linkIndex: i,
          ));
        }
      }

      if (link.toBlockId == block.id && link.targetAnchorUnit != null) {
        final currentSide = _anchorSideUnit(link.targetAnchorUnit!);
        if (currentSide == side) {
          final otherIndex = blocks.indexWhere((b) => b.id == link.fromBlockId);
          if (otherIndex == -1) {
            continue;
          }
          sideAnchors.add((
            link: link,
            isSource: false,
            sortKey: orderKeyFromOtherBlockCenter(
              _blockRectCanvas(blocks[otherIndex]).center,
            ),
            linkIndex: i,
          ));
        }
      }
    }

    sideAnchors.sort((a, b) {
      final bySortKey = a.sortKey.compareTo(b.sortKey);
      if (bySortKey != 0) {
        return bySortKey;
      }
      return a.linkIndex.compareTo(b.linkIndex);
    });

    for (int i = 0; i < sideAnchors.length; i++) {
      final entry = sideAnchors[i];
      final orderKey = i.toDouble();
      if (entry.isSource) {
        entry.link.sourceAnchorOrderKey = orderKey;
      } else {
        entry.link.targetAnchorOrderKey = orderKey;
      }
    }
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

  double _stabilizeDraggedOrderKey({
    required double rawKey,
    required double? previousKey,
  }) {
    final spacingDistance = anchorSpacingDistance * zoomLevel;
    if (spacingDistance <= 0) {
      return rawKey;
    }

    // Keep a small dead zone to avoid jittery neighbor swaps while dragging.
    final hysteresis = spacingDistance * 0.35;
    if (previousKey != null && (rawKey - previousKey).abs() < hysteresis) {
      return previousKey;
    }
    return rawKey;
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

    // Compute in canvas units so converting back to model stays zoom-invariant.
    final spacingDistance = anchorSpacingDistance * zoomLevel;
    final sidePadding = anchorBorderMarginDistance * zoomLevel;
    return (count - 1) * spacingDistance + (2 * sidePadding);
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
    final newWidth = math.max(_minBlockWidth, requiredModelWidth);
    final newHeight = math.max(_minBlockHeight, requiredModelHeight);

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
    final blockIndex = blocks.indexWhere((b) => b.id == blockId);
    if (blockIndex == -1) {
      return Offset.zero;
    }
    final rect = _blockRectCanvas(blocks[blockIndex]);
    final currentLinkIndex = links.indexOf(currentLink);
    if (currentLinkIndex == -1) {
      return Offset.zero;
    }

    final sameSideEntries = <(int linkIndex, double key)>[];
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
      sameSideEntries.add((
        i,
        _anchorOrderKeyForLinkSide(link, blockId, side, i),
      ));
    }
    if (sameSideEntries.isEmpty) {
      return Offset.zero;
    }

    sameSideEntries.sort((a, b) {
      final byKey = a.$2.compareTo(b.$2);
      if (byKey != 0) {
        return byKey;
      }
      return a.$1.compareTo(b.$1);
    });

    final rawKeys = sameSideEntries.map((e) => e.$2).toList(growable: false);
    final separatedKeys = List<double>.from(rawKeys);
    for (int i = 1; i < separatedKeys.length; i++) {
      final minNext = separatedKeys[i - 1] + spacingDistance;
      if (separatedKeys[i] < minNext) {
        separatedKeys[i] = minNext;
      }
    }

    final rawCenter = rawKeys.fold(0.0, (acc, v) => acc + v) / rawKeys.length;
    final separatedCenter =
        separatedKeys.fold(0.0, (acc, v) => acc + v) / separatedKeys.length;
    var centerOffset =
        separatedKeys[sameSideEntries.indexWhere(
          (e) => e.$1 == currentLinkIndex,
        )] +
        (rawCenter - separatedCenter);

    final edgeMargin = (_anchorHandleRadius * zoomLevel).clamp(
      3.0,
      _anchorHandleRadius,
    );
    final halfExtent = side.dx != 0 ? rect.height / 2 : rect.width / 2;
    final clampedCenterOffset = centerOffset
        .clamp(
          -math.max(0.0, halfExtent - edgeMargin),
          math.max(0.0, halfExtent - edgeMargin),
        )
        .toDouble();

    // Apply spacing parallel to the anchor side
    if (side.dx != 0) {
      // Horizontal side (left/right) - space vertically
      return Offset(0, clampedCenterOffset);
    } else if (side.dy != 0) {
      // Vertical side (top/bottom) - space horizontally
      return Offset(clampedCenterOffset, 0);
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

    return path;
  }

  Offset _outwardTangentForLinkEndpoint(
    BlockLink link, {
    required bool isSource,
    required Rect rect,
    required Offset edgePoint,
  }) {
    final anchorUnit = isSource ? link.sourceAnchorUnit : link.targetAnchorUnit;
    if (anchorUnit != null) {
      return _anchorSideUnit(anchorUnit);
    }
    return axisNormalForBorderPoint(rect, edgePoint);
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
      final width = math.max(
        90.0 * textScale,
        link.name.length * 8.0 * textScale + 28.0 * textScale + iconExtraWidth,
      );
      final height = 32.0 * textScale;

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
              final snappedSide = _anchorSideUnit(
                _anchorUnitFromCanvasPoint(fromRect, canvasPosition),
              );
              link.sourceAnchorUnit = snappedSide;
              final rawKey = _anchorOrderKeyFromCanvasPoint(
                fromRect,
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
              final snappedSide = _anchorSideUnit(
                _anchorUnitFromCanvasPoint(toRect, canvasPosition),
              );
              link.targetAnchorUnit = snappedSide;
              final rawKey = _anchorOrderKeyFromCanvasPoint(
                toRect,
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
          PopupMenuButton<String>(
            tooltip: 'Ecart blocs ($_blockSpacingMode)',
            onSelected: (value) {
              setState(() {
                _blockSpacingMode = value;
              });
            },
            itemBuilder: (context) {
              return _blockSpacingModes
                  .map(
                    (spacing) => CheckedPopupMenuItem<String>(
                      value: spacing,
                      checked: _blockSpacingMode == spacing,
                      child: Text(spacing),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.space_bar),
          ),
          PopupMenuButton<String>(
            tooltip: 'Priorite alignement ($_alignmentPriorityMode)',
            onSelected: (value) {
              setState(() {
                _alignmentPriorityMode = value;
              });
            },
            itemBuilder: (context) {
              return _alignmentPriorityModes
                  .map(
                    (mode) => CheckedPopupMenuItem<String>(
                      value: mode,
                      checked: _alignmentPriorityMode == mode,
                      child: Text(mode),
                    ),
                  )
                  .toList();
            },
            icon: const Icon(Icons.align_horizontal_left),
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
            onBlockTagsChanged: _handleBlockTagsChanged,
            onBlockIconBase64Changed: _handleBlockIconBase64Changed,
            onBlockPropertiesJsonChanged: _handleBlockPropertiesJsonChanged,
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
