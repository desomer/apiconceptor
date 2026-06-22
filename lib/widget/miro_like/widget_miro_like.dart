import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';

class Block {
  String id;
  String title;
  Offset position;
  Size size;

  Block({
    required this.id,
    required this.title,
    this.position = const Offset(0, 0),
    this.size = const Size(150, 100),
  });
}

class BlockLink {
  String fromBlockId;
  String toBlockId;
  ConnectorType connectorType;
  List<Offset> inflectionPoints;
  Offset? sourceAnchorUnit;
  Offset? targetAnchorUnit;
  bool isSourceAnchorLocked = false;
  bool isTargetAnchorLocked = false;
  double? sourceAnchorOrderKey;
  double? targetAnchorOrderKey;

  BlockLink({
    required this.fromBlockId,
    required this.toBlockId,
    this.connectorType = ConnectorType.bezier,
    List<Offset>? inflectionPoints,
    this.sourceAnchorUnit,
    this.targetAnchorUnit,
  }) : inflectionPoints = inflectionPoints ?? [];
}

enum ConnectorType { bezier, orthogonal }

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
  final GlobalKey _canvasKey = GlobalKey();
  final List<Block> blocks = [];
  final List<BlockLink> links = [];
  late final AnimationController _flowController;
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
      links.remove(link);
      if (selectedLink == link) {
        selectedLink = null;
      }
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

  Future<void> _showExportDialog() async {
    final jsonText = _generateBoardJson();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export JSON'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(child: SelectableText(jsonText)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonText));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('JSON copie dans le presse-papiers'),
                  ),
                );
              },
              child: const Text('Copier'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    String? error;

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Import JSON'),
              content: SizedBox(
                width: 640,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      minLines: 10,
                      maxLines: 18,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Collez le JSON ici',
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    try {
                      final decoded = jsonDecode(controller.text);
                      if (decoded is! Map<String, dynamic>) {
                        throw const FormatException(
                          'Le JSON racine doit etre un objet',
                        );
                      }

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

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Import JSON termine')),
                      );
                    } catch (e) {
                      setLocalState(() {
                        error = 'Import impossible: $e';
                      });
                    }
                  },
                  child: const Text('Importer'),
                ),
              ],
            );
          },
        );
      },
    );
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
            link.sourceAnchorUnit = newAnchor;
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
            link.targetAnchorUnit = newAnchor;
          }
        }
      }

      final blockIndex = blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex != -1) {
        _ensureBlockHasSpaceForAnchors(blocks[blockIndex]);
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

    final newWidth = math.max(block.size.width, requiredModelWidth);
    final newHeight = math.max(block.size.height, requiredModelHeight);

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
                    color: Colors.orange.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
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
                  color: Colors.teal.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
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
                  color: Colors.deepPurple.shade500,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildPropertiesPanel() {
    final block = selectedBlock;
    final link = selectedLink;

    if (block != null) {
      return Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Colors.grey.shade300)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proprietes du bloc',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('ID: ${block.id}'),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('block-title-${block.id}'),
              initialValue: block.title,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  block.title = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Text('Position X: ${block.position.dx.toStringAsFixed(1)}'),
            Text('Position Y: ${block.position.dy.toStringAsFixed(1)}'),
            const SizedBox(height: 8),
            Text('Largeur: ${block.size.width.toStringAsFixed(1)}'),
            Text('Hauteur: ${block.size.height.toStringAsFixed(1)}'),
          ],
        ),
      );
    }

    if (link != null) {
      return Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Colors.grey.shade300)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proprietes du lien',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Source: ${link.fromBlockId}'),
            Text('Cible: ${link.toBlockId}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<ConnectorType>(
              initialValue: link.connectorType,
              decoration: const InputDecoration(
                labelText: 'Type de lien',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: ConnectorType.bezier,
                  child: Text('Bezier'),
                ),
                DropdownMenuItem(
                  value: ConnectorType.orthogonal,
                  child: Text('Orthogonale'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  link.connectorType = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Text('Points d\'inflexion: ${link.inflectionPoints.length}'),
            const SizedBox(height: 8),
            Text(
              'Ancre source: ${link.sourceAnchorUnit?.toString() ?? 'auto'}',
            ),
            Text('Ancre cible: ${link.targetAnchorUnit?.toString() ?? 'auto'}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _deleteLink(link),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer le lien'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proprietes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Text('Selectionnez un bloc ou un lien.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miro Like'),
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
            onPressed: _showExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import JSON',
            onPressed: _showImportDialog,
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
                  linkingFromPoint: linkingFromPoint,
                  currentMousePosition: currentMousePosition,
                  linkSourceBlock: linkSourceBlock,
                  flowAnimation: _flowController,
                  pendingInflectionPoints: pendingInflectionPoints,
                ),
                child: Container(
                  color: Colors.grey[100],
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
          _buildPropertiesPanel(),
        ],
      ),
    );
  }
}

