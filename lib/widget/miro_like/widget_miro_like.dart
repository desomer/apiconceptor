import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/widget/miro_like/block_widget.dart';
import 'package:jsonschema/widget/miro_like/miro_canvas_painter.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'link_manager.dart';
import 'link_model.dart';
import 'block_model.dart';
import 'properties_panel.dart';
import 'import_export_manager.dart';

// ============================================================================
// THEME COLORS - Centralized color definitions for the entire application
// ============================================================================

// Canvas and Background Colors
const Color colorCanvasBackground = Color.fromARGB(255, 48, 48, 51);
const Color colorPropertiesPanelBg = Color.fromARGB(255, 24, 24, 27);
const Color colorPanelBorder = Color.fromARGB(255, 71, 71, 74);

// Block Colors
const Color colorBlockBackground = Color.fromARGB(255, 33, 33, 36);
const Color colorBlockBackgroundSelected = Color.fromARGB(255, 255, 193, 7);
const Color colorBlockBorder = Color.fromARGB(255, 66, 66, 69);
const Color colorBlockBorderSelected = Color.fromARGB(255, 255, 152, 0);
const Color colorBlockText = Colors.white;
const Color colorBlockTextSelected = Colors.black;

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

class _MiroLikeWidgetState extends State<MiroLikeWidget>
    with SingleTickerProviderStateMixin {
  static const double _linkHitTolerance = 14.0;
  static const double _inflectionHandleRadius = 7.0;
  static const double _anchorHandleRadius = 6.0;
  static const double _anchorSpacingDistance = 15.0;
  static const double _anchorPaddingMargin = 50.0;

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
      'position': _offsetToJson(block.position),
      'size': _sizeToJson(block.size),
    };
  }

  Map<String, dynamic> _linkToJson(BlockLink link) {
    return {
      'fromBlockId': link.fromBlockId,
      'toBlockId': link.toBlockId,
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

  void _importBoard(Map<String, dynamic> decoded) {
    final importedBlocks = _blocksFromJson(decoded['blocks']);
    final legacyType = _connectorTypeFromName(
      decoded['connectorType'],
    );
    final importedLinks = _linksFromJson(
      decoded['links'],
      fallbackType: legacyType,
    );
    final importedIds = importedBlocks
        .map((b) => b.id)
        .toSet();
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
    return (count - 1) * _anchorSpacingDistance + (2 * sidePadding);
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
    final spacingDistance = _anchorSpacingDistance;

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

  double _distancePointToSegmentSquared(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLenSq = ab.distanceSquared;
    if (abLenSq == 0) {
      return (p - a).distanceSquared;
    }

    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    final clampedT = t.clamp(0.0, 1.0);
    final proj = a + ab * clampedT;
    return (p - proj).distanceSquared;
  }

  bool _insertInflectionPointOnLink(Offset tapCanvas, Offset tapModel) {
    final toleranceSq = _linkHitTolerance * _linkHitTolerance;

    for (var linkIndex = links.length - 1; linkIndex >= 0; linkIndex--) {
      final link = links[linkIndex];
      final points = _linkControlPointsCanvas(link);
      if (points == null || points.length < 2) {
        continue;
      }

      var bestSegIndex = -1;
      var bestDistSq = double.infinity;
      for (var seg = 0; seg < points.length - 1; seg++) {
        final distSq = _distancePointToSegmentSquared(
          tapCanvas,
          points[seg],
          points[seg + 1],
        );
        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          bestSegIndex = seg;
        }
      }

      if (bestSegIndex != -1 && bestDistSq <= toleranceSq) {
        final insertIndex = bestSegIndex.clamp(0, link.inflectionPoints.length);
        link.inflectionPoints.insert(insertIndex, tapModel);
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
      final points = _linkControlPointsCanvas(link);
      if (points == null || points.length < 2) {
        continue;
      }

      var bestDistSq = double.infinity;
      for (var seg = 0; seg < points.length - 1; seg++) {
        final distSq = _distancePointToSegmentSquared(
          tapCanvas,
          points[seg],
          points[seg + 1],
        );
        if (distSq < bestDistSq) {
          bestDistSq = distSq;
        }
      }

      if (bestDistSq <= toleranceSq) {
        return link;
      }
    }

    return null;
  }

  List<Widget> _buildInflectionHandles() {
    final widgets = <Widget>[];

    for (var linkIndex = 0; linkIndex < links.length; linkIndex++) {
      final link = links[linkIndex];
      for (
        var pointIndex = 0;
        pointIndex < link.inflectionPoints.length;
        pointIndex++
      ) {
        final modelPoint = link.inflectionPoints[pointIndex];
        final canvasPoint = _modelToCanvas(modelPoint);

        widgets.add(
          Positioned(
            left: canvasPoint.dx - _inflectionHandleRadius,
            top: canvasPoint.dy - _inflectionHandleRadius,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
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
                    link.inflectionPoints[pointIndex] +=
                        details.delta / zoomLevel;
                  });
                },
                child: Container(
                  width: _inflectionHandleRadius * 2,
                  height: _inflectionHandleRadius * 2,
                  decoration: BoxDecoration(
                    color: colorInflectionPoint,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorAnchorBorder, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: colorShadow2,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<Widget> _buildAnchorHandles() {
    final widgets = <Widget>[];

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
        Positioned(
          left: fromAnchor.dx - _anchorHandleRadius,
          top: fromAnchor.dy - _anchorHandleRadius,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: GestureDetector(
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
              child: Container(
                width: _anchorHandleRadius * 2,
                height: _anchorHandleRadius * 2,
                decoration: BoxDecoration(
                  color: colorAnchorSourceHandle,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorAnchorBorder, width: 2),
                ),
              ),
            ),
          ),
        ),
      );

      widgets.add(
        Positioned(
          left: toAnchor.dx - _anchorHandleRadius,
          top: toAnchor.dy - _anchorHandleRadius,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: GestureDetector(
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
                  final toIndex = blocks.indexWhere(
                    (b) => b.id == link.toBlockId,
                  );
                  if (toIndex != -1) {
                    _ensureBlockHasSpaceForAnchors(blocks[toIndex]);
                  }
                });
              },
              child: Container(
                width: _anchorHandleRadius * 2,
                height: _anchorHandleRadius * 2,
                decoration: BoxDecoration(
                  color: colorAnchorTargetHandle,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorAnchorBorder, width: 2),
                ),
              ),
            ),
          ),
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
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: MouseRegion(
              key: _canvasKey,
              cursor: SystemMouseCursors.grab,
              onHover: (event) {
                setState(() {
                  currentMousePosition = event.localPosition;
                });
              },
              child: CustomPaint(
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
                child: Container(
                  color: colorCanvasBackground,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTapDown: (details) {
                          setState(() {
                            final canvasPosition = _toCanvasLocal(
                              details.globalPosition,
                            );
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

                            final hitLink = _findLinkAtCanvasPosition(
                              canvasPosition,
                            );
                            if (hitLink != null) {
                              selectedLink = hitLink;
                              selectedBlock = null;
                              _insertInflectionPointOnLink(
                                canvasPosition,
                                modelPosition,
                              );
                              return;
                            }

                            selectedBlock = null;
                            selectedLink = null;
                          });
                        },
                        onSecondaryTapDown: (details) {
                          setState(() {
                            final modelPosition = _toModelPosition(
                              details.globalPosition,
                            );

                            // Vérifier qu'on ne clique pas sur un bloc existant
                            for (var block in blocks) {
                              final blockRect = Rect.fromLTWH(
                                block.position.dx,
                                block.position.dy,
                                block.size.width,
                                block.size.height,
                              );
                              if (blockRect.contains(modelPosition)) {
                                return;
                              }
                            }

                            // Ajouter un bloc sur zone vide
                            blocks.add(
                              Block(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                title: 'Block ${blocks.length + 1}',
                                position: modelPosition,
                              ),
                            );
                            selectedBlock = null;
                            selectedLink = null;
                          });
                        },
                      ),
                      ...blocks.map((block) {
                        return Positioned(
                          left: block.position.dx * zoomLevel + canvasOffset.dx,
                          top: block.position.dy * zoomLevel + canvasOffset.dy,
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) {
                              if (_isSecondaryButtonPressed(event.buttons)) {
                                _startLinking(block);
                                _updateLinkPreviewFromGlobal(event.position);
                              }
                            },
                            onPointerMove: (event) {
                              if (linkSourceBlock != null &&
                                  _isSecondaryButtonPressed(event.buttons)) {
                                _updateLinkPreviewFromGlobal(event.position);
                              }
                            },
                            onPointerUp: (event) {
                              if (linkSourceBlock != null) {
                                _finishLinkingAtGlobal(event.position);
                              }
                            },
                            child: GestureDetector(
                              onPanDown: (details) {
                                setState(() {
                                  selectedBlock = block;
                                  selectedLink = null;
                                });
                              },
                              onPanUpdate: (details) {
                                if (selectedBlock == block) {
                                  setState(() {
                                    block.position += Offset(
                                      details.delta.dx / zoomLevel,
                                      details.delta.dy / zoomLevel,
                                    );
                                    _updateLinksAnchorsForBlock(block);
                                  });
                                }
                              },
                              onTapDown: (details) {
                                setState(() {
                                  selectedBlock = block;
                                  selectedLink = null;
                                });
                              },
                              child: BlockWidget(
                                block: block,
                                isSelected: selectedBlock == block,
                              ),
                            ),
                          ),
                        );
                      }),
                      ..._buildAnchorHandles(),
                      ..._buildInflectionHandles(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PropertiesPanel(
            selectedBlock: selectedBlock,
            selectedLink: selectedLink,
            onBlockTitleChanged: (blockId, newTitle) {
              setState(() {
                final blockIndex =
                    blocks.indexWhere((b) => b.id == blockId);
                if (blockIndex != -1) {
                  blocks[blockIndex].title = newTitle;
                }
              });
            },
            onReverseLink: _reverseLink,
            onDeleteLink: _deleteLink,
            onConnectorTypeChanged: (link, connectorType) {
              setState(() {
                link.connectorType = connectorType;
              });
            },
          ),
        ],
      ),
    );
  }
}
