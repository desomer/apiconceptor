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
  List<Offset> inflectionPoints;
  Offset? sourceAnchorUnit;
  Offset? targetAnchorUnit;

  BlockLink({
    required this.fromBlockId,
    required this.toBlockId,
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
  final GlobalKey _canvasKey = GlobalKey();
  final List<Block> blocks = [];
  final List<BlockLink> links = [];
  late final AnimationController _flowController;
  ConnectorType connectorType = ConnectorType.bezier;
  Block? selectedBlock;
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
      'inflectionPoints': link.inflectionPoints.map(_offsetToJson).toList(),
      'sourceAnchorUnit': link.sourceAnchorUnit == null
          ? null
          : _offsetToJson(link.sourceAnchorUnit!),
      'targetAnchorUnit': link.targetAnchorUnit == null
          ? null
          : _offsetToJson(link.targetAnchorUnit!),
    };
  }

  Map<String, dynamic> _boardToJson() {
    return {
      'version': 1,
      'connectorType': connectorType.name,
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

  List<BlockLink> _linksFromJson(dynamic value) {
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
          inflectionPoints: inflectionPoints,
          sourceAnchorUnit: item['sourceAnchorUnit'] == null
              ? null
              : _offsetFromJson(item['sourceAnchorUnit']),
          targetAnchorUnit: item['targetAnchorUnit'] == null
              ? null
              : _offsetFromJson(item['targetAnchorUnit']),
        ),
      );
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
                      final importedLinks = _linksFromJson(decoded['links']);
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
                        connectorType = _connectorTypeFromName(
                          decoded['connectorType'],
                        );

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
      setState(() {
        links.add(
          BlockLink(
            fromBlockId: linkSourceBlock!.id,
            toBlockId: targetBlock.id,
            inflectionPoints: List<Offset>.from(pendingInflectionPoints),
          ),
        );
        linkSourceBlock = null;
        linkingFromPoint = null;
        pendingInflectionPoints.clear();
      });
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

  Offset _borderPointFromUnit(Rect rect, Offset unit) {
    final normalized = _normalizeAnchorUnit(unit);
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final center = rect.center;
    return Offset(
      center.dx + normalized.dx * halfW,
      center.dy + normalized.dy * halfH,
    );
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
        ? _borderPointFromUnit(fromRect, link.sourceAnchorUnit!)
        : _pointOnRectBorderTowards(fromRect, fromReference);
    final toEdge = link.targetAnchorUnit != null
        ? _borderPointFromUnit(toRect, link.targetAnchorUnit!)
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
        return true;
      }
    }

    return false;
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
                        color: Colors.black.withOpacity(0.25),
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

    for (final link in links) {
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
              onPanUpdate: (details) {
                setState(() {
                  final canvasPosition = _toCanvasLocal(details.globalPosition);
                  link.sourceAnchorUnit = _anchorUnitFromCanvasPoint(
                    fromRect,
                    canvasPosition,
                  );
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
              onPanUpdate: (details) {
                setState(() {
                  final canvasPosition = _toCanvasLocal(details.globalPosition);
                  link.targetAnchorUnit = _anchorUnitFromCanvasPoint(
                    toRect,
                    canvasPosition,
                  );
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
          PopupMenuButton<ConnectorType>(
            tooltip: 'Type de flèche',
            icon: const Icon(Icons.alt_route),
            initialValue: connectorType,
            onSelected: (value) {
              setState(() {
                connectorType = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: ConnectorType.bezier, child: Text('Bezier')),
              PopupMenuItem(
                value: ConnectorType.orthogonal,
                child: Text('Orthogonale'),
              ),
            ],
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
      body: MouseRegion(
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
            connectorType: connectorType,
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

                      if (_insertInflectionPointOnLink(
                        canvasPosition,
                        modelPosition,
                      )) {
                        return;
                      }

                      selectedBlock = null;
                      for (var block in blocks) {
                        final blockRect = Rect.fromLTWH(
                          block.position.dx,
                          block.position.dy,
                          block.size.width,
                          block.size.height,
                        );
                        if (blockRect.contains(modelPosition)) {
                          selectedBlock = block;
                          break;
                        }
                      }
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
                            });
                          }
                        },
                        onTapDown: (details) {
                          setState(() {
                            selectedBlock = block;
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
            color: Colors.black.withOpacity(0.1),
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
  final ConnectorType connectorType;
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
    this.connectorType = ConnectorType.bezier,
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
          ? _borderPointFromUnit(fromRect, link.sourceAnchorUnit!)
          : _pointOnRectBorderTowards(fromRect, fromReference);
      final toEdge = link.targetAnchorUnit != null
          ? _borderPointFromUnit(toRect, link.targetAnchorUnit!)
          : _pointOnRectBorderTowards(toRect, toReference);

      _drawArrow(canvas, fromEdge, toEdge, linkPaint, viaPoints: viaCanvas);
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

      // Dessiner une petite flèche de prévisualisation
      _drawArrow(
        canvas,
        linkingFromCanvas,
        currentMousePosition!,
        tempPaint,
        viaPoints: previewViaCanvas,
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

  Offset _borderPointFromUnit(Rect rect, Offset unit) {
    final normalized = _normalizeAnchorUnit(unit);
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final center = rect.center;
    return Offset(
      center.dx + normalized.dx * halfW,
      center.dy + normalized.dy * halfH,
    );
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    List<Offset> viaPoints = const [],
  }) {
    final path = _connectorPath(from, to, viaPoints: viaPoints);
    canvas.drawPath(path, paint);
    _drawFlowParticles(canvas, path, paint.color);

    final endAngle = _pathEndAngle(path);
    if (endAngle == null) {
      return;
    }

    _drawArrowHead(canvas, to, endAngle, paint);
  }

  Path _connectorPath(
    Offset from,
    Offset to, {
    List<Offset> viaPoints = const [],
  }) {
    final allPoints = <Offset>[from, ...viaPoints, to];
    if (allPoints.length < 2) {
      return Path();
    }

    if (connectorType == ConnectorType.bezier) {
      return _buildSmoothBezierPath(allPoints);
    }

    final path = Path()..moveTo(allPoints.first.dx, allPoints.first.dy);
    for (var i = 0; i < allPoints.length - 1; i++) {
      _appendConnectorSegment(path, allPoints[i], allPoints[i + 1]);
    }
    return path;
  }

  Path _buildSmoothBezierPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      final controlPoints = _bezierControlPoints(points[0], points[1]);
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

      final c1 = p1 + ((p2 - p0) * (tension / 6));
      final c2 = p2 - ((p3 - p1) * (tension / 6));
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  void _appendConnectorSegment(Path path, Offset from, Offset to) {
    switch (connectorType) {
      case ConnectorType.bezier:
        final controlPoints = _bezierControlPoints(from, to);
        final c1 = controlPoints.$1;
        final c2 = controlPoints.$2;
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, to.dx, to.dy);
        break;
      case ConnectorType.orthogonal:
        const radius = 18.0;
        final delta = to - from;
        final horizontalFirst = delta.dx.abs() >= delta.dy.abs();
        final p1 = horizontalFirst
            ? Offset((from.dx + to.dx) / 2, from.dy)
            : Offset(from.dx, (from.dy + to.dy) / 2);
        final p2 = horizontalFirst
            ? Offset((from.dx + to.dx) / 2, to.dy)
            : Offset(to.dx, (from.dy + to.dy) / 2);
        _lineOrArcTo(path, from, p1, p2, radius);
        _lineOrArcTo(path, p1, p2, to, radius);
        path.lineTo(to.dx, to.dy);
        break;
    }
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
        final radius = 2.0 + (1.4 * progress);
        final flowPaint = Paint()
          ..color = color.withOpacity(0.45 + (0.5 * progress))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, radius, flowPaint);
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

  (Offset, Offset) _bezierControlPoints(Offset from, Offset to) {
    final delta = to - from;
    final distance = delta.distance;
    final curvature = math.max(40.0, distance * 0.35);

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
