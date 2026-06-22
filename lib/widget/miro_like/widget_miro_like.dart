import 'package:flutter/material.dart';
import 'dart:math' as math;

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

  BlockLink({required this.fromBlockId, required this.toBlockId});
}

enum ConnectorType { bezier, orthogonal }

class MiroLikeWidget extends StatefulWidget {
  const MiroLikeWidget({super.key});

  @override
  State<MiroLikeWidget> createState() => _MiroLikeWidgetState();
}

class _MiroLikeWidgetState extends State<MiroLikeWidget> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<Block> blocks = [];
  final List<BlockLink> links = [];
  ConnectorType connectorType = ConnectorType.bezier;
  Block? selectedBlock;
  Block? linkSourceBlock;
  Offset? linkingFromPoint;
  Offset? currentMousePosition;
  Offset canvasOffset = Offset.zero;
  double zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeSampleBlocks();
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
    });
  }

  void _endLinking(Block targetBlock) {
    if (linkSourceBlock != null && linkSourceBlock!.id != targetBlock.id) {
      setState(() {
        links.add(
          BlockLink(
            fromBlockId: linkSourceBlock!.id,
            toBlockId: targetBlock.id,
          ),
        );
        linkSourceBlock = null;
        linkingFromPoint = null;
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
          ),
          child: Container(
            color: Colors.grey[100],
            child: Stack(
              children: [
                GestureDetector(
                  onTapDown: (details) {
                    setState(() {
                      selectedBlock = null;
                      final modelPosition = _toModelPosition(
                        details.globalPosition,
                      );
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
                      onSecondaryLongPressStart: (details) {
                        _startLinking(block);
                      },
                      onSecondaryLongPressMoveUpdate: (details) {
                        if (linkSourceBlock != null) {
                          setState(() {
                            currentMousePosition = _toCanvasLocal(
                              details.globalPosition,
                            );
                          });
                        }
                      },
                      onSecondaryLongPressEnd: (details) {
                        if (linkSourceBlock != null) {
                          final modelPosition = _toModelPosition(
                            details.globalPosition,
                          );

                          for (var b in blocks) {
                            final blockBounds = Rect.fromLTWH(
                              b.position.dx,
                              b.position.dy,
                              b.size.width,
                              b.size.height,
                            );
                            if (blockBounds.contains(modelPosition)) {
                              _endLinking(b);
                              break;
                            }
                          }
                          setState(() {
                            linkSourceBlock = null;
                            linkingFromPoint = null;
                            currentMousePosition = null;
                          });
                        }
                      },
                      child: BlockWidget(
                        block: block,
                        isSelected: selectedBlock == block,
                      ),
                    ),
                  );
                }),
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner les liens
    final linkPaint = Paint()
      ..color = Colors.blueGrey.shade700
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var link in links) {
      final fromBlock = blocks.firstWhere((b) => b.id == link.fromBlockId);
      final toBlock = blocks.firstWhere((b) => b.id == link.toBlockId);

      final fromRect = _blockRectCanvas(fromBlock);
      final toRect = _blockRectCanvas(toBlock);
      final fromCenter = fromRect.center;
      final toCenter = toRect.center;

      final fromEdge = _pointOnRectBorderTowards(fromRect, toCenter);
      final toEdge = _pointOnRectBorderTowards(toRect, fromCenter);

      _drawArrow(canvas, fromEdge, toEdge, linkPaint);
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
      final linkingFromCanvas = _pointOnRectBorderTowards(
        sourceRect,
        currentMousePosition!,
      );

      // Dessiner une petite flèche de prévisualisation
      _drawArrow(canvas, linkingFromCanvas, currentMousePosition!, tempPaint);
    }
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

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    switch (connectorType) {
      case ConnectorType.bezier:
        _drawBezierArrow(canvas, from, to, paint);
      case ConnectorType.orthogonal:
        _drawOrthogonalArrow(canvas, from, to, paint);
    }
  }

  void _drawBezierArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    const arrowSize = 15.0;

    final controlPoints = _bezierControlPoints(from, to);
    final c1 = controlPoints.$1;
    final c2 = controlPoints.$2;

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);

    final angle = (to - c2).direction;
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

  void _drawOrthogonalArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
  ) {
    const arrowSize = 15.0;
    const radius = 18.0;

    final delta = to - from;
    final horizontalFirst = delta.dx.abs() >= delta.dy.abs();
    final p1 = horizontalFirst
        ? Offset((from.dx + to.dx) / 2, from.dy)
        : Offset(from.dx, (from.dy + to.dy) / 2);
    final p2 = horizontalFirst
        ? Offset((from.dx + to.dx) / 2, to.dy)
        : Offset(to.dx, (from.dy + to.dy) / 2);

    final path = Path()..moveTo(from.dx, from.dy);
    _lineOrArcTo(path, from, p1, p2, radius);
    _lineOrArcTo(path, p1, p2, to, radius);
    path.lineTo(to.dx, to.dy);
    canvas.drawPath(path, paint);

    final angle = (to - p2).direction;
    final arrowPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.fill;

    final pArrow1 =
        to + Offset(-arrowSize * 0.866, arrowSize * 0.5).rotate(angle);
    final pArrow2 =
        to + Offset(-arrowSize * 0.866, -arrowSize * 0.5).rotate(angle);

    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(pArrow1.dx, pArrow1.dy)
        ..lineTo(pArrow2.dx, pArrow2.dy)
        ..close(),
      arrowPaint,
    );
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