class BlockWidget extends StatelessWidget {
  final Block block;
  final bool isSelected;

  const BlockWidget({super.key, required this.block, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: block.size.width,
      height: block.size.height,
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[100] : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          block.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class MiroCanvasPainter extends CustomPainter {
  final List<Block> blocks;
  final List<BlockLink> links;
  final Offset canvasOffset;
  final double zoomLevel;
  final Block? selectedBlock;
  final Offset? linkingFromPoint;
  final Offset? currentMousePosition;
  final Block? linkSourceBlock;
  final Animation<double>? flowAnimation;
  final List<Offset> pendingInflectionPoints;

  MiroCanvasPainter({
    required this.blocks,
    required this.links,
    required this.canvasOffset,
    required this.zoomLevel,
    this.selectedBlock,
    this.linkingFromPoint,
    this.currentMousePosition,
    this.linkSourceBlock,
    this.flowAnimation,
    this.pendingInflectionPoints = const [],
  }) : super(repaint: flowAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner les liens
    final linkPaint = Paint()
      ..color = Colors.blueGrey.shade700
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var link in links) {
      final fromIndex = blocks.indexWhere((b) => b.id == link.fromBlockId);
      final toIndex = blocks.indexWhere((b) => b.id == link.toBlockId);
      if (fromIndex == -1 || toIndex == -1) {
        continue;
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

      final startTangent = _axisNormalForBorderPoint(fromRect, fromEdge);
      final targetOutward = _axisNormalForBorderPoint(toRect, toEdge);
      final endTangent = Offset(-targetOutward.dx, -targetOutward.dy);

      _drawArrow(
        canvas,
        fromEdge,
        toEdge,
        linkPaint,
        connectorType: link.connectorType,
        viaPoints: viaCanvas,
        startTangent: startTangent,
        endTangent: endTangent,
      );
    }

    // Dessiner le lien en cours de création
    if (linkingFromPoint != null &&
        linkSourceBlock != null &&
        currentMousePosition != null) {
      final tempPaint = Paint()
        ..color = Colors.blue.shade700
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final sourceRect = _blockRectCanvas(linkSourceBlock!);
      final previewViaCanvas = pendingInflectionPoints
          .map((point) => _modelToCanvas(point))
          .toList();
      final sourceReference = previewViaCanvas.isNotEmpty
          ? previewViaCanvas.first
          : currentMousePosition!;
      final linkingFromCanvas = _pointOnRectBorderTowards(
        sourceRect,
        sourceReference,
      );
      final startTangent = _axisNormalForBorderPoint(
        sourceRect,
        linkingFromCanvas,
      );

      // Dessiner une petite flèche de prévisualisation
      _drawArrow(
        canvas,
        linkingFromCanvas,
        currentMousePosition!,
        tempPaint,
        connectorType: ConnectorType.bezier,
        viaPoints: previewViaCanvas,
        startTangent: startTangent,
      );

      for (final point in previewViaCanvas) {
        canvas.drawCircle(
          point,
          5,
          Paint()
            ..color = Colors.orange.shade700
            ..style = PaintingStyle.fill,
        );
      }
    }
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

  Offset _axisNormalForBorderPoint(Rect rect, Offset edgePoint) {
    final vector = edgePoint - rect.center;
    if (vector.distanceSquared == 0) {
      return const Offset(1, 0);
    }
    if (vector.dx.abs() >= vector.dy.abs()) {
      return Offset(vector.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, vector.dy >= 0 ? 1 : -1);
  }

  Offset _unitOrFallback(Offset value, Offset fallback) {
    final length = value.distance;
    if (length == 0) {
      return fallback;
    }
    return value / length;
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    required ConnectorType connectorType,
    List<Offset> viaPoints = const [],
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final path = _connectorPath(
      from,
      to,
      connectorType: connectorType,
      viaPoints: viaPoints,
      startTangent: startTangent,
      endTangent: endTangent,
    );

    // Dessiner le tube néon avec effet de glow bleu
    _drawNeonTube(canvas, path);

    // Dessiner les particules qui circulent dans le tube
    _drawFlowParticles(canvas, path, const Color.fromARGB(255, 100, 200, 255));

    final endAngle = _pathEndAngle(path);
    if (endAngle == null) {
      return;
    }

    _drawArrowHead(canvas, to, endAngle, paint);
  }

  void _drawNeonTube(Canvas canvas, Path path) {
    // Tube bleu
    final tubePaint = Paint()
      ..color = const Color.fromARGB(100, 100, 200, 255)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, tubePaint);
  }

  Path _connectorPath(
    Offset from,
    Offset to, {
    required ConnectorType connectorType,
    List<Offset> viaPoints = const [],
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final allPoints = <Offset>[from, ...viaPoints, to];
    if (allPoints.length < 2) {
      return Path();
    }

    if (connectorType == ConnectorType.bezier) {
      return _buildSmoothBezierPath(
        allPoints,
        startTangent: startTangent,
        endTangent: endTangent,
      );
    }

    return _buildOrthogonalPath(
      allPoints,
      startTangent: startTangent,
      endTangent: endTangent,
    );
  }

  Path _buildOrthogonalPath(
    List<Offset> points, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final routed = <Offset>[...points];

    if (routed.length >= 2 && startTangent != null) {
      final start = routed.first;
      final next = routed[1];
      final dir = _unitOrFallback(startTangent, const Offset(1, 0));
      final lead = (next - start).distance;
      final leadLen = lead <= 0 ? 24.0 : (lead * 0.45).clamp(12.0, 52.0);
      routed.insert(1, start + dir * leadLen);
    }

    if (routed.length >= 2 && endTangent != null) {
      final end = routed.last;
      final prev = routed[routed.length - 2];
      final dir = _unitOrFallback(endTangent, const Offset(-1, 0));
      final lead = (end - prev).distance;
      final leadLen = lead <= 0 ? 24.0 : (lead * 0.45).clamp(12.0, 52.0);
      routed.insert(routed.length - 1, end - dir * leadLen);
    }

    const eps = 0.001;
    final manhattan = <Offset>[routed.first];

    for (var i = 1; i < routed.length; i++) {
      final from = manhattan.last;
      final to = routed[i];
      final dx = to.dx - from.dx;
      final dy = to.dy - from.dy;

      if (dx.abs() <= eps || dy.abs() <= eps) {
        if ((to - from).distanceSquared > eps * eps) {
          manhattan.add(to);
        }
        continue;
      }

      final horizontalFirst = dx.abs() >= dy.abs();
      final elbow = horizontalFirst
          ? Offset(to.dx, from.dy)
          : Offset(from.dx, to.dy);

      if ((elbow - from).distanceSquared > eps * eps) {
        manhattan.add(elbow);
      }
      if ((to - manhattan.last).distanceSquared > eps * eps) {
        manhattan.add(to);
      }
    }

    if (manhattan.length <= 1) {
      return Path()..moveTo(routed.first.dx, routed.first.dy);
    }

    final path = Path()..moveTo(manhattan.first.dx, manhattan.first.dy);
    if (manhattan.length == 2) {
      path.lineTo(manhattan.last.dx, manhattan.last.dy);
      return path;
    }

    const radius = 18.0;
    for (var i = 1; i < manhattan.length - 1; i++) {
      _lineOrArcTo(
        path,
        manhattan[i - 1],
        manhattan[i],
        manhattan[i + 1],
        radius,
      );
    }

    path.lineTo(manhattan.last.dx, manhattan.last.dy);
    return path;
  }

  Path _buildSmoothBezierPath(
    List<Offset> points, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      final controlPoints = _bezierControlPoints(
        points[0],
        points[1],
        startTangent: startTangent,
        endTangent: endTangent,
      );
      final c1 = controlPoints.$1;
      final c2 = controlPoints.$2;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, points[1].dx, points[1].dy);
      return path;
    }

    const tension = 1.0;
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      var c1 = p1 + ((p2 - p0) * (tension / 6));
      var c2 = p2 - ((p3 - p1) * (tension / 6));

      final segmentLength = (p2 - p1).distance;
      final handleLength = math.max(24.0, segmentLength * 0.45);

      if (i == 0 && startTangent != null) {
        final dir = _unitOrFallback(startTangent, const Offset(1, 0));
        c1 = p1 + dir * handleLength;
      }
      if (i == points.length - 2 && endTangent != null) {
        final dir = _unitOrFallback(endTangent, const Offset(-1, 0));
        c2 = p2 - dir * handleLength;
      }

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  void _drawArrowHead(Canvas canvas, Offset to, double angle, Paint paint) {
    const arrowSize = 15.0;
    final arrowPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.fill;

    final p1 = to + Offset(-arrowSize * 0.866, arrowSize * 0.5).rotate(angle);
    final p2 = to + Offset(-arrowSize * 0.866, -arrowSize * 0.5).rotate(angle);

    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      arrowPaint,
    );
  }

  double? _pathEndAngle(Path path) {
    final iterator = path.computeMetrics().iterator;
    if (!iterator.moveNext()) {
      return null;
    }

    var metric = iterator.current;
    while (iterator.moveNext()) {
      metric = iterator.current;
    }
    if (metric.length <= 0) {
      return null;
    }

    final endTangent = metric.getTangentForOffset(metric.length);
    if (endTangent == null) {
      return null;
    }

    final sampleOffset = math.max(0.0, metric.length - 8.0);
    final sampleTangent = metric.getTangentForOffset(sampleOffset);
    if (sampleTangent == null) {
      return endTangent.angle;
    }

    final direction = endTangent.position - sampleTangent.position;
    if (direction.distanceSquared == 0) {
      return endTangent.angle;
    }

    return direction.direction;
  }

  void _drawFlowParticles(Canvas canvas, Path path, Color color) {
    final metrics = path.computeMetrics();
    final iterator = metrics.iterator;
    if (!iterator.moveNext()) {
      return;
    }

    const spacing = 34.0;
    const speedPx = 170.0;
    final travel = (flowAnimation?.value ?? 0.0) * speedPx;

    do {
      final metric = iterator.current;
      final length = metric.length;
      if (length <= 0) {
        continue;
      }

      final phase = travel % spacing;
      for (double d = phase; d < length + spacing; d += spacing) {
        final offsetOnPath = d % length;
        final tangent = metric.getTangentForOffset(offsetOnPath);
        if (tangent == null) {
          continue;
        }
        final progress = offsetOnPath / length;
        final radius = 1.8 + (0.8 * progress);

        // Effet de lueur néon - couches multiples pour l'effet glow
        final neonColor = color.withValues(alpha: 0.15);

        // Première couche de glow (la plus large)
        final glow1Paint = Paint()
          ..color = neonColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius * 1.8, glow1Paint);

        // Deuxième couche de glow (moyenne)
        final glow2Paint = Paint()
          ..color = neonColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius * 1.3, glow2Paint);

        // Couche principale avec lueur plus intense
        final flowPaint = Paint()
          ..color = color.withValues(alpha: 0.65 + (0.35 * progress))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius, flowPaint);

        // Cœur brillant central
        final corePaint = Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius * 0.4, corePaint);
      }
    } while (iterator.moveNext());
  }

  void _lineOrArcTo(
    Path path,
    Offset prev,
    Offset corner,
    Offset next,
    double radius,
  ) {
    final vIn = corner - prev;
    final vOut = next - corner;
    if (vIn.distanceSquared == 0 || vOut.distanceSquared == 0) {
      path.lineTo(corner.dx, corner.dy);
      return;
    }

    final inDir = vIn / vIn.distance;
    final outDir = vOut / vOut.distance;
    final r = math.min(radius, math.min(vIn.distance, vOut.distance) / 2);

    final arcStart = corner - inDir * r;
    final arcEnd = corner + outDir * r;

    path.lineTo(arcStart.dx, arcStart.dy);
    path.quadraticBezierTo(corner.dx, corner.dy, arcEnd.dx, arcEnd.dy);
  }

  (Offset, Offset) _bezierControlPoints(
    Offset from,
    Offset to, {
    Offset? startTangent,
    Offset? endTangent,
  }) {
    final delta = to - from;
    final distance = delta.distance;
    final curvature = math.max(40.0, distance * 0.35);

    if (startTangent != null || endTangent != null) {
      final startDir = _unitOrFallback(
        startTangent ?? delta,
        const Offset(1, 0),
      );
      final endDir = _unitOrFallback(endTangent ?? delta, const Offset(1, 0));
      return (from + startDir * curvature, to - endDir * curvature);
    }

    if (delta.dx.abs() >= delta.dy.abs()) {
      final dir = delta.dx >= 0 ? 1.0 : -1.0;
      return (
        from + Offset(curvature * dir, 0),
        to - Offset(curvature * dir, 0),
      );
    }

    final dir = delta.dy >= 0 ? 1.0 : -1.0;
    return (from + Offset(0, curvature * dir), to - Offset(0, curvature * dir));
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

  Offset _anchorSideUnit(Offset unit) {
    final normalized = _normalizeAnchorUnit(unit);
    if (normalized.dx.abs() >= normalized.dy.abs()) {
      return Offset(normalized.dx >= 0 ? 1 : -1, 0);
    }
    return Offset(0, normalized.dy >= 0 ? 1 : -1);
  }

  Offset _getAnchorSpacingOffset(
    BlockLink currentLink,
    String blockId,
    Offset anchorUnit,
  ) {
    final side = _anchorSideUnit(anchorUnit);
    final spacingDistance = 15.0; // Distance between anchors

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

  @override
  bool shouldRepaint(MiroCanvasPainter oldDelegate) => true;
}

extension on Offset {
  Offset rotate(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(dx * cos - dy * sin, dx * sin + dy * cos);
  }
}
